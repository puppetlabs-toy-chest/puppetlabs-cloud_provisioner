require 'puppet/cloudpack'

Puppet::Face.define :node, '0.0.1' do
  action :bootstrap do
    Puppet::CloudPack.add_bootstrap_options(self)
    when_invoked do |options|
      Puppet::Cloudpack.bootstrap(options)
    end
  end
end
