require 'spec_helper'
require 'puppet/cloudpack'

describe Puppet::Face[:cloudnode, :current] do
  before :each do
    @options = {
      :platform => 'AWS'
    }
  end

  describe 'option validation' do
    describe '(platform)' do
      it 'should not require a platform' do
        @options.delete(:platform)
        # JJM This is absolutely not ideal, but I cannot for the life of me
        # figure out how to effectively deal with all of the create_connection
        # method calls in the option validation code.
        Puppet::CloudPack.stubs(:create_connection).with() do |options|
          raise(Exception, "#{options[:platform] == 'AWS'}")
        end
        expect { subject.terminate('server', @options) }.to raise_error Exception, 'true'
      end

      it 'should validate the platform' do
        @options[:platform] = 'UnsupportedProvider'
        expect { subject.terminate('server', @options) }.to raise_error ArgumentError, /one of/
      end
    end
  end
end
