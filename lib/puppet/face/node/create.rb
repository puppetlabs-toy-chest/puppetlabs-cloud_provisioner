require 'puppet/cloudpack'

Puppet::Face.define :node, '0.0.1' do
  action :create do
    Puppet::CloudPack.add_create_options(self)
    when_invoked do |options|
      Puppet::CloudPack.create(options)
    end
  end
end
