require 'puppet/cloudpack'

Puppet::Face.define :cloudnode, '0.0.1' do
  action :init do
    Puppet::CloudPack.add_init_options(self)
    when_invoked do |server, options|
      Puppet::CloudPack.init(server, options)
    end
  end
end
