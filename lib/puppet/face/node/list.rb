require 'puppet/cloudpack'

Puppet::Face.define :node, '0.0.1' do
  action :list do
    summary 'List node instances'
    description <<-'EOT'
      The list action obtains a list of instances from the cloud provider and
      displays them on the console output.  For EC2 instances, only the instances in
      a specific region are provided.
    EOT
    Puppet::CloudPack.add_list_options(self)
    when_invoked do |options|
      Puppet::CloudPack.list(options)
    end
    when_rendering :console do |value|
      value.collect do |id,status_hash|
        "#{id}:\n" + status_hash.collect do |field, val|
          "  #{field}: #{val}"
        end.sort.join("\n")
      end.sort.join("\n")
    end
  end
end

