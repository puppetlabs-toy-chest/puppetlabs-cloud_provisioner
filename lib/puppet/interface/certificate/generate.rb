# Sign a remote certificate.
Puppet::Interface::Certificate_CA_MODES = {
    # Our ca is local, so we use it as the ultimate source of information
    # And we cache files locally.
    :local => :file,
    # We're a remote CA client.
    :remote => :rest,
    # We are the CA, so we don't have read/write access to the normal certificates.
    :only => :file,
    # We have no CA, which means this is meaningless
    :none => nil
  }

Puppet::Interface::Certificate.action :sign do |name|
  require 'puppet/ssl/signed_cert'

  location = Puppet::SSL::Host.ca_location
  unless terminus = Puppet::Interface::Certificate_CA_MODES[location]
    raise ArgumentError, "You must have a ca specified; use --ca to specify the location (remote, local, only)"
  end

  if location == :local and ! Puppet::SSL::CertificateAuthority.ca?
    Puppet::Application[:certificate].class.run_mode("master")
    set_run_mode Puppet::Application[:certificate].class.run_mode
  end

  Puppet::SSL::SignedCert.indirection.terminus_class = terminus

  Puppet::SSL::SignedCert.indirection.save(Puppet::SSL::SignedCert.new(name))
end
