require 'spec_helper'
require 'puppet/cloudpack'

describe Puppet::Face[:node, :current] do
  before :each do
    @options = {
      :login             => 'ubuntu',
      :keyfile           => 'file_on_disk.txt',
      :installer_payload => 'some.tar.gz',
      :installer_answers => 'some.answers',
      :node_group        => 'webserver'
    }
  end

  describe 'option validation' do
    before :each do
      Puppet::CloudPack.stubs(:init)
    end

    describe '(login)' do
      it 'should require a login' do
        @options.delete(:login)
        expect { subject.init('server', @options) }.to raise_error ArgumentError, /required/
      end
    end

    describe '(keyfile)' do
      it 'should require a keyfile' do
        @options.delete(:keyfile)
        expect { subject.init('server', @options) }.to raise_error ArgumentError, /required/
      end
    end

    describe '(installer-payload)' do
      it 'should require an installer payload' do
        @options.delete(:installer_payload)
        expect { subject.init('server', @options) }.to raise_error ArgumentError, /required/
      end
    end

    describe '(installer-answers)' do
      it 'should require an answers file' do
        @options.delete(:installer_answers)
        expect { subject.init('server', @options) }.to raise_error ArgumentError, /required/
      end
    end

    describe '(node-group)' do
      it 'should require a provider' do
        @options.delete(:node_group)
        expect { subject.init('server', @options) }.to raise_error ArgumentError, /required/
      end
    end
  end
end
