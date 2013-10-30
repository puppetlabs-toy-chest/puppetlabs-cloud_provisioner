require 'spec_helper'
require 'puppet/cloudpack'

describe Puppet::Face[:node_aws, :current] do
  before :each do
    @options = {
      :image             => 'ami-12345',
      :keyname           => 'some_keypair',
      :login             => 'ubuntu',
      :keyfile           => 'file_on_disk.txt',
      :installer_payload => 'some.tar.gz',
      :installer_answers => 'some.answers',
      :node_group        => 'webserver',
      :type              => 'm1.small',
    }
  end

  describe 'option validation' do
    before :each do
      Puppet::CloudPack.expects(:bootstrap).never
    end

    describe '(image)' do
      it 'should require an image' do
        @options.delete(:image)
        expect { subject.bootstrap(@options) }.to raise_error ArgumentError, /required/
      end
    end

    describe '(keypair)' do
      it 'should require a keypair name' do
        @options.delete(:keyname)
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

  end
end
