require 'puppet/face'

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
end
