require 'spec_helper'
require 'template_helper'
require 'puppet'
require 'puppet/cloudpack'
require 'puppet/cloudpack/installer'

describe Puppet::CloudPack::Installer do
  describe 'when searching for file location' do
    it 'should override the system script with a user script' do
      with_mock_user_template do |template_id|
        subject.find_template(template_id).should == File.join(Puppet[:confdir], 'scripts', template_id + '.erb')
      end
    end
    it 'should be able to use a lib version' do
      subject.find_template('puppet-enterprise').should == File.join(subject.lib_script_dir, 'puppet-enterprise.erb')
    end
    it 'should fail when it cannot find a script' do
      now = Time.now.to_i
      expect { subject.find_template("foo_#{now}") }.to raise_error(Exception, /Could not find/)
    end
  end

  describe 'when compiling the script' do
    it 'should be able to compile erb templates' do
      with_mock_user_template do |template_id|
        subject.build_installer_template(template_id, {:variable => 'bar'}).should == 'Here is a bar'
      end
    end
  end
end
