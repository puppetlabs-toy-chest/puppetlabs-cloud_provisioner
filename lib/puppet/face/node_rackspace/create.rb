require 'puppet/face'
require 'puppet/cloudpack/rackspace'

Puppet::Face.define(:node_rackspace, '0.0.1') do
  action :create do
    summary "Create Rackspace Cloud Servers"
    description <<-'EOT'
      Create Rackspace Cloud Servers.
    EOT

    returns 'Array of Cloud Server attribute hashes.'

    examples <<-'EOT'
    Create a Rackspace Cloud server.

      $ puppet node_rackspace create -f 1 -i 104 -n demo

    Create a Rackspace Cloud server and unmask the admin password in the output.

      $ puppet node_rackspace create -f 1 -i 104 -n demo --show-password

    Create a Rackspace Cloud server and wait for it to boot.

      $ puppet node_rackspace create -f 1 -i 104 -n demo -w

    Create a Rackspace Cloud Server, wait for it to boot, then add the specificed SSH public key.

      $ puppet node_rackspace create -f 1 -i 104 -n demo -p ~/.ssh/id_rsa.pub
    EOT

    option '--flavor-id=', '-f=' do
      required
      summary 'The Rackspace Cloud Server flavor id.'
      description <<-'EOT'
        A flavor is an available hardware configuration for a server.
        Each flavor has a unique combination of disk space, memory capacity
        and priority for CPU time. Flavors are identified by id. Use the
        puppet node_rackspace list flavors command to get a list of
        available flavors.
      EOT
    end

    option '--image-id=', '-i=' do
      required
      summary 'The Rackspace Cloud Server image id.'
      description <<-'EOT'
        An image is a collection of files used to create or rebuild a server.
        Images are identified by id. Use the puppet node_rackspace list images
        command to get list of available images.
      EOT
    end

    option '--name=', '-n=' do
      summary 'The Rackspace Cloud Server name.'
      description <<-'EOT'
        The Rackspace Cloud Server name attribute. Note, server names are not
        unique across servers. When referring to a specific server, the
        server id should be used.
      EOT
    end

    option '--public-key=', '-p=' do
      default_to { nil }
      summary 'The SSH public key path on disk.'
      description <<-'EOT'
        The path to the SSH public key on disk, which will be uploaded to the
        server once it has completed the provisioning process.
      EOT
    end

    option '--show-password' do
      default_to { false }
      summary 'Show the instance root password.'
      description <<-'EOT'
        Toggle the visibility of the root password in the output following the
        creating of a new Rackspace Cloud Server.
      EOT
    end

    option '--wait-for-boot', '-w' do
      default_to { false }
      summary 'Wait for server to boot'
      description <<-'EOT'
        Wait for the server to boot.
      EOT
    end

    when_invoked do |options|
      rackspace = Puppet::CloudPack::Rackspace.new(options)
      rackspace.create
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
        "  progress:  #{server[:progress]}\n" <<
        "  password:  #{server[:password]}\n"
      end.join("\n")
    end
  end
end
