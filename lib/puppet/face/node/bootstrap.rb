Puppet::Face.define :node, '0.0.1' do
  action :bootstrap do
    option '--image=', '-i='
    option '--keypair=', '-k='
    option '--group=', '-g=', '--security-group='
    option '--login=', '-l=', '--username='
    option '--keyfile='
    option '--installer-payload='
    option '--installer-answers='
    option '--node-group=', '--as='
    when_invoked do |options|
      options[:_destroy_server_at_exit] = :bootstrap
      server = self.create(options)
      self.init(server, options)
      options.delete(:_destroy_server_at_exit)
    end
  end
end