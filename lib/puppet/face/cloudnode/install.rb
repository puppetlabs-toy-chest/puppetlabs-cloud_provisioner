require 'puppet/cloudpack'

Puppet::Face.define :cloudnode, '0.0.1' do
  action :install do
    summary 'Install Puppet on an arbitrary node'
    description <<-EOT
      Installs Puppet on an existing instance. It uses scp to
      copy installation requirements to the machine and ssh to
      run the installation commmands remotely.
    EOT
    Puppet::CloudPack.add_install_options(self)
    when_invoked do |server, options|
      Puppet::CloudPack.install(server, options)
    end
  end
end
