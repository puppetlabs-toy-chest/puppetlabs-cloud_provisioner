require 'spec_helper'

describe Puppet::Face[:node, '0.0.1'] do
  before(:all) { @stdout, $stdout = $stdout, StringIO.new(@buffer = '') }
  after(:all)  { $stdout = @stdout }

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

      subject { Puppet::Face[:node, '0.0.1'] }

      it 'should destroy the specified instance' do
        args = { 'dns-name' => 'some.name' }
        @servers.expects(:all).with(args).returns([@server])
        @server.expects(:destroy)

        subject.terminate('some.name')
      end
    end
  end
end
