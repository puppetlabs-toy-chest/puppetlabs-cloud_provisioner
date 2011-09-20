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
          @result.should_not be_empty
        end
        it "should look like a hash of identifiers" do
          @result.each do |k,v|
            k.should match(/^i-\w+/i)
          end
        end
        it "should be a kind of Hash" do
          @result.should be_a_kind_of(Hash)
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

  describe 'install helper methods' do
    before :all do
      @server = 'ec2-50-19-20-121.compute-1.amazonaws.com'
      @login  = 'root'
      @keyfile = Tempfile.open('private_key')
      @keydata = 'FOOBARBAZ'
      @keyfile.write(@keydata)
      @keyfile.close
    end
    before :each do
      @ssh_mock = Fog::SSH::Mock.new(@server, @login, 'options')
      @scp_mock = Fog::SCP::Mock.new('local', 'remote', {})
      @mock_connection_tuple = { :ssh => @ssh_mock, :scp => @scp_mock }
    end
    after :all do
      File.unlink(@keyfile.path)
    end
    describe '#install' do
      before :each do
        @options = {
          :keyfile           => @keyfile.path,
          :login             => @login,
          :server            => @server,
          :install_script    => "puppet-enterprise-s3",
          :installer_answers => "/Users/jeff/vms/moduledev/enterprise/answers_cloudpack.txt",
        }
        Puppet::CloudPack.expects(:ssh_connect).with(@server, @login, @keyfile.path).returns(@mock_connection_tuple)
        Puppet::CloudPack.expects(:ssh_remote_execute).twice.with(any_parameters)
      end
      it 'should return a generated certname matching a guid' do
        subject.install(@server, @options).should match(/[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}/)
      end
      it 'should return the specified certname' do
        @options[:certname] = 'abc123'
        subject.install(@server, @options).should eq 'abc123'
      end
      it 'should set server as public_dns_name option' do
        subject.expects(:compile_template).with do |options|
          options[:public_dns_name] == @server
        end
        subject.install(@server, @options)
      end
    end
    describe '#install - setting up install command' do
      before :each do
        @options = {
          :keyfile           => @keyfile.path,
          :server            => @server,
        }
      end
      it 'should pre-pend sudo to command if login is not root' do
        @options[:login] = 'dan'
        Puppet::CloudPack.expects(:ssh_connect).with(@server, 'dan', @keyfile.path).returns(@mock_connection_tuple)
        @is_command_valid = false
        Puppet::CloudPack.expects(:ssh_remote_execute).twice.with do |server, login, command, keyfile|
          if command =~ /^sudo bash -c 'chmod u\+x \S+gems\.sh; \S+gems\.sh'/
            # set that the command is valid when it matches the regex
            # the test will pass is this is set to true
            @is_command_valid = true
          else
            true
          end
        end
        subject.install(@server, @options)
        @is_command_valid.should be_true
      end
      it 'should not add sudo to command when login is root' do
        @options[:login] = 'root'
        Puppet::CloudPack.expects(:ssh_connect).with(@server, 'root', @keyfile.path).returns(@mock_connection_tuple)
        @is_command_valid = false
        Puppet::CloudPack.expects(:ssh_remote_execute).twice.with do |server, login, command, keyfile|
          if command =~ /^bash -c 'chmod u\+x \S+gems\.sh; \S+gems\.sh'/
            # set that the command is valid when it matches the regex
            # the test will pass is this is set to true
            @is_command_valid = true
          else
            # return true for all invocations of ssh_remote_execute
            true
          end
        end
        subject.install(@server, @options)
        @is_command_valid.should be_true
      end
    end
    describe '#ssh_connect' do
      before :each do
        Puppet::CloudPack.expects(:ssh_test_connect).with(@server, @login, @keyfile.path).returns(true)
      end
      it 'should return Fog::SSH and Fog::SCP instances' do
        Fog::SSH.expects(:new).with(@server, @login, {:key_data => [@keydata]}).returns(@ssh_mock)
        Fog::SCP.expects(:new).with(@server, @login, {:key_data => [@keydata]}).returns(@scp_mock)
        results = subject.ssh_connect(@server, @login, @keyfile.path)
        results[:ssh].should be @ssh_mock
        results[:scp].should be @scp_mock
      end
    end
    describe '#ssh_test_connect' do
      before :each do
        subject.stubs(:sleep)
      end
      describe "with transient failures" do
        it 'should be tolerant of ??? failures' do
          pending 'Dan mentioned specific conditions which are unknown at this time.'
        end
        describe 'with Net:SSH::AuthenticationFailed failures' do
          it 'should be tolerant of intermittent failures' do
            Puppet::CloudPack.stubs(:ssh_remote_execute).raises(Net::SSH::AuthenticationFailed, 'root').then.returns(true)
            subject.ssh_test_connect('server', 'root', @keyfile.path)
          end
          it 'should fail eventually' do
            Puppet::CloudPack.stubs(:ssh_remote_execute).raises(Net::SSH::AuthenticationFailed, 'root')
            expect { subject.ssh_test_connect('server', 'root', @keyfile.path) }.should raise_error(Puppet::Error, /auth/)
          end
        end
      end
      describe 'with general Exception failures' do
        it 'should not be tolerant of intermittent errors' do
          Puppet::CloudPack.stubs(:ssh_remote_execute).raises(Exception, 'some error').then.returns(true)
          expect { subject.ssh_test_connect('server', 'root', @keyfile.path) }.should raise_error(Exception, 'some error')
        end
        it 'should fail eventually ' do
          Puppet::CloudPack.stubs(:ssh_remote_execute).raises(Exception, 'some error')
          expect { subject.ssh_test_connect('server', 'root', @keyfile.path) }.should raise_error(Exception, 'some error')
        end
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
      ['http://foo:80', 'ftp://foo', 'https://blah'].each do |url|
        it 'should not upload the installer_payload when it is an http URL' do
          @scp_mock.expects(:upload).never
          @result = subject.upload_payloads(
            @scp_mock,
            {:installer_payload => url, :tmp_dir => '/tmp'}
          )
        end
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

  describe 'helper functions' do
    before :each do
      @login   = 'root'
      @server  = 'ec2-75-101-189-165.compute-1.amazonaws.com'
      @keyfile = Tempfile.open('private_key')
      @keydata = 'FOOBARBAZ'
      @keyfile.write(@keydata)
      @keyfile.close
      @options = {
        :keyfile           => @keyfile.path,
        :login             => @login,
        :server            => @server,
        :install_script    => "puppet-enterprise-s3",
        :installer_answers => "/Users/jeff/vms/moduledev/enterprise/answers_cloudpack.txt",
      }
    end

    describe '#merge_default_options' do
      it 'should set the installer script' do
        merged_options = subject.merge_default_options(@options)
        merged_options.should include(:install_script)
      end
      it 'should set the installer script to gems when unset' do
        (opts = @options.dup).delete(:install_script)
        merged_options = subject.merge_default_options(opts)
        merged_options[:install_script].should eq('gems')
      end
      it 'should allow the user to specify the install script' do
        merged_options = subject.merge_default_options(@options)
        merged_options[:install_script].should eq(@options[:install_script])
      end
    end

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

  describe 'option parsing helper functions' do
    before :each do
      @options = {
        :platform => 'AWS',
        :image    => 'ami-12345',
        :type     => 'm1.small',
        :keypair  => 'some_keypair',
        :region   => 'us-east-1',
      }
    end
    it 'should split a group string on the path separator' do
      @options[:group] = %w[ A B C D E ].join(File::PATH_SEPARATOR)
      Puppet::CloudPack.stubs(:create_connection).with() do |options|
        if options[:group] == %w[ A B C D E ] then
          raise Exception, 'group was split as expected'
        else
          raise Exception, 'group was not split as expected'
        end
      end
      expect { Puppet::CloudPack.group_option_before_action(@options) }.to raise_error Exception, /was split as expected/
    end

  end
end
