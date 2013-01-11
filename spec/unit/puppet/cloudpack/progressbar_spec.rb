require 'spec_helper'

describe "Puppet::CloudPack.constants" do
  subject { Puppet::CloudPack.constants.collect { |k| k.to_s } }
  it { should include("ProgressBar") }
end
