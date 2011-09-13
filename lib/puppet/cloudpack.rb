require 'tempfile'
require 'rubygems'
require 'guid'
require 'fog'
require 'net/ssh'
require 'puppet/network/http_pool'
require 'timeout'

module Puppet::CloudPack
  require 'puppet/cloudpack/installer'
  class << self

    # Method to set AWS defaults in a central place.  Lots of things need these
    # defaults, so they all call merge_default_options() to ensure the keys are
    # set.
    def merge_default_options(options)
      default_options = { :region => 'us-east-1', :platform => 'AWS', :install_script => 'gems' }
      default_options.merge(options)
    end

    def add_region_option(action)
      action.option '--region=' do
        summary "The geographic region of the instance. Defaults to us-east-1."
        description <<-'EOT'
          The instance may run in any region EC2 operates within.  The regions at the
          time of this documentation are: US East (Northern Virginia), US West (Northern
          California), EU (Ireland), Asia Pacific (Singapore), and Asia Pacific (Tokyo).

          The region names for this command are: eu-west-1, us-east-1,
          ap-northeast-1, us-west-1, ap-southeast-1

          Note: to use another region, you will need to copy your keypair and reconfigure the
          security groups to allow SSH access.
        EOT
        before_action do |action, args, options|
          # JJM FIXME We shouldn't have to set the defaults here, but we do because the first
          # required action may not have it's #before_action evaluated yet.  As a result,
          # the default settings may not be evaluated.
          options = Puppet::CloudPack.merge_default_options(options)

          regions_response = Puppet::CloudPack.create_connection(options).describe_regions
          region_names = regions_response.body["regionInfo"].collect { |r| r["regionName"] }.flatten
          unless region_names.include?(options[:region])
            raise ArgumentError, "Region must be one of the following: #{region_names.join(', ')}"
          end
        end
      end
    end

    def add_platform_option(action)
      action.option '--platform=' do
        summary 'Platform used to create machine instance (only supports AWS).'
        description <<-EOT
          The Cloud platform used to create new machine instances.
          Currently, AWS (Amazon Web Services) is the only supported platform.
        EOT
        before_action do |action, args, options|
          supported_platforms = [ 'AWS' ]
          unless supported_platforms.include?(options[:platform])
            raise ArgumentError, "Platform must be one of the following: #{supported_platforms.join(', ')}"
          end
        end
      end
    end

    # JJM This method is separated from the before_action block to aid testing.
    def group_option_before_action(options)
      options[:group] = options[:group].split(File::PATH_SEPARATOR) unless options[:group].is_a? Array
      options = Puppet::CloudPack.merge_default_options(options)

      known = Puppet::CloudPack.create_connection(options).security_groups
      unknown = options[:group].select { |g| known.get(g).nil? }
      unless unknown.empty?
        raise ArgumentError, "Unrecognized security groups: #{unknown.join(', ')}"
      end
    end

    def add_create_options(action)
      add_platform_option(action)
      add_region_option(action)

      action.option '--image=', '-i=' do
        summary 'AMI to use when creating the instance.'
        description <<-EOT
          Pre-configured operating system image used to create machine instance.
          This currently only supports AMI images.
          Example of a Redhat 5.6 32bit image: ami-b241bfdb
        EOT
        required
        before_action do |action, args, options|
          # We add these options because it's required in Fog but optional for Cloud Pack
          # It doesn't feel right to do this here, but I don't know another way yet.
          options = Puppet::CloudPack.merge_default_options(options)
          if Puppet::CloudPack.create_connection(options).images.get(options[:image]).nil?
            raise ArgumentError, "Unrecognized image name: #{options[:image]}"
          end
        end
      end

      action.option '--type=' do
        summary 'Type of instance.'
        description <<-EOT
          Type of instance to be launched. Type specifies characteristics that
          a machine will have such as architecture, memory, processing power, storage
          and IO performance. The type selected will determine the cost of a machine instance.
          Supported types are: 'm1.small','m1.large','m1.xlarge','t1.micro','m2.xlarge',
          'm2.2xlarge','x2.4xlarge','c1.medium','c1.xlarge','cc1.4xlarge'.
        EOT
        required
        before_action do |action, args, options|
          supported_types = ['m1.small','m1.large','m1.xlarge','t1.micro','m2.xlarge','m2.2xlarge','x2.4xlarge','c1.medium','c1.xlarge','cc1.4xlarge']
          unless supported_types.include?(options[:type])
            raise ArgumentError, "Platform must be one of the following: #{supported_types.join(', ')}"
          end
        end
      end

      action.option '--keypair=' do
        summary 'SSH keypair used to access the instance.'
        description <<-EOT
          The key pair that will be used to ssh into your machine instance
          once it has been created. This expects the id of the ssh keypair as
          represented in the aws console.
        EOT
        required
        before_action do |action, args, options|
          # We add this option because it's required in Fog but optional for Cloud Pack
          # It doesn't feel right to do this here, but I don't know another way yet.
          options = Puppet::CloudPack.merge_default_options(options)
          if Puppet::CloudPack.create_connection(options).key_pairs.get(options[:keypair]).nil?
            raise ArgumentError, "Unrecognized keypair name: #{options[:keypair]}"
          end
        end
      end

      action.option '--group=', '-g=', '--security-group=' do
        summary "The instance's security group(s)."
        description <<-EOT
          The security group(s) that the machine will be associated with.
          A security group determines the rules for both inbound as well as
          outbound connections.
          Multiple groups can be specified as a list using ':'.
        EOT
        before_action do |action, args, options|
          Puppet::CloudPack.group_option_before_action(options)
        end
      end
    end

    def add_list_options(action)
      add_platform_option(action)
      add_region_option(action)
    end

    def add_fingerprint_options(action)
      add_platform_option(action)
      add_region_option(action)
    end

    def add_init_options(action)
      add_install_options(action)
      add_classify_options(action)
    end

    def add_terminate_options(action)
      add_region_option(action)
      add_platform_option(action)
      action.option '--force', '-f' do
        summary 'Forces termination of an instance.'
      end
    end

    def add_bootstrap_options(action)
      add_create_options(action)
      add_init_options(action)
    end

    def add_install_options(action)
      action.option '--login=', '-l=', '--username=' do
        summary 'User to login to the instance as.'
        description <<-EOT
          The name of the user to login to the instance as.
          This should be the same user who has been configured
          with your keypair for passwordless access.
          This is usually the root user.
        EOT
        required
      end

      action.option '--keyfile=' do
        summary "SSH private key used to determine user's identify."
        description <<-EOT
          Path to the local private key that can be used to ssh into
          the instance. If the instance was created with
          the create action, this should be the private key
          part of the keypair.
        EOT
        required
        before_action do |action, arguments, options|
          keyfile = File.expand_path(options[:keyfile])
          unless test 'f', keyfile
            raise ArgumentError, "Could not find file '#{keyfile}'"
          end
          unless test 'r', keyfile
            raise ArgumentError, "Could not read from file '#{keyfile}'"
          end
        end
      end

      action.option '--installer-payload=' do
        summary 'The location of the Pupept Enterprise universal gzipped tarball'
        description <<-EOT
          Location of the Puppet enterprise universal tarball to be used
          for the installation. This option is only required if Puppet
          should be installed on the machine using this image.
          This tarball must be zipped.
        EOT
        before_action do |action, arguments, options|
          options[:installer_payload] = File.expand_path(options[:installer_payload])
          unless test 'f', options[:installer_payload]
            raise ArgumentError, "Could not find file '#{options[:installer_payload]}'"
          end
          unless test 'r', options[:installer_payload]
            raise ArgumentError, "Could not read from file '#{options[:installer_payload]}'"
          end
          unless(options[:installer_payload] =~ /(tgz|gz)$/)
            Puppet.warning("Option: intaller-payload expects a .tgz or .gz file")
          end
        end
      end

      action.option '--installer-answers=' do
        summary 'Answers file to be used for PE installation'
        description <<-EOT
          Location of the answers file that should be copied to the machine
          to install Puppet Enterprise.
        EOT
        before_action do |action, arguments, options|
          options[:installer_answers] = File.expand_path(options[:installer_answers])
          unless test 'f', options[:installer_answers]
            raise ArgumentError, "Could not find file '#{options[:installer_answers]}'"
          end
          unless test 'r', options[:installer_answers]
            raise ArgumentError, "Could not read from file '#{options[:installer_answers]}'"
          end
        end
      end

      action.option '--install-script=' do
        summary 'Name of the template to use for installation'
        description <<-EOT
          Name of the template to use for installation. The current
          list of supported templates is: gems, puppet-enterprise
        EOT
      end

      action.option '--puppet-version=' do
        summary 'version of Puppet to install'
        description <<-EOT
          Version of Puppet to be installed. This version is
          passed to the Puppet installer script.
        EOT
        before_action do |action, arguments, options|
          unless options[:puppet_version] =~ /^(\d+)\.(\d+)(\.(\d+|x))?$|^(\d)+\.(\d)+\.(\d+)([a-zA-Z][a-zA-Z0-9-]*)|master$/
            raise ArgumentError, "Invaid Puppet version '#{options[:puppet_version]}'"
          end
        end
      end

      action.option '--pe-version=' do
        summary 'version of Puppet Enterprise to install'
        description <<-EOT
          Version of Puppet Enterprise to be passed to the installer script.
          Defaults to 1.1.
        EOT
        before_action do |action, arguments, options|
          unless options[:pe_version] =~ /^(\d+)\.(\d+)(\.(\d+))?$|^(\d)+\.(\d)+\.(\d+)([a-zA-Z][a-zA-Z0-9-]*)$/
            raise ArgumentError, "Invaid Puppet Enterprise version '#{options[:pe_version]}'"
          end
        end
      end

      action.option '--facter-version=' do
        summary 'version of facter to install'
        description <<-EOT
          The version of facter that should be installed.
          This only makes sense in open source installation
          mode.
        EOT
        before_action do |action, arguments, options|
          unless options[:facter_version] =~ /\d+\.\d+\.\d+/
            raise ArgumentError, "Invaid Facter version '#{options[:facter_version]}'"
          end
        end
      end
    end

    def add_classify_options(action)
      action.option '--node-group=', '--as=' do
        summary 'The Puppet Dashboard node group to add to.'
      end
    end

    def bootstrap(options)
      server = self.create(options)
      self.init(server, options)
      return nil
    end

    def classify(certname, options)
      if options[:node_group]
        dashboard_classify(certname, options)
      else
        Puppet.info('No classification method selected')
      end
    end

    def dashboard_classify(certname, options)
      Puppet.info "Using http://#{Puppet[:report_server]}:#{Puppet[:report_port]} as Dashboard."
      http = Puppet::Network::HttpPool.http_instance(Puppet[:report_server], Puppet[:report_port])

      # Workaround for the fact that Dashboard is typically insecure.
      http.use_ssl = false
      headers = { 'Content-Type' => 'application/json' }

      begin
        Puppet.notice 'Registering node ...'
        data = { 'node' => { 'name' => certname } }
        response = http.post('/nodes.json', data.to_pson, headers)
        if (response.code == '201')
          Puppet.notice 'Registering node ... Done'
        else
          Puppet.warning 'Registering node ... Failed'
          Puppet.warning "Server responded with a #{response.code} status"
        end

        Puppet.notice 'Classifying node ...'
        data = { 'node_name' => certname, 'group_name' => options[:node_group] }
        response = http.post("/memberships.json", data.to_pson, headers)
        if (response.code == '201')
          Puppet.notice 'Classifying node ... Done'
        else
          Puppet.warning 'Classifying node ... Failed'
          Puppet.warning "Server responded with a #{response.code} status"
        end
      rescue Errno::ECONNREFUSED
        Puppet.warning 'Registering node ... Error'
        Puppet.err "Could not connect to host http://#{Puppet[:report_server]}:#{Puppet[:report_port]}"
        Puppet.err "Check your report_server and report_port options"
        exit(1)
      end

      return nil
    end

    def create(options)
      options = merge_default_options(options)
      unless options.has_key? :_destroy_server_at_exit
        options[:_destroy_server_at_exit] = :create
      end

      Puppet.info("Connecting to #{options[:platform]} #{options[:region]} ...")
      connection = create_connection(options)
      Puppet.info("Connecting to #{options[:platform]} #{options[:region]} ... Done")
      Puppet.info("Instance Type: #{options[:type]}")

      # TODO: Validate that the security groups permit SSH access from here.
      # TODO: Can this throw errors?
      server     = create_server(connection.servers,
        :image_id   => options[:image],
        :key_name   => options[:keypair],
        :groups     => options[:group],
        :flavor_id  => options[:type]
      )

      # This is the earliest point we have knowledge of the instance ID
      Puppet.info("Instance identifier: #{server.id}")

      Signal.trap(:EXIT) do
        if options[:_destroy_server_at_exit]
          server.destroy rescue nil
          Puppet.err("Destroyed server #{server.id} because of an abnormal exit")
        end
      end

      create_tags(connection.tags, server)

      Puppet.notice("Launching server #{server.id} ...")
      retries = 0
      begin
        server.wait_for do
          print '#'
          self.ready?
        end
        puts
        Puppet.notice("Server #{server.id} is now launched")
      rescue Fog::Errors::Error
        Puppet.err "Launching server #{server.id} Failed."
        Puppet.err "Could not connect to host"
        Puppet.err "Please check your network connection and try again"
        return nil
      end

      # This is the earliest point we have knowledge of the DNS name
      Puppet.notice("Server #{server.id} public dns name: #{server.dns_name}")

      if options[:_destroy_server_at_exit] == :create
        options.delete(:_destroy_server_at_exit)
      end

      return server.dns_name
    end

    def list(options)
      options = merge_default_options(options)
      connection = create_connection(options)
      servers = connection.servers
      # Convert the Fog object into a simple hash.
      # And return the array to the Faces API for rendering
      hsh = {}
      servers.each do |s|
        hsh[s.id] = {
          "id"         => s.id,
          "state"      => s.state,
          "dns_name"   => s.dns_name,
          "created_at" => s.created_at,
        }
      end
      hsh
    end

    def fingerprint(server, options)
      options = merge_default_options(options)
      connection = create_connection(options)
      servers = connection.servers.all('dns-name' => server)

      # Our hash for output.  We'll collect into this data structure.
      output_hash = {}
      output_array = servers.collect do |myserver|
        # TODO: Find a better way of getting the Fingerprints
        # The current method scrapes the AWS console looking for an ^ec2: pattern
        # This is not robust or ideal.  We make a "best effort" to find the fingerprint
        begin
          # Is there any console output yet?
          if myserver.console_output.body['output'].nil? then
            Puppet.info("Waiting for instance console output to become available ...")
            Fog.wait_for do
              print "#"
              not myserver.console_output.body['output'].nil?
            end or raise Fog::Errors::Error, "Waiting for console output timed out"
            puts "# Console output is ready"
          end
          # FIXME Where is the fingerprint?  Do we output it ever?
          { "#{myserver.id}" => myserver.console_output.body['output'].grep(/^ec2:/) }
        rescue Fog::Errors::Error => e
          Puppet.warning("Waiting for SSH host key fingerprint from #{options[:platform]} ... Failed")
          Puppet.warning "Could not read the host's fingerprints"
          Puppet.warning "Please verify the host's fingerprints through the AWS console output"
        end
      end
      output_array.each { |hsh| output_hash = hsh.merge(output_hash) }
      # Check to see if we got anything back
      if output_hash.collect { |k,v| v }.flatten.empty? then
        Puppet.warning "We could not securely find a fingerprint because the image did not print the fingerprint to the console."
        Puppet.warning "Please use an AMI that prints the fingerprint to the console in order to connect to the instance more securely."
        Puppet.info "The system is ready.  Please add the host key to your known hosts file."
        Puppet.info "For example: ssh root@#{server} and respond yes."
      end
      output_hash
    end

    def init(server, options)
      certname = install(server, options)
      options.delete(:_destroy_server_at_exit)

      Puppet.notice "Puppet is now installed on: #{server}"

      classify(certname, options)

      # HACK: This should be reconciled with the Certificate Face.
      opts = options.merge(:ca_location => :remote)

      # TODO: Wait for C.S.R.?

      Puppet.notice "Signing certificate ..."
      begin
        Puppet::Face[:certificate, '0.0.1'].sign(certname, opts)
        Puppet.notice "Signing certificate ... Done"
      rescue Puppet::Error => e
        # TODO: Write useful next steps.
        Puppet.err "Signing certificate ... Failed"
        Puppet.err "Signing certificate error: #{e}"
        exit(1)
      rescue Net::HTTPError => e
        # TODO: Write useful next steps
        Puppet.warning "Signing certificate ... Failed"
        Puppet.err "Signing certificate error: #{e}"
        exit(1)
      end
    end

    def install(server, options)

      options = merge_default_options(options)

      options[:certname] ||= Guid.new.to_s
      options[:public_dns_name] = server

      # FIXME We shouldn't try to connect if the answers file hasn't been provided
      # for the installer script matching puppet-enterprise-* (e.g. puppet-enterprise-s3)
      connections = ssh_connect(server, options[:login], options[:keyfile])

      options[:tmp_dir] = File.join('/', 'tmp', Guid.new.to_s)
      create_tmpdir_cmd = "mkdir #{options[:tmp_dir]}"
      ssh_remote_execute(server, options[:login], create_tmpdir_cmd, options[:keyfile])

      upload_payloads(connections[:scp], options)

      tmp_script_path = compile_template(options)

      remote_script_path = File.join(options[:tmp_dir], "#{options[:install_script]}.sh")
      connections[:scp].upload(tmp_script_path, remote_script_path)

      # Finally, execute the installer script
      install_command = "bash -c 'chmod u+x #{remote_script_path}; #{remote_script_path}'"
      install_command = options[:login] == 'root' ? install_command : 'sudo ' + install_command
      ssh_remote_execute(server, options[:login], install_command, options[:keyfile])

      options[:certname]
    end

    # This is the single place to make SSH calls.  It will handle collecting STDOUT
    # in a line oriented manner, printing it to debug log destination and checking the
    # exit code of the remote call.  This should also make it much easier to do unit testing on
    # all of the other methods that need this functionality.  Finally, it should provide
    # one place to swap out the back end SSH implementation if need be.
    def ssh_remote_execute(server, login, command, keyfile = nil)
      Puppet.info "Executing remote command ..."
      Puppet.debug "Command: #{command}"
      buffer = String.new
      exit_code = nil
      Net::SSH.start(server, login, :keys => [ keyfile ]) do |session|
        session.open_channel do |channel|
          channel.on_data do |ch, data|
            buffer << data
            if buffer =~ /\n/
              lines = buffer.split("\n")
              buffer = lines.length > 1 ? lines.pop : String.new
              lines.each do |line|
                Puppet.debug(line)
              end
            end
          end
          channel.on_eof do |ch|
            # Display anything remaining in the buffer
            unless buffer.empty?
              Puppet.debug(buffer)
            end
          end
          channel.on_request("exit-status") do |ch, data|
            exit_code = data.read_long
            Puppet.debug("SSH Command Exit Code: #{exit_code}")
          end
          # Finally execute the command
          channel.exec(command)
        end
      end
      Puppet.info "Executing remote command ... Done"
      exit_code
    end

    def ssh_test_connect(server, login, keyfile = nil)
      Puppet.notice "Waiting for SSH response ..."
      # TODO I'd really like this all to be based on wall time and not retry counts.
      # We should only really block for 3 minutes or so.
      retries = 0
      begin
        status = Timeout::timeout(10) do
          ssh_remote_execute(server, login, "date", keyfile)
        end
      rescue Net::SSH::AuthenticationFailed, Errno::ECONNREFUSED => e
        if (retries += 1) > 10
          Puppet.err "Could not connect via SSH.  The error is: #{e}"
          Puppet.err "Please check to make sure your ssh key is working properly, e.g. ssh #{login}@#{server}"
          raise Puppet::Error, "Check your authentication credentials and try again."
        else
          Puppet.info "Failed to connect with issue #{e} (Retry #{retries})"
          Puppet.info "This may be because the machine is booting.  Retrying the connection..."
          sleep 5
        end
        retry
      rescue Errno::ETIMEDOUT => e
        if (retries += 1) > 3
          Puppet.err "Could not connect via SSH.  The error is: #{e}"
          Puppet.err "This indicates the machine has not even come online yet.  Please check if the system launched."
          raise Puppet::Error, "Too many timeouts trying to connect."
        else
          Puppet.info "Failed to connect with issue #{e} (Retry #{retries})"
          Puppet.info "This may be because the machine is booting.  Retrying the connection..."
        end
      rescue Timeout::Error => e
        if (retries += 1) > 5
          Puppet.err "Could not connect via SSH.  The error is: #{e}"
          raise Puppet::Error, "Too many timeouts trying to connect."
        else
          Puppet.info "Connection test timed-out: (Retry #{retries})"
          Puppet.info "This may be because the machine is booting.  Retrying the connection..."
          retry
        end
      rescue Exception => e
        Puppet.err("Unhandled connection robustness error: #{e.class} [#{e.inspect}]")
        raise e
      end
      Puppet.notice "Waiting for SSH response ... Done"
      true
    end

    def ssh_connect(server, login, keyfile = nil)
      opts = {}
      opts[:key_data] = [File.read(File.expand_path(keyfile))] if keyfile

      ssh_test_connect(server, login, keyfile)

      ssh = Fog::SSH.new(server, login, opts)
      scp = Fog::SCP.new(server, login, opts)

      {:ssh => ssh, :scp => scp}
    end

    def upload_payloads(scp, options)
      options = merge_default_options(options)

      if options[:install_script] == 'puppet-enterprise'
        unless options[:installer_payload] and options[:installer_answers]
          raise 'Must specify installer payload and answers file if install script if puppet-enterprise'
        end
      end

      # Puppet enterprise install scripts, even those using S3, need and installer answer file.
      if options[:install_script] =~ /^puppet-enterprise-/
        unless options[:installer_answers]
          raise "Must specify an answers file for install script #{options[:install_script]}"
        end
      end

      if options[:installer_payload]
        Puppet.notice "Uploading Puppet Enterprise tarball ..."
        scp.upload(options[:installer_payload], "#{options[:tmp_dir]}/puppet.tar.gz")
        Puppet.notice "Uploading Puppet Enterprise tarball ... Done"
      end

      if options[:installer_answers]
        Puppet.info "Uploading Puppet Answer File ..."
        scp.upload(options[:installer_answers], "#{options[:tmp_dir]}/puppet.answers")
        Puppet.info "Uploading Puppet Answer File ... Done"
      end
    end

    def compile_template(options)
      Puppet.notice "Installing Puppet ..."
      options = merge_default_options(options)
      options[:server] = Puppet[:server]
      options[:environment] = Puppet[:environment] || 'production'

      install_script = Puppet::CloudPack::Installer.build_installer_template(options[:install_script], options)
      Puppet.debug("Compiled installation script:")
      Puppet.debug(install_script)

      # create a temp file to write compiled script
      # return the path of the temp location of the script
      begin
        f = Tempfile.open('install_script')
        f.write(install_script)
        f.path
      ensure
        f.close
      end
    end

    def terminate(server, options)
      # JJM This isn't ideal, it would be better to set the default in the
      # option handling block, but I'm not sure how to do this.
      options = merge_default_options(options)

      Puppet.info "Connecting to #{options[:platform]} ..."
      connection = create_connection(options)
      Puppet.info "Connecting to #{options[:platform]} ... Done"

      servers = connection.servers.all('dns-name' => server)
      if servers.length == 1 || options[:force]
        # We're using myserver rather than server to prevent ruby 1.8 from
        # overwriting the server method argument
        servers.each do |myserver|
          Puppet.notice "Destroying #{myserver.id} (#{myserver.dns_name}) ..."
          myserver.destroy()
          Puppet.notice "Destroying #{myserver.id} (#{myserver.dns_name}) ... Done"
        end
      elsif servers.empty?
        Puppet.warning "Could not find server with DNS name '#{server}'"
      else
        Puppet.err "More than one server with DNS name '#{server}'; aborting"
      end

      return nil
    end

    def create_connection(options = {})
      # We don't support more than AWS, but this satisfies the rspec tests
      # that pass in a provider string that does not match 'AWS'.  This makes
      # the test pass by preventing Fog from throwing an error when the region
      # option is not expected
      case options[:platform]
      when 'AWS'
        Fog::Compute.new(:provider => options[:platform], :region => options[:region])
      else
        Fog::Compute.new(:provider => options[:platform])
      end
    end

    def create_server(servers, options = {})
      Puppet.notice('Creating new instance ...')
      server = servers.create(options)
      Puppet.notice("Creating new instance ... Done")
      return server
    end

    def create_tags(tags, server)
      Puppet.notice('Creating tags for instance ...')
      tags.create(
        :key         => 'Created-By',
        :value       => 'Puppet',
        :resource_id => server.id
      )
      Puppet.notice('Creating tags for instance ... Done')
    end
  end
end
