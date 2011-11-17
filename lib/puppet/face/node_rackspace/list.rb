require 'puppet/face'
require 'puppet/cloudpack/rackspace'

Puppet::Face.define(:node_rackspace, '0.0.1') do
  action :list do
    summary "List Rackspace Cloud Servers"
    description <<-'EOT'
      List Rackspace Cloud servers, images, or flavors.
    EOT

    returns 'Array of Cloud Server attribute hashes.'

    examples <<-'EOT'
      $ puppet node_rackspace list servers

      $ puppet node_rackspace list images

      $ puppet node_rackspace list flavors
    EOT

    arguments "<kind>"

    when_invoked do |kind, options|
      valid_kinds = ['servers', 'images', 'flavors']
      if valid_kinds.include?(kind)
        options[:kind] = kind
        rackspace = Puppet::CloudPack::Rackspace.new(options)
        rackspace.send(:"list_#{kind}")
      else
        raise ArgumentError, "Invalid search type, kind must be one of [flavors, images, or servers]"
      end
    end

    when_rendering :console do |return_value|
      Puppet.notice "Complete"
      case return_value[:kind]
      when 'servers'
        return_value[:servers].map do |server|
          "#{server[:id]}:\n" <<
          "  name:      #{server[:name]}\n" <<
          "  serverid:  #{server[:id]}\n" <<
          "  hostid:    #{server[:host_id]}\n" <<
          "  ipaddress: #{server[:addresses]["public"]}\n" <<
          "  state:     #{server[:state]}\n" <<
          "  progress:  #{server[:progress]}\n"
        end.join("\n")
      when 'images'
        return_value[:images].map do |image|
          "#{image['name']}:\n" <<
          "  id:      #{image['id']}\n" <<
          "  updated: #{image['updated']}\n" <<
          "  status:  #{image['status']}\n"
        end.join("\n")
      when 'flavors'
        return_value[:flavors].map do |flavor|
          "#{flavor['name']}:\n" <<
          "  id:   #{flavor['id']}\n" <<
          "  ram:  #{flavor['ram']}\n" <<
          "  disk: #{flavor['disk']}\n"
        end.join("\n")
      end
    end
  end
end
