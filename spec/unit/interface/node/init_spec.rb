#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../../spec_helper.rb')
require 'puppet/interface/node'

describe "Puppet::Interface::Node when initializing" do
  before do
    @interface = Puppet::Interface.interface(:catalog)
  end
end
