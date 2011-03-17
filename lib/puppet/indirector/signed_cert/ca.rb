require 'puppet'
require 'puppet/ssl/signed_cert'

class Puppet::SSL::SignedCert::Ca < Puppet::Indirector::Code
  def ca
    raise ArgumentError, "This process is not configured as a certificate authority" unless Puppet::SSL::CertificateAuthority.ca?
    Puppet::SSL::CertificateAuthority.new
  end

  def save(request)
    name = request.key
    instance = request.instance

    if instance.csr
      puppet_csr = Puppet::SSL::CertificateRequest.new(request.key)
      puppet_csr.content = instance.csr
      puppet_csr.class.indirection.save(puppet_csr)
    end

    ca.sign(request.key)
  end
end
