require 'puppet/cloudpack'

Puppet::Face.define :node_aws, '0.0.1' do
  action :terminate do
    summary 'Terminate an EC2 machine instance'
    description <<-EOT
      Terminates an instance.
      Accepts the instance name to terminate
      as the only argument.
    EOT
    Puppet::CloudPack.add_terminate_options(self)
    when_invoked do |server, options|
      Puppet::CloudPack.terminate(server, options)
    end
  end
end
