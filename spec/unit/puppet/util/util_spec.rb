require 'spec_helper'
require 'puppet/cloudpack/utils'


describe Puppet::CloudPack::Utils do
  describe 'retry_action' do
    it "should require a block" do
      expect {Puppet::CloudPack::Utils.retry_action(retries=2)}.to raise_error(Puppet::CloudPack::Utils::RetryException, 'No block given')
    end
    
    it "should retry the number of retries specified" do
      attempts = 0
      Puppet::CloudPack::Utils.retry_action(retries=3) do
        attempts += 1
        raise
      end
      attempts.should == 3
    end
  end 
end