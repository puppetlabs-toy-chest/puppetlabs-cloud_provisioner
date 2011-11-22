require 'puppet/cloudpack'

Puppet::Face.define :node, '0.0.1' do
  action :classify do
    summary 'Add a node to a dashboard group'
    description <<-EOT
      Add node <certname> to a dashboard group.  Make The External Node
      Classifier aware of a newly created agent and classify it. This only
      supports the Dashboard as a node classifier and assigns the node to a
      group.  The group itself is expected to have classes the node should
      receive in its configuration catalog

      Classification of a node will allow it to receive proper configurations
      on its next run

      This action is not restricted to cloud machine instances.  It can be run
      multiple times for a single node.

      This action may also be carried out before the install action.
    EOT
    examples <<-'EOEXAMPLE'
      Add the agent01.example.com node to the pe_agents group:

          puppet node classify \
            --enc-server puppetmaster.example.com \
            --enc-port 3000 \
            --enc-ssl \
            --node-group pe_agents \
            agent01.example.com
    EOEXAMPLE

    arguments '<certname>'

    when_rendering :console do |return_value|
      return_value['status'] || 'OK'
    end

    Puppet::CloudPack.add_classify_options(self)
    when_invoked do |certname, options|
      Puppet::CloudPack.classify(certname, options)
    end
  end
end
