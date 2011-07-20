require 'spec_helper'
require 'puppet/cloudpack'

describe Puppet::Face[:node, :current] do
  before :each do
    @options = {
      :node_group => 'webserver'
    }
  end

  describe 'option validation' do
    describe '(node-group)' do
      it 'should not call dashboard_classify if node_group is not supplied' do
        @options.delete(:node_group)
        subject.expects(:dashboard_classify).never
        subject.classify('server', @options)
      end
      it 'should call dashboard_classify if a node_group is specified' do
        Puppet::CloudPack.expects(:dashboard_classify).with('server', @options).once
        subject.classify('server', @options)
      end
    end
  end
end
