require 'rubygems'
require 'fog'

Puppet::Face.define :node, '0.0.1' do
  action :terminate do
    option '--force', '-f'
    when_invoked do |server, options|
      connection = create_connection()

      servers = connection.servers.all('dns-name' => server)
      if servers.length == 1 || options[:force]
        servers.each { |server| server.destroy() }
      elsif servers.empty?
        Puppet.warning "Could not find server with DNS name '#{server}'"
      else
        Puppet.err "More than one server with DNS name '#{server}'; aborting"
      end

      nil
    end
  end
end