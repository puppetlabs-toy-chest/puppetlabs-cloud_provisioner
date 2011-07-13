require 'puppet/cloudpack'

Puppet::Face.define :node, '0.0.1' do
  action :terminate do
    summary 'Terminates the machine instance'
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
