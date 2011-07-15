require 'spec_helper'
require 'puppet/cloudpack'

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
