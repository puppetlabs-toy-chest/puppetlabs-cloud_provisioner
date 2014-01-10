require 'puppet/google_api'

class Puppet::GoogleAPI::Compute
  def initialize(api)
    @api     = api
    @compute = api.discover('compute', 'v1')
  end

  def instances
    @instances ||= Instances.new(@api, @compute)
  end

  class Instances
    def initialize(api, compute)
      @api     = api
      @compute = compute
    end

    def add_instance_to_s_to(instance)
      # Add a custom method to an AutoParse generated set of data that will
      # return something meaningful when turned into a string; this is careful
      # to try and set itself correctly for human consumption.
      #
      # If only the upstream library did the right thing out of the box, eh?
      def instance.to_s
        text = {
          name:   name,
          status: status.downcase + (status_message ? " #{status_message}" : '')
        }
        description and text.merge!(description: description)
        tags.items.empty? or text.merge!(tags: tags.items.join(', '))

        unless metadata.items.empty?
          content = metadata.items.inject({}) do |hash, item|
            value = if item.value.length > 40 then
                      item.value[0,37] + '...'
                    else
                      item.value
                    end

            hash[item.key] = value
            hash
          end

          text.merge!(metadata: Puppet::GoogleAPI.hash_to_human_s(content))
        end

        # @todo danielp 2013-09-16: these are both URLs pointing to the actual
        # instance; we should fetch the content from them -- with full auth,
        # since that is required to see them -- and display a more
        # human-meaningful response.  (Possibly the object, possibly just the
        # name...)
        text.merge!(type: machine_type)

        # Networking details...
        #
        # @todo danielp 2013-09-16: this doesn't extract any of the available
        # data about those interfaces -- are they public, what is the external
        # IP, etc. at least the later is probably going to be highly desired
        # by some users.  Worst luck, though, the definitions are complex and
        # can support more than one access type per nic...
        text.merge!(router: can_ip_forward)
        unless network_interfaces.empty?
          data = network_interfaces.map do |int|
            [int.name, int.network_ip]
          end

          text.merge!(networks: Puppet::GoogleAPI.hash_to_human_s(Hash[data]))
        end

        unless disks.empty?
          data = disks.sort_by {|disk| disk.index }.map do |disk|
            [
              disk.device_name,
              [
                disk.type.downcase,
                disk.mode.downcase,
                disk.boot ? 'boot' : nil
              ].compact.join(' ')
            ]
          end

          text.merge!(disks: Puppet::GoogleAPI.hash_to_human_s(Hash[data]))
        end

        # Now, turn that map into human-focused output
        Puppet::GoogleAPI.hash_to_human_s(text)
      end
    end

    def get(project, zone, name)
      args = {project: project, zone: zone, instance: name}
      @api.execute(@compute.instances.get, args).first
    rescue
      nil
    end

    def list(project, zone)
      instances = @api.execute(@compute.instances.list, project: project, zone: zone)
      # Turn our collection of pages into a single, flat collection; we don't
      # need any of the additional data in the containers.
      instances = instances.map {|i| i.items }.flatten
      instances.each {|i| add_instance_to_s_to(i) }
      instances
    end

    def aggregated_list(project)
      pages = @api.execute(@compute.instances.aggregated_list, project: project)
      # Our collection is a map, keyed by zone and value being an array of
      # instance records.  We need to flatten this by merging the values if we
      # get duplicate keys (eg: because we have more than one page of machines
      # in a single zone, or because a zone instance list happens to contain a
      # page boundary.)
      instances = Hash.new {|hash, key| hash[key] = [] }
      pages.each do |page|
        # *sigh*  there is *no* other mechanism to get the dynamic list of
        # keys, so we turn it into a hash.  Since we want the class not the
        # hash version of the value, we have to indirect like this.
        page.items.to_hash.keys.each do |zone|
          # Instances will return an empty array if the list is empty, even
          # though the returned data contains only the various warning bits
          # and pieces.
          instances[zone] += page.items[zone].instances
        end
      end

      instances.values.flatten.each {|i| add_instance_to_s_to(i) }

      instances
    end

    def create(project, zone, name, type, options)
      params = {project: project, zone: zone}
      body   = {name: name, metadata: {items: []}}

      if machine_type = @api.compute.machine_types.get(project, zone, type)
        body[:machineType] = machine_type.self_link
      else
        raise "machine type #{type} not found in project #{project} zone #{zone}"
      end

      # GCE v1 API does not support Scratch disks, so here we create
      # a persistent disk and register it for attachement to the instance.
      # Note that we name the disk the same as the instance to be compatible
      # with other tools.
      boot_disk = @api.compute.disks.create(project, zone, name, options)
      body[:disks] = [{
        type: 'PERSISTENT',
        source: boot_disk.targetLink,
        mode: 'READ_WRITE',
        deviceName: name,
        boot: true
      }]

      # @todo danielp 2013-09-17: we don't support network configuration
      # outside this fixed-in-place default.  Good luck.
      body[:networkInterfaces] = [{
          # @todo danielp 2013-09-17: this just assumes the network exists.
          # Eventually we need to fix that to allow some real network config,
          # and also to error-check this fetch.
          network: @api.compute.networks.get(project, 'default').self_link,
          # @todo danielp 2013-09-17: right now, we forcibly expose everything
          # to the outside world.  In the longer term that should change (as
          # best practice is to put *only* your front-end nodes on the
          # Internet), but that requires (a) network configuration input, and
          # (b) solving the problem of how to install Puppet on that node...
          accessConfigs: [
            {type: 'ONE_TO_ONE_NAT', name: 'external nat'}
          ]
      }]

      if options[:login]
        # @todo danielp 2013-09-18: I suspect that if you store your SSH
        # public key in PEM format, bad things follow from this line!
        keydata = Pathname(options[:key]).sub_ext('.pub').read
        value = "#{options[:login]}:#{keydata}"

        # Why didn't the just use a regular JSON object for this?  *sigh*
        body[:metadata][:items] << {key: 'sshKeys', value: value}
      end

      result = @api.execute(@compute.instances.insert, params, body).first
      while options[:wait] and result.status != 'DONE'
        # I wonder if I should show some sort of progress bar...
        sleep 1
        result = @api.compute.zone_operations.get(project, zone, result.name)
      end

      return result
    end

    def delete(project, zone, name, options)
      instance = get(project, zone, name)

      params = {project: project, zone: zone, instance: name}
      result = @api.execute(@compute.instances.delete, params).first
      while options[:wait] and result.status != 'DONE'
        # I wonder if I should show some sort of progress bar...
        sleep 1
        result = @api.compute.zone_operations.get(project, zone, result.name)
      end

      # delete the instance's persistent boot disk (if any)
      instance.disks.each do |disk|
        next unless (disk.type == 'PERSISTENT' && disk.boot)
        @api.compute.disks.delete(project, zone, File.basename(URI.parse(disk.source).path))
      end

      return result
    end

    def set_metadata(project, zone, name, fingerprint, metadata, options)
      params = {project: project, zone: zone, instance: name}
      body = {
        fingerprint: [fingerprint].pack('m'),
        items: metadata.inject([]) do |array, (key, value)|
          array << {key: key, value: value}
        end
      }

      result = @api.execute(@compute.instances.set_metadata, params, body).first
      while options[:wait] and result.status != 'DONE'
        # I wonder if I should show some sort of progress bar...
        sleep 1
        result = @api.compute.zone_operations.get(project, zone, result.name)
      end

      return result
    end
  end


  def machine_types
    @machine_types ||= MachineTypes.new(@api, @compute)
  end

  class MachineTypes
    def initialize(api, compute)
      @api     = api
      @compute = compute
    end

    def get(project, zone, name)
      @api.execute(@compute.machine_types.get, project: project, zone: zone, machineType: name).first
    rescue
      nil
    end
  end

  def images
    @images ||= Images.new(@api, @compute)
  end

  class Images
    def initialize(api, compute)
      @api     = api
      @compute = compute
    end

    def get(project, name)
      @api.execute(@compute.images.get, project: project, image: name).first
    rescue
      nil
    end
  end

  def disks
    @disks ||= Disks.new(@api, @compute)
  end

  class Disks
    def initialize(api, compute)
      @api     = api
      @compute = compute
    end

    def create(project, zone, name, options)
      params = {project: project, zone: zone}
      body   = {name: name}

      case options[:image]
      when /^https?:/i
        # The rest of the system will error-check the URL you supplied.
        params[:sourceImage] = options[:image]

      when String
        image = nil
        ([project] + options[:image_search]).each do |where|
          image = @api.compute.images.get(where, options[:image])
          break if image
        end

        image or
          raise "unable to find the image '#{options[:image]}' for #{project}"

        params[:sourceImage] = image.self_link
      else
        raise "the disk image must be either a full HTTP URL, or an image name"
      end

      body[:description] = 'Created from: ' + params[:sourceImage]

      result = @api.execute(@compute.disks.insert, params, body).first
      while result.status != 'DONE'
        # I wonder if I should show some sort of progress bar...
        sleep 1
        result = @api.compute.zone_operations.get(project, zone, result.name)
      end

      result
    end

    def delete(project, zone, name)
      params = {project: project, zone: zone, disk: name}

      result = @api.execute(@compute.disks.delete, params).first
      while result.status != 'DONE'
        # I wonder if I should show some sort of progress bar...
        sleep 1
        result = @api.compute.zone_operations.get(project, zone, result.name)
      end

      result
    end
  end

  def networks
    @networks ||= Networks.new(@api, @compute)
  end

  class Networks
    def initialize(api, compute)
      @api     = api
      @compute = compute
    end

    def get(project, name)
      @api.execute(@compute.networks.get, project: project, network: name).first
    rescue
      nil
    end
  end


  def zone_operations
    @zone_operations ||= ZoneOperations.new(@api, @compute)
  end

  class ZoneOperations
    def initialize(api, compute)
      @api     = api
      @compute = compute
    end

    def get(project, zone, name)
      args = {project: project, zone: zone, operation: name}
      @api.execute(@compute.zone_operations.get, args).first
    rescue
      nil
    end
  end
end
