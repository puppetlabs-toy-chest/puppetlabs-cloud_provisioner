require 'spec_helper'
require 'puppet/cloudpack'

describe Puppet::Face[:node, :current] do
  before :each do
    @options = {
      :platform          => 'AWS',
      :image             => 'ami-12345',
      :keypair           => 'some_keypair',
      :login             => 'ubuntu',
      :keyfile           => 'file_on_disk.txt',
      :installer_payload => 'some.tar.gz',
      :installer_answers => 'some.answers',
      :node_group        => 'webserver'
    }
  end

  describe 'option validation' do
    before :each do
      Puppet::CloudPack.stubs(:bootstrap)
    end

    describe '(platform)' do
      it 'should require a platform' do
        @options.delete(:platform)
        expect { subject.create(@options) }.to raise_error ArgumentError, /required/
      end

      it 'should validate the platform' do
        @options[:platform] = 'UnsupportedProvider'
        expect { subject.bootstrap(@options) }.to raise_error ArgumentError, /one of/
      end
    end

    describe '(image)' do
      it 'should require an image' do
        @options.delete(:image)
        expect { subject.bootstrap(@options) }.to raise_error ArgumentError, /required/
      end
    end

    describe '(keypair)' do
      it 'should require a keypair name' do
        @options.delete(:keypair)
        expect { subject.bootstrap(@options) }.to raise_error ArgumentError, /required/
      end
    end

    describe '(login)' do
      it 'should require a login' do
        @options.delete(:login)
        expect { subject.bootstrap(@options) }.to raise_error ArgumentError, /required/
      end
    end

    describe '(keyfile)' do
      it 'should require a keyfile' do
        @options.delete(:keyfile)
        expect { subject.bootstrap(@options) }.to raise_error ArgumentError, /required/
      end
    end

    describe '(installer-payload)' do
      it 'should require an installer payload' do
        @options.delete(:installer_payload)
        expect { subject.bootstrap(@options) }.to raise_error ArgumentError, /required/
      end
    end

    describe '(installer-answers)' do
      it 'should require an answers file' do
        @options.delete(:installer_answers)
        expect { subject.bootstrap(@options) }.to raise_error ArgumentError, /required/
      end
    end

    describe '(node-group)' do
      it 'should require a provider' do
        @options.delete(:node_group)
        expect { subject.bootstrap(@options) }.to raise_error ArgumentError, /required/
      end
    end
  end
end
