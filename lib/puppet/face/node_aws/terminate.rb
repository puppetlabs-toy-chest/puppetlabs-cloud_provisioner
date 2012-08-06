require 'puppet/cloudpack'
require 'puppet/face/node_aws'

Puppet::Face.define :node_aws, '0.0.1' do
  action :terminate do
    summary 'Terminate an EC2 machine instance.'
    description <<-EOT
      Terminate the instance identified by its <terminate-id>.
      The terminate-id flag is used to determine which EC2 identifier is
      used for terminating instances.
    EOT

    option '--terminate-id ID' do
      summary 'field used to identify node to terminate'
      description <<-EOT
        Field used to identify the node to terminate. Can be set to
        dns-name or instance-id.
      EOT
      default_to { 'dns-name' }

      before_action do |action, args, options|
        unless ['dns-name', 'instance-id' ].include?(options[:terminate_id])
          raise(Puppet::Error, "Invalid terminate-id #{options[:terminate_id]}. Valid values are dns-name, instance-id")
        end
      end

    end

    arguments '<instance_name>'

    Puppet::CloudPack.add_terminate_options(self)
    when_invoked do |server, options|
      Puppet::CloudPack.terminate(server, options)
    end
  end
end
