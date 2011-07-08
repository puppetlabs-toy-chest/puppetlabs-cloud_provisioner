require 'puppet/cloudpack'

Puppet::Face.define :cloudnode, '0.0.1' do
  action :create do
    summary 'Create a new EC2 machine instance.'
    description <<-EOT
      Creates a new EC2 machine instance, prints its
      SSH host key fingerprints, and returns its DNS name.
      If the process fails, Puppet will automatically clean
      up after itself and tear down the instance.
    EOT
    Puppet::CloudPack.add_create_options(self)
    when_invoked do |options|
      Puppet::CloudPack.create(options)
    end
  end
end
