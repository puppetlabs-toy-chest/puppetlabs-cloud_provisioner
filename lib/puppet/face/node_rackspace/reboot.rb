require 'puppet/face'
require 'puppet/cloudpack/rackspace'

Puppet::Face.define(:node_rackspace, '0.0.1') do
  action :reboot do
    summary "Reboot a Rackspace Cloud Server"
    description <<-'EOT'
      Reboot a single Rackspace Cloud Server by server id.
    EOT

    returns 'Hash containing the status'

    examples <<-'EOT'
      $ puppet node_rackspace reboot 12345678
    EOT

    arguments "<server_id>"

    when_invoked do |server_id, options|
      options[:server_id] = server_id
      rackspace = Puppet::CloudPack::Rackspace.new(options)
      rackspace.reboot
    end
  end
end
