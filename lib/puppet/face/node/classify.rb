require 'puppet/cloudpack'

Puppet::Face.define :node, '0.0.1' do
  action :classify do
    summary 'Specify how Puppet should classify a node'
    description <<-EOT
      Make The External Node Classifier aware of a newly created agent
      and classify it. This only supports the Dashboard as a
      node classifier and assigns node groups in order to classify.

      Classification of a node will allow it to receive proper
      configurations on its next run

      This action is not restricted to cloud machine instances.
      It can be run multiple times for a single node.
    EOT
    Puppet::CloudPack.add_classify_options(self)
    when_invoked do |certname, options|
      Puppet::CloudPack.classify(certname, options)
    end
  end
end
