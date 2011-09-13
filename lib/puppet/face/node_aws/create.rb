require 'puppet/cloudpack'

Puppet::Face.define :node_aws, '0.0.1' do
  action :create do
    summary 'Create a new EC2 machine instance.'
    description <<-EOT
      This action launches a new Amazon EC2 instance and returns
      the public DNS name suitable for SSH access.  The system
      may not be immediately ready after launch while it boots.
      Please use the fingerprint action to wait for the system
      to become ready after launch.
      If the process fails, Puppet will automatically clean
      up after itself and tear down the instance.
    EOT
    Puppet::CloudPack.add_create_options(self)
    when_invoked do |options|
      Puppet::CloudPack.create(options)
    end
  end
end
