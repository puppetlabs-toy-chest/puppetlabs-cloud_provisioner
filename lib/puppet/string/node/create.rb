require 'rubygems'
require 'fog'

Puppet::String.define :node, '0.0.1' do
  script :create do
    puts "Connecting to AWS..."
    connection = Fog::Compute.new(
      :provider => 'AWS',
      :aws_access_key_id => ENV['AWS_ACCESS_KEY'],
      :aws_secret_access_key => ENV['AWS_SECRET_KEY']
    )

    puts "Creating new instance..."
    server = connection.servers.create(
      :image_id => ENV['IMAGE_ID'],
      :key_name => ENV['KEY_NAME'],
      :groups   => (ENV['SECURITY_GROUP'] || '').split(File::PATH_SEPARATOR)
    )

    puts "Starting up..."
    print '.' while server.reload.state == 'pending'
    puts ' Done'

    if server.state == 'running'
      # TODO: Find a better way of getting the Fingerprints
      puts "Waiting to capture console output..."
      while server.console_output.body['output'].nil?
        print '.'
        sleep 2
      end
      puts ' Done'
      puts

      server.console_output.body['output'].each_line do |line|
        puts line if line =~ /^ec2:/
      end

      puts "Running as: #{server.dns_name}"
    else
      puts "Failed: #{server.state_reason.inspect}"
    end

    server
  end
end
