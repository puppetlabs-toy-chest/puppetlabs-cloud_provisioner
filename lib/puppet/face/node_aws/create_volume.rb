require 'puppet/cloudpack'
require 'puppet/face/node_aws'

Puppet::Face.define :node_aws, '0.0.1' do
  action :create_volume do

    summary 'Create a new EBS volume'

    description <<-'EOT'
      This action creates an EBS volume that is available to instances to mount.
    EOT

    Puppet::CloudPack.add_create_volume_options(self)

    when_invoked do |options|
      Puppet::CloudPack.create_volume(options)
    end

    when_rendering :console do |value|
      value.to_s
    end

    returns "Volume ID of EBS volume created"

    examples <<-'EOT'
       $ puppet node_aws create_volume --size 10 [ --snapshot-id snap-7334e011 ]
       vol-ccc507a1
    EOT

  end
end
