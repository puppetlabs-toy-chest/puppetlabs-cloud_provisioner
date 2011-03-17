#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../spec_helper.rb')
require 'puppet/provisioner'

describe Puppet::Provisioner do
  before do
    @provisioner = Puppet::Provisioner.new
  end

  it "should have a name"

  describe "when bootstrapping" do
    it "should require an IP address and a root password"

    it "should ssh to the machine, install the initializer, and run the initializer"
  end

  describe "when initializing" do
    it "should download/receive? the PE installer"

    it "should run the installer with answers"

    it "should generate a certificate request"

    it "should register itself with the server"
  end
end
