require 'puppet/face'
require 'pathname'

Puppet::Face.define(:node_gce, '1.0.0') do
  copyright "Puppet Labs", 2013
  license   "Apache 2 license; see COPYING"

  summary "View and manage Google Compute nodes."
  description <<-'EOT'
    This subcommand provides a command line interface to manage Google Compute
    machine instances.  We support creation of instances, shutdown of instances
    and basic queries for Google Compute instances.
  EOT


  action :register do
    summary 'Register your Cloud Provisioner GCE client with Google Cloud'
    description <<-EOT
      Register your Cloud Provisioner GCE client with Google Cloud.

      In order for the GCE client to operate, it needs to establish a secure
      trust relationship with the Google Cloud API, and the project you are
      working with.

      This action captures the registration process, and stores the secret
      data required to authenticate you.  It will open a page in your web
      browser to access the requisite authentication data.
    EOT

    arguments 'CLIENT_ID CLIENT_SECRET'

    when_invoked do |client_id, client_secret, options|
      require 'puppet/google_api'

      Puppet::GoogleAPI.new(client_id, client_secret).discover('compute', 'v1beta15') or
        raise "unable to discover the GCE v1beta15 API"

      true
    end

    when_rendering :console do |result|
      if result
        'Registration was successful, and the GCE API is available'
      else
        'Registration failed, or the GCE API was not available'
      end
    end
  end


  action :list do
    summary 'List GCE compute instances'
    description <<-EOT
      List GCE compute instances.

      This provides a list of GCE compute instances for the selected project.
    EOT

    option '--project SCP-1125' do
      summary 'The project to list instances from'
      required
    end

    option '--zone us-central1-a' do
      summary 'Limit to instances in the specified zone'
    end

    when_invoked do |options|
      require 'puppet/google_api'
      api = Puppet::GoogleAPI.new

      if options[:zone]
        api.compute.instances.list(options[:project], options[:zone])
      else
        api.compute.instances.aggregated_list(options[:project])
      end
    end

    when_rendering :console do |output|
      if output.is_a? Hash
        output.map do |key, value|
          if value.empty?
            "#### zone: #{key}\n<no instances in zone>\n"
          else
            "#### zone: #{key}\n" + value.map(&:to_s).join("\n\n") + "\n"
          end
        end.join("\n")
      else
        output.join("\n\n")
      end
    end
  end


  action :create do
    summary 'create a new GCE compute instance'
    description <<-EOT
      Create a new GCE computer instance.

      This starts the process of creating a new instance, which happens
      in the background, and optionally waits for completion.
    EOT

    arguments '<name> <type>'

    option '--project SCP-1125' do
      summary 'The project to list instances from'
      required
    end

    option '--zone us-central1-a' do
      summary 'Limit to instances in the specified zone'
      default_to { 'us-central1-a' }
    end

    option '--image <name|url>' do
      summary 'the disk image name, or full URL, to boot from'
      required
    end

    option '--image-search <projects>' do
      summary 'the additional projects to search for images by name'
      description <<-EOT
        The additional projects to search for images by name.

        Google Compute supplies a number of default images, but they live
        in their own little world -- distinct projects.  This allows you to
        set the search path for images specified by name.

        It should be a colon separated list of projects.
      EOT

      default_to do
        require 'puppet/google_api'
        Puppet::GoogleAPI::StandardImageProjects.join(':')
      end

      before_action do |action, args, options|
        # Fun times, but for consistency to the user...
        options[:image_search] = options[:image_search].split(':')
      end
    end

    option '--login <username>', '-l <username>', '--username <username>' do
      summary 'The login user to create on the target system.'
      description <<-EOT
        The login user to create on the target system.  This, along with the
        SSH public key, is added to the instance metadata -- which in turn will
        cause the Google supplied scripts to create the appropriate account
        on the instance.
      EOT
    end

    option '--key <keyname | path>' do
      summary 'The SSH keypair name or file to install on the created user account.'
      description <<-EOT
        The SSH keypair name or file to install on the created user account.

        The normal value is a keypair name -- relative to ~/.ssh -- that is used
        to locate the private and public keys.  On the target system, only the
        public key is stored.  The private key never leaves your machine.
      EOT

      default_to { 'id_rsa' }

      before_action do |action, args, options|
        # First, make sure the pathname is absolute; this turns relative names
        # into names relative to the .ssh directory, but preserves an
        # absolute path.
        key = Pathname(options[:key]).expand_path('~/.ssh')

        # Figure out if we got pointed to the public key; we keep this option
        # pointing at the private key by convention.
        if key.read =~ /PUBLIC KEY|^ssh-/ and key.extname.downcase == '.pub'
          key = key.sub_ext('')
        end

        # Now, verify that we are pointed to a private key file.
        unless key.read =~ /PRIVATE KEY/
          raise <<EOT
SSH keypair #{options[:key]} does not have private and public key data where I
expect it to be, and I can't figure out how to locate the right parts.

We assume that the private key material is in `.../example-key`, and that the
public key material is in a corresponding `.../example-key.pub` file.

If the option is relative, we assume the base directory is `~/.ssh`.

Please point the key option at the private key file, and put the public key in
place next to it with an additional `.pub` extension.
EOT
        end

        # Finally, update the option to reflect our changes.
        options[:key] = key.to_s
      end
    end

    option '--[no-]wait' do
      summary 'wait for instance creation to complete before returning'
      default_to { true }
    end

    # @todo danielp 2013-09-16: we should support network configuration, but
    # for now ... we don't.  Sorry.  Best of luck.

    when_invoked do |name, type, options|
      require 'puppet/google_api'
      api = Puppet::GoogleAPI.new

      api.compute.instances.create(options[:project], options[:zone], name, type, options)
    end

    when_rendering :console do |result|
      if result.error
        # @todo danielp 2013-09-17: untested
        result.error.errors.each do |msg|
          Puppet.err(msg.message || msg.code)
        end

        "Creating the VM failed"
      else
        (result.warnings || []).each do |msg|
          Puppet.warning(msg.message || msg.code)
        end

        "Creating the VM is #{result.status.downcase}"
      end
    end
  end


  action :delete do
    summary 'delete an existing GCE compute instance'
    description <<-EOT
      Delete an existing GCE computer instance.

      This starts the process of deleting the instance, which happens
      in the background, and optionally waits for completion.
    EOT

    arguments '<name>'

    option '--project SCP-1125' do
      summary 'The project to list instances from'
      required
    end

    option '--zone us-central1-a' do
      summary 'Limit to instances in the specified zone'
      default_to { 'us-central1-a' }
    end

    option '--[no-]wait' do
      summary 'wait for instance creation to complete before returning'
      default_to { true }
    end

    when_invoked do |name, options|
      require 'puppet/google_api'
      api = Puppet::GoogleAPI.new

      api.compute.instances.delete(options[:project], options[:zone], name, options)
    end

    when_rendering :console do |result|
      if result.error
        # @todo danielp 2013-09-17: untested
        result.error.errors.each do |msg|
          Puppet.err(msg.message || msg.code)
        end
      else
        (result.warnings || []).each do |msg|
          Puppet.warning(msg.message || msg.code)
        end

        "Deleting the VM is #{result.status.downcase}"
      end
    end
  end


  action :user do
    summary 'Manage user login accounts and SSH keys on an instance'
    description <<-EOT
      Manage user login accounts and SSH keys on an instance.

      This operates by modifying the instance `sshKey` metadata value,
      which contains a list of user accounts and SSH key data.  The
      Google supplied images use this to sync active accounts on the
      instances.

      The sync process runs once a minute, so there is a potential for
      some delay between our update and the change being reflected on the
      machine in production.

      Also, notably, this may no longer work on custom images: if you don't
      include the Google sync process, this will "succeed" in the sense that
      the metadata will be changed, but nothing will happen on the target
      instance.
    EOT

    option '--project SCP-1125' do
      summary 'The project to list instances from'
      required
    end

    option '--zone us-central1-a' do
      summary 'Limit to instances in the specified zone'
      default_to { 'us-central1-a' }
    end

    option '--[no-]wait' do
      summary 'wait for instance creation to complete before returning'
      default_to { true }
    end

    arguments '<instance> ( remove <user> | set <user> <key> )'

    when_invoked do |*args|
      require 'puppet/google_api'
      api = Puppet::GoogleAPI.new

      # destructure our arguments nicely; wish this were doable in the method
      # arguments, but sadly ... not so. :/
      options = args.pop
      name, action, user, key, *bad = args
      name or raise "you must give the instance name to modify"
      user or raise "you must tell me which user to act on"
      bad.empty? or raise "unexpected trailing arguments #{bad.join(', ')}"

      # Fetch the existing metadata, by way of fetching the entire instance.
      node = api.compute.instances.get(options[:project], options[:zone], name) or
        raise "unable to find instance #{name} in #{options[:project]} #{options[:zone]}"

      metadata = Hash[node.metadata.items.map {|i| [i.key, i.value]}]
      if ssh = metadata['sshKey']
        ssh = Hash[metadata['sshKey'].split("\n").map {|s| s.split(':') }]
      else
        ssh = {}
      end

      case action
      when 'remove'
        key and raise "unexpected key argument when removing a user"
        ssh.delete(user)

      when 'set'
        key or raise "the key must be supplied when setting a user key"
        ssh[user] = key

      else
        raise "I don't know how to '#{action}' a user, sorry"
      end

      # ...and now set that modified data back.
      metadata['sshKey'] = ssh.map {|k,v| "#{k}:#{v}" }.join("\n")
      api.compute.instances.set_metadata(
        options[:project], options[:zone], name,
        node.metadata.fingerprint, metadata, options)
    end

    when_rendering :console do |result|
      "Updating the ssh key metadata is #{result.status.downcase}"
    end
  end
end
