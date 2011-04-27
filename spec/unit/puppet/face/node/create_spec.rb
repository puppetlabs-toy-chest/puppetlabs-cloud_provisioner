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

    describe '(platform)' do
      it 'should require a platform' do
        @options.delete(:platform)
        expect { subject.create(@options) }.to raise_error ArgumentError, /required/
      end

      it 'should validate the platform' do
        @options[:platform] = 'UnsupportedProvider'
        expect { subject.create(@options) }.to raise_error ArgumentError, /one of/
      end
    end

    describe '(image)' do
      it 'should require an image' do
        @options.delete(:image)
        expect { subject.create(@options) }.to raise_error ArgumentError, /required/
      end
    end

    describe '(keypair)' do
      it 'should require a keypair name' do
        @options.delete(:keypair)
        expect { subject.create(@options) }.to raise_error ArgumentError, /required/
      end
    end
  end
end
