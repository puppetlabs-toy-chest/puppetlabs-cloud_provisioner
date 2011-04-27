require 'spec_helper'
require 'puppet/cloudpack'

describe Puppet::Face[:node, :current] do
  before :each do
    @options = {
      :node_group => 'webserver'
    }
  end

  describe 'option validation' do
    before :each do
      Puppet::CloudPack.stubs(:classify)
    end

    describe '(node-group)' do
      it 'should require a provider' do
        @options.delete(:node_group)
        expect { subject.classify('server', @options) }.to raise_error ArgumentError, /required/
      end
    end
  end
end
