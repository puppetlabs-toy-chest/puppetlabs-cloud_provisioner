#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../../spec_helper.rb')
require 'puppet/interface/certificate'

describe "Puppet::Interface::Certificate#sign" do
  before do
    @interface = Puppet::Interface::Certificate
    @old_ca_location = Puppet::SSL::Host.ca_location
  end

  after do
    Puppet::SSL::Host.ca_location = @old_ca_location if @old_ca_location
  end

  it "should fail if the ca location is set to :none" do
    Puppet::SSL::Host.ca_location = :none
    lambda { @interface.sign("foo") }.should raise_error(ArgumentError, /--ca/)
  end

  it "should set the run mode to master when the CA is local"

  it "should set the terminus to :file if the CA is 'local'"

  it "should set the terminus to :rest if the CA is 'remote'"

  it "should set the terminus to :file if the CA is 'only'"
end
