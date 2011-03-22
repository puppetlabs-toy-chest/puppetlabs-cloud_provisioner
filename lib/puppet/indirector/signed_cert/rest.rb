require 'puppet/ssl/certificate'
require 'puppet/indirector/rest'

class Puppet::SSL::SignedCert::Rest < Puppet::Indirector::REST
  desc "Sign certificate requests over HTTP via REST."

  use_server_setting(:ca_server)
  use_port_setting(:ca_port)
end
