require 'spec_helper'
require 'puppet/faces'

describe Puppet::Faces[:node, '0.0.1'] do
  before(:all) { @stdout = $stdout }
  after(:all)  { $stdout = @stdout }

  def server
    stub = Puppet::Faces[:node, '0.0.1'].stubs(:create_server)
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

  describe '#create' do
    describe 'with valid arguments' do
      before :all do
        $stdout = StringIO.new(@buffer = '')
        stub_console_output("pre\nec2: ####\nec2: PRINTS\nec2: ####\npost\n")
        @result = subject.create(:image => 'ami-12345')
        @server = subject.create_connection().servers.first
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

      it "should output the host's fingerprints" do
        @buffer.should match /PRINTS/
      end
    end

    describe 'in exceptional situations' do
      before(:all) { @options = { :image => 'ami-12345' } }

      subject { Puppet::Faces[:node, '0.0.1'].create(@options) }

      describe 'like when waiting for fingerprints times out' do
        before :each do
          server do |server|
            server.stubs(:console_output).raises(Fog::Errors::Error)
          end
        end

        it 'should explain what went wrong' do
          subject
          @logs.join.should match /Could not read the host's fingerprints/
        end

        it 'should provide further instructions' do
          subject
          @logs.join.should match /verify the host's fingerprints through/
        end

        it 'should have a non-nil return value' do
          subject.should_not be_nil
        end
      end

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

  describe '#create_connection' do
    it 'should create a new connection' do
      Fog::Compute.expects(:new)
      subject.create_connection()
    end
  end

  describe '#create_server' do
    it 'should create a new server' do
      options = { :image_id => 'ami-12345' }
      servers = mock { expects(:create).with(options) }
      subject.create_server(servers, options)
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
      subject.create_tags(tags, mock(:id => 'i-1234'))
    end
  end
end