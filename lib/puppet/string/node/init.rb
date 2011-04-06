require 'rubygems'
require 'fog'

Puppet::String.define :node, '0.0.1' do
  action :init do
    option '--login=', '-l=', '--username='
    option '--keyfile=', '-k='
    option '--tarball=', '--puppet='
    option '--answers='
    when_invoked do |server, options|
      certname = install(server, options)
      # TODO: Sign Certificate.
      # TODO: Register / classify node with ENC.
    end
  end
end
