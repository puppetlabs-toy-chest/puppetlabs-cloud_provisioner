require 'rubygems'
require 'fog'

Puppet::Faces.define :node, '0.0.1' do
  action :create do
    option '--image=', '-i='
    option '--keypair=', '-k='
    option '--group=', '-g=', '--security-group='
    when_invoked do |options|
      unless options.has_key? :_destroy_server_at_exit
        options[:_destroy_server_at_exit] = :create
      end

      print "Connecting to AWS ..."
      connection = Fog::Compute.new(:provider => 'AWS')
      puts " Done"

      print "Creating new instance ..."
      server = connection.servers.create(
        :image_id => options[:image],
        :key_name => options[:keypair],
        :groups   => (options[:group] || '').split(File::PATH_SEPARATOR)
      )
      Signal.trap(:EXIT) do
        if options[:_destroy_server_at_exit]
          server.destroy rescue nil
        end
      end
      connection.tags.create(
        :key         => 'Created-By',
        :value       => 'Puppet',
        :resource_id => server.id
      )
      puts ' Done'
      print "Starting up "
      start_time = Time.now
      begin
        while server.state == 'pending'
          print '.'
          server.reload
        end 
      rescue Excon::Errors::SocketError => e
        sleep 2
        print "E"
        raise "Cannot connect to AWS; aborting." if Time.now - start_time > 360
        retry
      end
      puts " Done"

      if server.state == 'running'
        # TODO: Find a better way of getting the Fingerprints
        print "Waiting for host fingerprints "
       start_time = Time.now
        begin
          while server.console_output.body['output'].nil?
            print '.'
            sleep 2
          end
        rescue Excon::Errors::SocketError => e
          sleep 2
          print "E"
          raise "Cannot connect to AWS; aborting." if Time.now - start_time > 360
          retry
        end
        puts ' Done'
        puts

        server.console_output.body['output'].each_line do |line|
          puts line if line =~ /^ec2:/
        end

        if options[:_destroy_server_at_exit] == :create
          options.delete(:_destroy_server_at_exit)
        end
        return server.dns_name
      else
        puts "Failed: #{server.state_reason.inspect}"
      end
    end
  end
end
