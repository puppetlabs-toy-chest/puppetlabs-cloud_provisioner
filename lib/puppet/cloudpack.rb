require 'tempfile'
require 'rubygems'
require 'guid'
require 'fog'
require 'net/ssh'
require 'puppet/network/http_pool'
require 'puppet/cloudpack/progressbar'
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

      action.option '--keyname=' do
        summary 'The AWS SSH key name as shown in the AWS console.  Please see the related list_keynames action.'
        description <<-EOT
          This options expects the name of the SSH key pair as listed in the
          Amazon AWS console.  Cloud Provisioner will use this information to tell Amazon
          to install the public SSH key into the authorized_keys file of the new EC2
          instance.  This is a related, but distinct, option from the --keyfile option of
          the install action.  To obtain a listing of valid keynames please see the
          list_keynames action.
        EOT
        required
        before_action do |action, args, options|
          # We add this option because it's required in Fog but optional for Cloud Pack
          # It doesn't feel right to do this here, but I don't know another way yet.
          options = Puppet::CloudPack.merge_default_options(options)
          if Puppet::CloudPack.create_connection(options).key_pairs.get(options[:keyname]).nil?
            raise ArgumentError, "Unrecognized key name: #{options[:keyname]} (Suggestion: use the puppet node_aws list_keynames action to find a list of valid key names for your account.)"
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

    def add_list_keynames_options(action)
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
          with your key pair for passwordless access.
          This is usually the root user.
        EOT
        required
      end

      action.option '--keyfile=' do
        summary "The path to the local SSH private key or 'agent' if the private key is loaded in an agent"
        description <<-EOT
          This option expects the filesystem path to the local private key that
          can be used to ssh into the instance. If the instance was created with the
          create action, this should be the path to the private key file downloaded
          from the Amazon AWS EC2.

          Specify 'agent' if you have the key loaded in your agent and available via
          the SSH_AUTH_SOCK variable.
        EOT
        required
        before_action do |action, arguments, options|
          # If the user specified --keyfile=agent, check for SSH_AUTH_SOCK
          if options[:keyfile].downcase == 'agent' then
            # Force the option value to lower case to make it easier to test
            # for 'agent' in all other sections of the code.
            options[:keyfile].downcase!
            # Check if the user actually has access to an Agent.
            if ! ENV['SSH_AUTH_SOCK'] then
              raise ArgumentError,
                "SSH_AUTH_SOCK environment variable is not set and you specified --agent keyfile.  Please check that ssh-agent is running correctly, or perhaps SSH agent forwarding is disabled."
            end
            # We break out of the before action block because we don't really
            # have anything else to do to support ssh agent authentication.
            break
          end

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
        summary 'The location of the Puppet Enterprise universal gzipped tarball'
        description <<-EOT
          Location of the Puppet enterprise universal tarball to be used
          for the installation. This option is only required if Puppet
          should be installed on the machine using this image.
          This tarball must be zipped.
        EOT
        before_action do |action, arguments, options|
          type = Puppet::CloudPack.payload_type(options[:installer_payload])
          case type
          when :invalid
            raise ArgumentError, "Invalid input '#{options[:installer_payload]}' for option installer-payload, should be a URL or a file path"
          when :file_path
            options[:installer_payload] = File.expand_path(options[:installer_payload])
            unless test 'f', options[:installer_payload]
              raise ArgumentError, "Could not find file '#{options[:installer_payload]}'"
            end
            unless test 'r', options[:installer_payload]
              raise ArgumentError, "Could not read from file '#{options[:installer_payload]}'"
            end
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

      action.option '--puppetagent-certname=' do
        summary 'The Puppet Agent certificate name to configure on the target system'
        description <<-EOT
          This option allows you to specify an optional Puppet Agent
          certificate name to configure on the target system.  This option
          applies to the puppet-enterprise and puppet-enterprise-http
          installation scripts.  If provided, this option will replace any
          puppet agent certificate name provided in the puppet enterprise
          answers file.  This certificate name will show up in the Puppet Dashboard
          when the agent checks in for the first time.
        EOT
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
      action.option '--enc-server=' do
        summary 'The External Node Classifier URL.'
        description <<-EOT
          The URL of the External Node Classifier.
          This currently only supports the Dashboard
          as an external node classifier.
        EOT
        default_to do
          Puppet[:server]
        end
      end

      action.option '--enc-port=' do
        summary 'The External Node Classifier Port'
        description <<-EOT
          The port of the External Node Classifier.
          This currently only supports the Dashboard
          as an external node classifier.
        EOT
        default_to do
          3000
        end
      end

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
        Puppet.notice('No classification method selected')
      end
    end

    def dashboard_classify(certname, options)
      Puppet.info "Using http://#{options[:enc_server]}:#{options[:enc_port]} as Dashboard."
      http = Puppet::Network::HttpPool.http_instance(options[:enc_server], options[:enc_port])

      # Workaround for the fact that Dashboard is typically insecure.
      http.use_ssl = false
      headers = { 'Content-Type' => 'application/json' }

      begin
        Puppet.notice "Registering node: #{certname} ..."
        # get the list of nodes that have been specified in the Dashboard
        response = http.get('/nodes.json', headers )
        nodes = handle_json_response(response, 'List nodes')
        node = nodes.detect { |node| node['name'] == certname }
        node_info = if node
          Puppet.notice("Node: #{certname} already exists in Dashboard, not creating")
          node
        else
          # create the node if it does not exist
          data = { 'node' => { 'name' => certname } }
          response = http.post('/nodes.json', data.to_pson, headers)
          handle_json_response(response, 'Registering node', '201')
        end
        node_id = node_info['id']

        # checking if the specified group even exists
        response = http.get('/node_groups.json', headers )
        node_groups = handle_json_response(response, 'List groups')

        node_group_info = node_groups.detect {|group| group['name'] == options[:node_group] }
        unless node_group_info
          raise Puppet::Error, "Group #{options[:node_group]} does not exist in Dashboard. Groups must exist before they can be assigned to nodes."
        end
        node_group_id = node_group_info['id']

        Puppet.notice 'Classifying node ...'
        response = http.get("/memberships.json", headers)
        memberships = handle_json_response(response, 'List memberships')
        if memberships.detect{ |members| members['node_group_id'] == node_group_id and members['node_id'] == node_id }
          Puppet.warning("Group #{options[:node_group]} already added to node #{options[:node_name]}, nothing to do")
        else
          # add the node group to the node if the relationship did not already exist
          data = { 'node_name' => certname, 'group_name' => options[:node_group] }
          response = http.post("/memberships.json", data.to_pson, headers)
          handle_json_response(response, 'Classify node', '201')
        end
      rescue Errno::ECONNREFUSED
        Puppet.warning 'Registering node ... Error'
        Puppet.err "Could not connect to host http://#{options[:enc_server]}:#{options[:enc_port]}"
        Puppet.err "Check your --enc_server and --enc_port options"
        exit(1)
      end

      return nil
    end

    def handle_json_response(response, action, expected_code='200')
      if response.code == expected_code
        Puppet.notice "#{action} ... Done"
        PSON.parse response.body
      else
        # I should probably raise an exception!
        Puppet.warning "#{action} ... Failed"
        Puppet.info("Body: #{response.body}")
        Puppet.warning "Server responded with a #{response.code} status"
        raise Puppet::Error, "Could not: #{action}, got #{response.code} expected #{expected_code}"
      end
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
        :key_name   => options[:keyname],
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

    def list_keynames(options = {})
      options = merge_default_options(options)
      connection = create_connection(options)
      keys_array = connection.key_pairs.collect do |key|
        key.attributes.inject({}) { |memo,(k,v)| memo[k.to_s] = v; memo }
      end
      # Covert the array into a Hash
      keys_hash = Hash.new
      keys_array.each { |key| keys_hash.merge!({key['name'] => key['fingerprint']}) }
      # Get a sorted list of the names
      sorted_names = keys_hash.keys.sort
      sorted_names.collect do |name|
        { 'name' => name, 'fingerprint' => keys_hash[name] }
      end
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
      install_status = install(server, options)
      certname = install_status['puppetagent_certname']
      options.delete(:_destroy_server_at_exit)

      Puppet.notice "Puppet is now installed on: #{server}"

      classify(certname, options)

      # HACK: This should be reconciled with the Certificate Face.
      cert_options = {:ca_location => :remote}

      # TODO: Wait for C.S.R.?

      Puppet.notice "Signing certificate ..."
      begin
        Puppet::Face[:certificate, '0.0.1'].sign(certname, cert_options)
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

      # If the end user wants to use their agent, we need to set keyfile to nil
      if options[:keyfile] == 'agent' then
        options[:keyfile] = nil
      end

      # Figure out if we need to be root
      cmd_prefix = options[:login] == 'root' ? '' : 'sudo '

      # FIXME: This appears to be an AWS assumption.  What about VMware with a plain IP?
      # (Not necessarily a bug, just a yak to shave...)
      options[:public_dns_name] = server

      # FIXME We shouldn't try to connect if the answers file hasn't been provided
      # for the installer script matching puppet-enterprise-* (e.g. puppet-enterprise-s3)
      connections = ssh_connect(server, options[:login], options[:keyfile])

      options[:tmp_dir] = File.join('/', 'tmp', Guid.new.to_s)
      create_tmpdir_cmd = "bash -c 'umask 077; mkdir #{options[:tmp_dir]}'"
      ssh_remote_execute(server, options[:login], create_tmpdir_cmd, options[:keyfile])

      upload_payloads(connections[:scp], options)

      tmp_script_path = compile_template(options)

      remote_script_path = File.join(options[:tmp_dir], "#{options[:install_script]}.sh")
      connections[:scp].upload(tmp_script_path, remote_script_path)

      # Finally, execute the installer script
      install_command = "#{cmd_prefix}bash -c 'chmod u+x #{remote_script_path}; #{remote_script_path}'"
      results = ssh_remote_execute(server, options[:login], install_command, options[:keyfile])
      if results[:exit_code] != 0 then
        raise Puppet::Error, "The installation script exited with a non-zero exit status, indicating a failure.  It may help to run with --debug to see the script execution or to check the installation log file on the remote system in #{options[:tmp_dir]}."
      end

      # At this point we may assume installation of Puppet succeeded since the
      # install script returned with a zero exit code.

      # Determine the certificate name as reported by the remote system.
      certname_command = "#{cmd_prefix}puppet agent --configprint certname"
      results = ssh_remote_execute(server, options[:login], certname_command, options[:keyfile])

      if results[:exit_code] == 0 then
        puppetagent_certname = results[:stdout].strip
      else
        Puppet.warn "Could not determine the remote puppet agent certificate name using #{certname_command}"
        puppetagent_certname = nil
      end

      # Return value
      {
        'status'               => 'success',
        'puppetagent_certname' => puppetagent_certname,
      }
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
      stdout = String.new
      exit_code = nil
      # Figure out the options we need to pass to start.  This allows us to use SSH_AUTH_SOCK
      # if the end user specifies --keyfile=agent
      ssh_opts = keyfile ? { :keys => [ keyfile ] } : { }
      # Start
      begin
        Net::SSH.start(server, login, ssh_opts) do |session|
          session.open_channel do |channel|
            channel.on_data do |ch, data|
              buffer << data
              stdout << data
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
      rescue Net::SSH::AuthenticationFailed => user
        raise Puppet::Error, "Authentication failure for user #{user}. Please check the keyfile and try again."
      end

      Puppet.info "Executing remote command ... Done"
      { :exit_code => exit_code, :stdout => stdout }
    end

    def ssh_test_connect(server, login, keyfile = nil)
      Puppet.notice "Waiting for SSH response ..."

      retry_exceptions = {
          Net::SSH::AuthenticationFailed => "Failed to connect. This may be because the machine is booting.\nRetrying the connection...",
          Errno::ECONNREFUSED            => " Failed to connect.\nThis may be because the machine is booting.  Retrying the connection...",
          Errno::ETIMEDOUT               => "Failed to connect.\nThis may be because the machine is booting.  Retrying the connection..",
          Errno::ECONNRESET              => "Connection reset.\nRetrying the connection...",
          Timeout::Error                 => "Connection test timed-out.\nThis may be because the machine is booting.  Retrying the connection..."
      }

      Puppet::CloudPack::Utils.retry_action( :timeout => 250, :retry_exceptions => retry_exceptions ) do 
        Timeout::timeout(250) do
          ssh_remote_execute(server, login, "date", keyfile)
        end
      end

      Puppet.notice "Waiting for SSH response ... Done"
      true
    end

    def ssh_connect(server, login, keyfile = nil)
      opts = {}
      # This allows SSH_AUTH_SOCK agent usage if keyfile is nil
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

      if options[:installer_payload] and payload_type(options[:installer_payload]) == :file_path
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

    def payload_type(payload)
      uri = begin
        URI.parse(payload)
      rescue URI::InvalidURIError => e
        return :invalid
      end
      if uri.class.to_s =~ /URI::(FTP|HTTPS?)/
        $1.downcase.to_sym
      else
        # assuming that everything else is a valid filepath
        :file_path
      end
    end
  end
end
