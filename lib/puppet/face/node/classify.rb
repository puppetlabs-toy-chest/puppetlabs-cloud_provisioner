require 'puppet/cloudpack'

Puppet::Face.define :node, '0.0.1' do
  action :classify do
    Puppet::CloudPack.add_classify_options(self)
    when_invoked do |certname, options|
      Puppet::CloudPack.classify(certname, options)
    end
  end
end
