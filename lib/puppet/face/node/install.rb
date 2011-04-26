require 'puppet/cloudpack'

Puppet::Face.define :node, '0.0.1' do
  action :install do
    Puppet::CloudPack.add_install_options(self)
    when_invoked do |server, options|
      Puppet::CloudPack.install(server, options)
    end
  end
end
