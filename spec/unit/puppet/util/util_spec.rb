require 'spec_helper'
require 'puppet/cloudpack/util/util'


describe Puppet::CloudPack::Util do
  describe 'retry_action' do
    it "should require a block" do
      expect {Puppet::CloudPack::Util.retry_action(retries=2)}.to raise_error(Puppet::CloudPack::Util::RetryException, 'No block given')
    end
    
    it "should retry the number of retries specified" do
      attempts = 0
      Puppet::CloudPack::Util.retry_action(retries=3) do
        attempts += 1
        raise
      end
      attempts.should == 3
    end
  end 
end