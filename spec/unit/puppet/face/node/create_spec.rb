require 'spec_helper'
require 'puppet/cloudpack'

describe Puppet::Face[:node, :current] do
  before :each do
    @options = {
      :platform => 'AWS',
      :image    => 'ami-12345',
      :keypair  => 'some_keypair'
    }
  end

  describe 'option validation' do
    before :each do
      Puppet::CloudPack.stubs(:create)
    end

    it 'should require a provider' do
      @options.delete(:platform)
      expect { subject.create(@options) }.to raise_error ArgumentError, /required/
    end

    it 'should validate the provider' do
      @options[:platform] = 'UnsupportedProvider'
      expect { subject.create(@options) }.to raise_error ArgumentError, /one of/
    end
  end
end
