require 'puppet/cloudpack'

Puppet::Face.define :cloudnode, '0.0.1' do
  action :init do
    summary 'Install Puppet on a node and clasify it'
    description <<-EOT
      Install Puppet Enterprise on an arbitrary system
      (see “install”), classify it in Dashboard (see
       “classify”), and automatically sign its certificate
      request (using the certificate face’s sign action).
    EOT
    Puppet::CloudPack.add_init_options(self)
    when_invoked do |server, options|
      Puppet::CloudPack.init(server, options)
    end
  end
end
