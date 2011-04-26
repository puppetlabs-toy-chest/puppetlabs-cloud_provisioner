require 'rubygems'
require 'fog'

Puppet::Face.define :node, '0.0.1' do
  action :terminate do
    when_invoked do |server, options|
      connection = create_connection()

      servers = connection.servers.all('dns-name' => server)
      servers.each do |server|
        server.destroy()
      end

      nil
    end
  end
end