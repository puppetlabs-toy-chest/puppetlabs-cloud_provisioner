#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper.rb')
require 'puppet/ssl/signed_cert'

describe Puppet::SSL::SignedCert do
  before do
    @signer = Puppet::SSL::SignedCert.new("mysigner")
    Puppet::SSL::CertificateAuthority.stubs(:ca?).returns true
  end

  it "should have a name" do
    @signer.name.should == "mysigner"
  end
end
