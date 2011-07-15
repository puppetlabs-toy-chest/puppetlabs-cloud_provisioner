require 'spec_helper'
require 'puppet/cloudpack'

module Fog
  module SSH
    class Mock
      def run(commands)
        commands.collect do |command|
          Result.new(command)
        end
      end
      class Result
        attr_accessor :command, :stderr, :stdout, :status
        def initialize(command)
          @command = command
          @stderr = command
          @stdout = command
        end
      end
    end
  end
  module SCP
    class Mock
      def upload(local_path, remote_path, upload_options = {})
        nil
      end
    end
  end
end

describe Puppet::CloudPack do
  before(:all) { @stdout, $stdout = $stdout, StringIO.new(@buffer = '') }
  after(:all)  { $stdout = @stdout }

  def server
    stub = Puppet::CloudPack.stubs(:create_server)
    stub.with do |servers, options|
      server = servers.create(options)
      stub.returns(server)
      yield server
    end
  end

  # The real kicker here is that we don't actually even *care* about the
  # console output; we care about the host's fingerprints.
  def stub_console_output(last_message=nil)
    server do |server|
      server.stubs(:console_output => mock do
        responses = [ nil, nil, nil, nil, nil, last_message ]
        responses.collect! { |output| { 'output' => output } }
        stubs(:body).returns(*responses)
      end)
    end
  end

  describe 'actions' do
    describe '#create' do
      describe 'with valid arguments' do
        before :all do
          stub_console_output("pre\nec2: ####\nec2: PRINTS\nec2: ####\npost\n")
          @result = subject.create(:platform => 'AWS', :image => 'ami-12345')
          @server = Fog::Compute.new(:provider => 'AWS').servers.first
        end

        it 'should tag the newly created instance as created by us' do
          @server.tags.should include('Created-By' => 'Puppet')
        end

        it 'should create a new running instance' do
          @server.should be_ready
        end

        it 'should return the dns name of the new instance' do
          @result.should == @server.dns_name
        end
      end

      describe 'in exceptional situations' do
        before(:all) { @options = { :platform => 'AWS', :image => 'ami-12345' } }

        subject { Puppet::CloudPack.create(@options) }

        describe 'like when creating the new instance fails' do
          before :each do
            server do |server|
              server.stubs(:ready?).raises(Fog::Errors::Error)
            end
          end

          it 'should explain what went wrong' do
            subject
            @logs.join.should match /Could not connect to host/
          end

          it 'should provide further instructions' do
            subject
            @logs.join.should match /check your network connection/
          end

          it 'should have a nil return value' do
            subject.should be_nil
          end
        end
      end
    end
    describe '#install' do
      before :all do
        @keyfile = Tempfile.open('private_key')
        @keyfile.write('FOO')
        @keyfile.close
        @ssh_mock = Fog::SSH::Mock.new('address', 'username', 'options')
        @scp_mock = Fog::SCP::Mock.new('local', 'remote', {})
      end
      describe '#ssh_connect' do
        it 'should use the correct options to make a connection' do
          Fog::SSH.expects(:new).with('server', 'root', {:key_data => ['FOO']}).returns(@ssh_mock)
          Fog::SCP.expects(:new).with('server', 'root', {:key_data => ['FOO']}).returns(@scp_mock)
          @ssh_mock.expects(:run).with(['hostname'])
          subject.ssh_connect('server', 'root', @keyfile.path)
        end
        it 'should be tolerant of exceptions' do
          Fog::SSH.expects(:new).with('server', 'root', {:key_data => ['FOO']}).returns(@ssh_mock)
          Fog::SCP.expects(:new).with('server', 'root', {:key_data => ['FOO']}).returns(@scp_mock)
          # this expectation varifies that it allows for failures on the first try
          # and does not raise exceptions when the second call does not fail
          @ssh_mock.expects(:run).with do |var| raise(Net::SSH::AuthenticationFailed, 'fails') end.with(['hostname'])
          subject.ssh_connect('server', 'root', @keyfile.path)
        end
        it 'Exceptions eventually cause a failure' do
          Fog::SSH.expects(:new).with('server', 'root', {:key_data => ['FOO']}).returns(@ssh_mock)
          @ssh_mock.stubs(:run).with do |var| raise(Exception, 'fails') end
          expect { subject.ssh_connect('server', 'root', @keyfile.path) }.should raise_error
        end
      end
      describe '#upload_payloads' do
        it 'should not upload anything if nothing is specifed to upload' do
          @scp_mock.expects(:upload).never
          @result = subject.upload_payloads(
            @scp_mock,
            {}
          )
        end
        it 'should upload answer file when specified' do
          @scp_mock.expects(:upload).with('foo', "/tmp/puppet.answers")
          @result = subject.upload_payloads(
            @scp_mock,
            {:installer_answers => 'foo', :tmp_dir => '/tmp'}
          )
        end
        it 'should upload installer_payload when specified' do
          @scp_mock.expects(:upload).with('foo', "/tmp/puppet.tar.gz")
          @result = subject.upload_payloads(
            @scp_mock,
            {:installer_payload => 'foo', :tmp_dir => '/tmp'}
          )
        end
        it 'should require installer payload when install-script is puppet-enterprise' do
          expect do
            subject.upload_payloads(
              @scp_mock,
              :install_script => 'puppet-enterprise',
              :installer_answers => 'foo'
            )
          end.should raise_error Exception, /Must specify installer payload/
        end
        it 'should require installer answers when install-script is puppet-enterprise' do
          expect do
            subject.upload_payloads(
              @scp_mock,
              :install_script => 'puppet-enterprise',
              :installer_payload => 'foo'
            )
          end.should raise_error Exception, /Must specify .*? answers file/
        end
      end
      describe '#run install script' do
        it 'should upload the script and execute it' do
          @scp_mock.expects(:upload).with('foo_file', "/tmp/foo.sh")
          @ssh_mock.expects(:run).with("bash -c 'chmod u+x /tmp/foo.sh; /tmp/foo.sh | tee /tmp/install.log'").returns([Fog::SSH::Mock::Result.new('foo')])
          subject.run_install_script(
            @ssh_mock, @scp_mock, 'foo_file', '/tmp', 'foo', 'root'
          )
        end
        it 'should execte script with sudo when login is not root' do
          @ssh_mock.expects(:run).with("sudo bash -c 'chmod u+x /tmp/foo.sh; /tmp/foo.sh | tee /tmp/install.log'").returns([Fog::SSH::Mock::Result.new('foo')])
          subject.run_install_script(
            @ssh_mock, @scp_mock, 'foo_file', '/tmp', 'foo', 'dan'
          )
        end
      end
      describe '#compile_template' do
        it 'should be able to compile a template' do
          tmp_file = begin
            tmp = Tempfile.open('foo')
            tmp.write('Here is a <%= options[:variable] %>')
            tmp.path
          ensure
            tmp.close
          end
          tmp_filename = File.basename(tmp_file)
          tmp_basedir = File.join(File.dirname(tmp_file), 'scripts')
          tmp_file_real = File.join(tmp_basedir, "#{tmp_filename}.erb")
          FileUtils.mkdir_p(tmp_basedir)
          FileUtils.mv(tmp_file, tmp_file_real)
          Puppet[:confdir] = File.dirname(tmp_file)
          @result = subject.compile_template(
            :variable => 'variable',
            :install_script => tmp_filename
          )
          File.read(@result).should == 'Here is a variable'
        end
      end
    end
    describe '#terminate' do
      describe 'with valid arguments' do
        before :each do
          @connection = Fog::Compute.new(:provider => 'AWS')
          @servers = @connection.servers
          @server = @servers.create(:image_id => '12345')

          Fog::Compute.stubs(:new => @connection)
          @connection.stubs(:servers => @servers)

          @server.wait_for(&:ready?)
        end

        subject { Puppet::CloudPack }

        it 'should destroy the specified instance' do
          args = { 'dns-name' => 'some.name' }
          @servers.expects(:all).with(args).returns([@server])
          @server.expects(:destroy)

          subject.terminate('some.name', { })
        end
      end
    end

    describe '#list' do
      describe 'with valid arguments' do
        before :all do
          @result = subject.list(:platform => 'AWS')
        end
        it 'should not be empty' do
          # We actually get back something like this from Fog:
          # ["ec2-368-5-559-12.compute-1.amazonaws.com", "ec2-14-92-246-64.compute-1.amazonaws.com"]
          @result.should_not be_empty
        end
        it "should look like a list of DNS names" do
          @result.each do |hostname|
            hostname.should match(/^([a-zA-Z0-9-]+)$|^([a-zA-Z0-9-]+\.)+[a-zA-Z0-9-]+$/)
          end
        end
        it "should be a kind of Array" do
          @result.should be_a_kind_of(Array)
        end
      end
    end

    describe '#fingerprint' do
      describe 'with valid arguments' do
        before :all do
          @connection = Fog::Compute.new(:provider => 'AWS')
          @servers = @connection.servers
          @server = @servers.create(:image_id => '12345')
          # Commented because without a way to mock the busy wait on the console output,
          # these tests take WAY too long.
          # @result = subject.fingerprint(@server.dns_name, :platform => 'AWS')
        end
        it 'should not be empty' do
          pending "Fog does not provide a mock Excon::Response instance with a non-nil body.  As a result we wait indefinitely in this test.  Pending a better way to test an instance with console output already available."
          result = subject.fingerprint(@server.dns_name, :platform => 'AWS')
          result.should_not be_empty
        end
        it "should look like a list of fingerprints" do
          pending "#8348 unimplemented (What does a valid fingerprint look like?)"
          result = subject.fingerprint(@server.dns_name, :platform => 'AWS')
          result.should_not be_empty
        end
        it "should be a kind of Array" do
          pending "#8348 We need a way to mock the busy loop wait on console output."
          @result.should be_a_kind_of(Hash)
        end
      end
    end

  end

  describe 'helper functions' do
    describe '#create_connection' do
      it 'should create a new connection' do
        Fog::Compute.expects(:new).with(:provider => 'SomeProvider')
        subject.send :create_connection, :platform => 'SomeProvider'
      end
    end

    describe '#create_server' do
      it 'should create a new server' do
        options = { :image_id => 'ami-12345' }
        servers = mock { expects(:create).with(options) }
        subject.send :create_server, servers, options
      end
    end

    describe '#create_tags' do
      it 'should create new tags for the given server' do
        tags = mock do
          expects(:create).with(
            :key         => 'Created-By',
            :value       => 'Puppet',
            :resource_id => 'i-1234'
          )
        end
        subject.send :create_tags, tags, mock(:id => 'i-1234')
      end
    end
  end
end
