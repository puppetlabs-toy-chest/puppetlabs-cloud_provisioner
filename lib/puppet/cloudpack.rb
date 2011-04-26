require 'rubygems'
require 'fog'
require 'puppet/network/http_pool'

module Puppet::CloudPack
  class << self
    def add_create_options(action)
      # TODO: Should mark certain options as required.
      # TODO: Validate parameters.
      action.option '--image=', '-i='
      action.option '--keypair='
      action.option '--group=', '-g=', '--security-group='
    end

    def add_init_options(action)
      add_install_options(action)
      add_classify_options(action)
    end

    def add_terminate_options(action)
      action.option '--force', '-f'
    end

    def add_bootstrap_options(action)
      add_create_options(action)
      add_init_options(action)
    end

    def add_install_options(action)
      action.option '--login=', '-l=', '--username='
      action.option '--keyfile='
      action.option '--installer-payload='
      action.option '--installer-answers='
    end

    def add_classify_options(action)
      action.option '--node-group=', '--as=' do
        required
      end
    end



    def bootstrap(options)
      options[:_destroy_server_at_exit] = :bootstrap
      server = self.create(options)
      self.init(server, options)
      options.delete(:_destroy_server_at_exit)
      return nil
    end

    def classify(certname, options)
      puts "Using http://#{Puppet[:report_server]}:#{Puppet[:report_port]} as Dashboard."
      http = Puppet::Network::HttpPool.http_instance(Puppet[:report_server], Puppet[:report_port])

      # Workaround for the fact that Dashboard is typically insecure.
      http.use_ssl = false
      headers = { 'Content-Type' => 'application/json' }

      begin
        print 'Registering node ...'
        data = { 'node' => { 'name' => certname } }
        response = http.post('/nodes.json', data.to_pson, headers)
        if (response.code == '201')
          puts ' Done'
        else
          puts ' Failed'
          Puppet.warning "Server responded with a #{response.code} status"
        end

        print 'Classifying node ...'
        data = { 'node_name' => certname, 'group_name' => options[:node_group] }
        response = http.post("/memberships.json", data.to_pson, headers)
        if (response.code == '201')
          puts ' Done'
        else
          puts ' Failed'
          Puppet.warning "Server responded with a #{response.code} status"
        end
      rescue Errno::ECONNREFUSED
        puts ' Error'
        Puppet.err "Could not connect to host http://#{Puppet[:report_server]}:#{Puppet[:report_port]}"
        Puppet.err "Check your report_server and report_port options"
        exit(1)
      end

      return nil
    end

    def create(options)
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

    def init(server, options)
      certname = install(server, options)
      options.delete(:_destroy_server_at_exit)

      puts "Puppet Enterprise is now installed on: #{server}"

      classify(certname, options)

      # HACK: This should be reconciled with the Certificate Face.
      opts = options.merge(:ca_location => :remote)

      # TODO: Wait for C.S.R.?

      print "Signing certificate ..."
      begin
        Puppet::Face[:certificate, '0.0.1'].sign(certname, opts)
        puts " Done"
      rescue Puppet::Error => e
        # TODO: Write useful next steps.
        puts " Failed"
      rescue Net::HTTPError => e
        # TODO: Write useful next steps
        puts " Failed"
      end
    end

    def install(server, options)
      login    = options[:login]
      keyfile  = options[:keyfile]

      if not test('f', '/usr/bin/uuidgen')
        raise "/usr/bin/uuidgen does not exist; please install uuidgen."
      elsif not test('x', '/usr/bin/uuidgen')
        raise "/usr/bin/uuidgen is not executable; please change that file's permissions."
      end
      certname = `/usr/bin/uuidgen`.downcase.chomp

      opts = {}
      opts[:key_data] = [File.read(keyfile)] if keyfile

      ssh = Fog::SSH.new(server, login, opts)
      scp = Fog::SCP.new(server, login, opts)

      print "Waiting for SSH response ..."
      retries = 0
      begin
        # TODO: Certain cases cause this to hang?
        ssh.run(['hostname'])
      rescue Net::SSH::AuthenticationFailed
        puts " Failed"
        raise "Check your authentication credentials and try again."
      rescue => e
        sleep 5
        retries += 1
        print '.'
        puts " Failed"
        raise "SSH not responding; aborting." if retries > 60
        retry
      end
      puts " Done"

      print "Uploading Puppet ..."
      scp.upload(options[:installer_payload], '/tmp/puppet.tar.gz')
      puts " Done"

      print "Uploading Puppet Answer File ..."
      scp.upload(options[:installer_answers], '/tmp/puppet.answers')
      puts " Done"

      print "Installing Puppet ..."
      steps = [
        'tar -xvzf /tmp/puppet.tar.gz -C /tmp',
        %Q[echo "q_puppetagent_certname='#{ certname }'" >> /tmp/puppet.answers],
        '/tmp/puppet-enterprise-1.0-all/puppet-enterprise-installer -a /tmp/puppet.answers &> /tmp/install.log'
      ]
      ssh.run(steps.map { |c| login == 'root' ? cmd : "sudo #{c}" })
      puts " Done"

      return certname
    end

    def terminate(server, options)
      connection = create_connection()

      servers = connection.servers.all('dns-name' => server)
      if servers.length == 1 || options[:force]
        servers.each { |server| server.destroy() }
      elsif servers.empty?
        Puppet.warning "Could not find server with DNS name '#{server}'"
      else
        Puppet.err "More than one server with DNS name '#{server}'; aborting"
      end

      return nil
    end

    private
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
end
