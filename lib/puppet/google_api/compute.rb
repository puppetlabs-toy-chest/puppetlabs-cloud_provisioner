require 'puppet/google_api'

class Puppet::GoogleAPI::Compute
  def initialize(api)
    @api     = api
    @compute = api.discover('compute', 'v1beta15')
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
        text.merge!(type: machine_type, kernel: kernel)
        image and text.merge!(image: image)

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
  end
end
