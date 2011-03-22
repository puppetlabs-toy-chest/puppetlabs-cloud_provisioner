#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../../spec_helper.rb')
require 'puppet/ssl/signed_cert'
require 'tempfile'

describe "Puppet::SSL::SignedCert::File" do
  before do
    Puppet::SSL::CertificateAuthority.stubs(:ca?).returns true
    @terminus = Puppet::SSL::SignedCert.indirection.terminus(:file)

    @tmpdir = Tempfile.new("signed_cert_ca_testing")
    @tmpdir.close
    File.unlink(@tmpdir.path)
    Dir.mkdir(@tmpdir.path)
    Puppet[:confdir] = @tmpdir.path
    Puppet[:vardir] = @tmpdir.path
  end

  it "should be a terminus on SignedCert" do
    @terminus.should be_instance_of(Puppet::SSL::SignedCert::File)
  end

  it "should create a CA instance if none is present" do
    @terminus.ca.should be_instance_of(Puppet::SSL::CertificateAuthority)
  end

  describe "when creating the CA" do
    it "should fail if it is not a valid CA" do
      Puppet::SSL::CertificateAuthority.expects(:ca?).returns false
      lambda { @terminus.ca }.should raise_error(ArgumentError)
    end
  end

  it "should be indirected with the name 'signed_cert'" do
    Puppet::SSL::SignedCert.indirection.name.should == :signed_cert
  end

  describe "when saving" do
    before do
      @signer = Puppet::SSL::SignedCert.new("mysigner")
      @request = Puppet::Indirector::Request.new(:signed_cert, :save, "mysigner", @signer)
      @csr = mk_csr("mysigner")

      FileUtils.mkdir_p(Puppet[:requestdir])
    end

    def mk_csr(name)
      @key = Puppet::SSL::Key.new(name)
      @key.generate

      csr = Puppet::SSL::CertificateRequest.new(name)
      csr.generate(@key)

      csr
    end

    it "should fail if no CSR is provided and no CSR is on disk" do
      lambda { @terminus.save(@request) }.should raise_error(ArgumentError, /certificate request/)
    end

    it "should save the CSR and sign it if one is provided" do
      Puppet::SSL::CertificateRequest.indirection.find("mysigner").should be_nil
      @signer.csr = @csr.content
      @terminus.save(@request)

      Puppet::SSL::Certificate.indirection.find("mysigner").should be_instance_of(Puppet::SSL::Certificate)
    end

    it "should sign the on-disk CSR if present and none is provided" do
      @csr.class.indirection.save(@csr)

      @terminus.save(@request)

      Puppet::SSL::Certificate.indirection.find("mysigner").should be_instance_of(Puppet::SSL::Certificate)
    end

    it "should replace the on-disk CSR with any provided CSR and sign it" do
      csr1 = mk_csr("signer")
      csr1.class.indirection.save(csr1)

      csr2 = mk_csr("signer")
      @signer.csr = csr2.content
      @terminus.save(@request)

      cert = Puppet::SSL::Certificate.indirection.find("mysigner")

      cert.content.public_key.to_s.should_not == csr1.content.public_key.to_s
      cert.content.public_key.to_s.should == csr2.content.public_key.to_s
    end
  end
end
