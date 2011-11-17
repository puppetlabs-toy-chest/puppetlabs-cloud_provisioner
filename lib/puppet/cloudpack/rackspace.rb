require 'fog'

module Puppet::CloudPack
  class Rackspace

    attr_accessor :connection

    def initialize(options, connection=nil)
      @options    = options
      @connection = connection || create_connection
    end

    def create_connection(options = {})
      Puppet.notice "Connecting ..."
      connection = Fog::Compute[:rackspace]
      Puppet.notice "Connected to Rackspace"
      connection
    end

    def list_images
      images = @connection.list_images_detail.attributes
      {:kind => @options[:kind], :images => images[:body]['images']}
    end

    def list_flavors
      flavors = @connection.list_flavors_detail.attributes
      {:kind => @options[:kind], :flavors => flavors[:body]['flavors']}
    end

    def list_servers
      servers = @connection.servers
      if servers.empty?
        s = {}
      else
        s = servers.collect {|s| s.attributes}
      end
      {:kind => @options[:kind], :servers => s}
    end

    def create
      # Both image_id and flavor_id must be integers.
      # FIXME image_id and flavor_id should be validated.
      new_attributes = {
        :image_id  => @options[:image_id].to_i,
        :flavor_id => @options[:flavor_id].to_i,
        :name => @options[:name],
        :public_key_path => @options[:public_key],
        :username => @options[:root]
      }
      server = @connection.servers.create(new_attributes)

      # We cannot upload the SSH public key until the Rackspace
      # Cloud Server is fully booted.
      if @options[:public_key] | @options[:wait_for_boot]
        Puppet.notice "Waiting for server to boot ..."
        server.wait_for { ready? }
      end
      if @options[:public_key]
        Puppet.notice "Adding SSH public key ..."
        server.setup(:password => server.password)
      end

      # The login password is masked with '*' characters unless
      # the --show-password option is set to true.
      password = get_admin_password(server, @options[:show_password])
      [{:password => password, :status => 'success'}.merge(server.attributes)]
    end

    def get_admin_password(server, show_password=false)
      if show_password
        server.password
      else
        server.password.gsub(/./, '*')
      end
    end

    def find
      server = @connection.servers.get(@options[:server_id])
      if server.nil?
        Puppet.notice "Cannot find a server with id: #{@options[:server_id]}"
        []
      else
        [server.attributes]
      end
    end

    def reboot
      server = @connection.servers.get(@options[:server_id])
      if server.nil?
        Puppet.notice "Cannot find a server with id: #{@options[:server_id]}"
      else
        server.reboot
      end
      {'status' => 'success'}
    end

    def terminate
      server = @connection.servers.get(@options[:server_id])
      if server.nil?
        Puppet.notice "Cannot find a server with id: #{@options[:server_id]}"
      else
        server.destroy
      end
      {'status' => 'success'}
    end
  end
end
