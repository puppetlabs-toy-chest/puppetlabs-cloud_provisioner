require 'puppet/cloudpack'

Puppet::Face.define :node, '0.0.1' do
  action :classify do
    summary 'Specify how Puppet should classify a node'
    description <<-EOT
      Make Puppet Dashboard aware of a newly created agent
      node and add it to a node group, thus allowing it to
      receive proper configurations on its next run. This
      action will have no material effect unless you’re using
      Puppet dashboard for node classification.

      This action is not restricted to cloud machine instances.
      It can be run multiple times for a single node.
    EOT
    Puppet::CloudPack.add_classify_options(self)
    when_invoked do |certname, options|
      Puppet::CloudPack.classify(certname, options)
    end
  end
end
