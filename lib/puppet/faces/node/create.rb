require 'rubygems'
require 'fog'

Puppet::Faces.define :node, '0.0.1' do
  action :create do
    # TODO: Should mark certain options as required.
    # TODO: Validate parameters.
    option '--image=', '-i='
    option '--keypair=', '-k='
    option '--group=', '-g=', '--security-group='
    when_invoked do |options|
      unless options.has_key? :_destroy_server_at_exit
        options[:_destroy_server_at_exit] = :create
      end

      connection = create_connection()

      # TODO: Validate that the security groups permit SSH access from here.
      # TODO: Can this throw errors?
      server     = create_server(connection.servers,
        :image_id => options[:image],
        :key_name => options[:keypair],
        :groups   => (options[:group] || '').split(File::PATH_SEPARATOR)
      )

      Signal.trap(:EXIT) do
        if options[:_destroy_server_at_exit]
          server.destroy rescue nil
        end
      end

      create_tags(connection.tags, server)

      print 'Starting up '
      retries = 0
      begin
        server.wait_for do
          print '.'
          self.ready?
        end
        puts ' Done'
      rescue Fog::Errors::Error
        puts "Failed"
        Puppet.err "Could not connect to host"
        Puppet.err "Please check your network connection and try again"
        return nil
      end

      # TODO: Find a better way of getting the Fingerprints
      begin
        print 'Waiting for host fingerprints '
        Fog.wait_for do
          print '.'
          not server.console_output.body['output'].nil?
        end or raise Fog::Errors::Error, "Waiting for host fingerprints timed out"
        puts ' Done'

        puts *server.console_output.body['output'].grep(/^ec2:/)
      rescue Fog::Errors::Error => e
        puts "Failed"
        Puppet.warning "Could not read the host's fingerprints"
        Puppet.warning "Please verify the host's fingerprints through AWS"
      end

      if options[:_destroy_server_at_exit] == :create
        options.delete(:_destroy_server_at_exit)
      end

      return server.dns_name
    end
  end

  def create_connection(options = { :provider => 'AWS' })
    print 'Connecting to AWS ...'
    connection = Fog::Compute.new(options)
    puts ' Done'
    return connection
  end

  def create_server(servers, options = {})
    print 'Creating new instance ...'
    server = servers.create(options)
    puts ' Done'
    return server
  end

  def create_tags(tags, server)
    print 'Creating tags for instance ...'
    tags.create(
      :key         => 'Created-By',
      :value       => 'Puppet',
      :resource_id => server.id
    )
    puts ' Done'
  end
end
