require 'puppet/cloudpack'

Puppet::Face.define :cloudnode, '0.0.1' do
  action :terminate do
    Puppet::CloudPack.add_terminate_options(self)
    when_invoked do |server, options|
      Puppet::CloudPack.terminate(server, options)
    end
  end
end
