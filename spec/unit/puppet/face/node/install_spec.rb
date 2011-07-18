require 'spec_helper'
require 'puppet/cloudpack'
require 'tempfile'

describe Puppet::Face[:node, :current] do
  before :each do
    @options = {
      :login             => 'ubuntu',
      :keyfile           => Tempfile.new('file_on_disk.txt').path,
      :installer_payload => Tempfile.new('some.tar.gz').path,
      :installer_answers => Tempfile.new('some.answers').path
    }
  end

  after :each do
    File.delete(@options[:keyfile])           if test 'f', @options[:keyfile]
    File.delete(@options[:installer_payload]) if test 'f', @options[:installer_payload]
    File.delete(@options[:installer_answers]) if test 'f', @options[:installer_answers]
  end

  describe 'option validation' do
    before :each do
      Puppet::CloudPack.expects(:install).never
    end

    describe '(login)' do
      it 'should require a login' do
        @options.delete(:login)
        expect { subject.install('server', @options) }.to raise_error ArgumentError, /required/
      end
    end

    describe '(keyfile)' do
      it 'should require a keyfile' do
        (opts = @options.dup).delete :keyfile
        expect { subject.install('server', opts) }.to raise_error ArgumentError, /required/
      end

      it 'should validate the keyfile name for existence' do
        opts = @options.update :keyfile => '/dev/null/nonexistent.file'
        expect { subject.install('server', opts) }.to raise_error ArgumentError, /could not find/i
      end

      it 'should validate the keyfile name for readability' do
        File.chmod 0300, @options[:keyfile]
        expect { subject.install('server', @options) }.to raise_error ArgumentError, /could not read/i
      end
    end

    describe '(installer-payload)' do

      it 'should validate the installer payload for existence' do
        opts = @options.update :installer_payload => '/dev/null/nonexistent.file'
        expect { subject.install('server', opts) }.to raise_error ArgumentError, /could not find/i
      end

      it 'should validate the installer payload for readability' do
        File.chmod 0300, @options[:installer_payload]
        expect { subject.install('server', @options) }.to raise_error ArgumentError, /could not read/i
      end

      it 'should warn if the payload does not have either tgz or gz extension' do
        @options[:installer_payload] = Tempfile.new('foo.tar').path
        Puppet.expects(:warning).with("Option: intaller-payload expects a .tgz or .gz file")
        Puppet::CloudPack.expects(:install)
        subject.install('server', @options)
      end
    end

    describe '(installer-answers)' do

      it 'should validate the answers file for existence' do
        opts = @options.update :installer_answers => '/dev/null/nonexistent.file'
        expect { subject.install('server', opts) }.to raise_error ArgumentError, /could not find/i
      end

      it 'should validate the answers file for readability' do
        File.chmod 0300, @options[:installer_answers]
        expect { subject.install('server', @options) }.to raise_error ArgumentError, /could not read/i
      end

      it 'should require an answers file if the script starts with puppet-enterprise-' do
        pending "The validation happens inside the install action, so this doesn't work because the install action is being mocked"
        opts = @options.dup
        opts.delete(:installer_payload)
        opts.delete(:installer_answers)
        opts[:installer_script] = "puppet-enterprise-s3"
        expect { subject.install('server', opts) }.to raise_error ArgumentError, /answers/i
      end

    end
    describe '(puppet-version)' do
      ['2.7.x', 'master', '2.6.9'].each do |version|
        it "should accept valid value #{version}" do
          opts = @options.update :puppet_version => version
          opts[:puppet_version].should == version
          Puppet::CloudPack.expects(:install)
          subject.install('server', @options)
        end
      end
      it 'should fail when invalid versions are specified' do
        opts = @options.update :puppet_version => '1.2.3.4'
        expect { subject.install('server', opts) }.to raise_error(ArgumentError, /Invaid Puppet version/)
      end
    end
  end
end
