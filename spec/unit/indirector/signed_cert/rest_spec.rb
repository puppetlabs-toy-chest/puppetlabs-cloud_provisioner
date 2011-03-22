#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../../spec_helper.rb')
require 'puppet/ssl/signed_cert'

describe "Puppet::SSL::SignedCert::Rest" do
  before do
    @terminus = Puppet::SSL::SignedCert::Rest.indirection.terminus(:rest)
  end

  it "should be a terminus on SignedCert" do
    @terminus.should be_instance_of(Puppet::SSL::SignedCert::Rest)
  end
end
