require 'puppet/indirector/face'

Puppet::Face.define(:node_rackspace, '0.0.1') do
  copyright "Puppet Labs", 2011
  license   "Puppet Enterprise Software License Agreement"

  summary "View and manage Rackspace Cloud Servers"
  description <<-'EOT'
    View and manage Rackspace Cloud Servers
  EOT
end
