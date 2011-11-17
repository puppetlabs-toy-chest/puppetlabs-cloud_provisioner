require 'puppet/face'
require 'puppet/cloudpack/rackspace'

Puppet::Face.define(:node_rackspace, '0.0.1') do
  action :find do
    summary "Find Rackspace Cloud Servers"
    description <<-'EOT'
      Find Rackspace Cloud Servers by server id.
    EOT

    returns 'Array of Cloud Server attribute hashes.'

    examples <<-'EOT'
      $ puppet node_rackspace find 12345678
    EOT

    arguments "<server_id>"

    when_invoked do |server_id, options|
      options[:server_id] = server_id
      rackspace = Puppet::CloudPack::Rackspace.new(options)
      rackspace.find
    end

    when_rendering :console do |return_value|
      Puppet.notice "Complete"
      return_value.map do |server|
        "#{server[:id]}:\n" <<
        "  name:      #{server[:name]}\n" <<
        "  serverid:  #{server[:id]}\n" <<
        "  hostid:    #{server[:host_id]}\n" <<
        "  ipaddress: #{server[:addresses]["public"]}\n" <<
        "  state:     #{server[:state]}\n" <<
        "  progress:  #{server[:progress]}\n"
      end.join("\n")
    end
  end
end
