Puppet::Face.define :node, '0.0.1' do
  action :init do
    option '--login=', '-l=', '--username='
    option '--keyfile=', '-k='
    option '--installer-payload='
    option '--installer-answers='
    option '--node-group=', '--as='
    when_invoked do |server, options|
      certname = install(server, options)
      options.delete(:_destroy_server_at_exit)

      puts "Puppet Enterprise is now installed on: #{server}"

      classify(certname, options)

      # HACK: This should be reconciled with the Certificate Face.
      opts = options.merge(:ca_location => :remote)

      # TODO: Wait for C.S.R.?

      print "Signing certificate ..."
      begin
        Puppet::Face[:certificate, '0.0.1'].sign(certname, opts)
        puts " Done"
      rescue Puppet::Error => e
        # TODO: Write useful next steps.
        puts " Failed"
      rescue Net::HTTPError => e
        # TODO: Write useful next steps
        puts " Failed"
      end
    end
  end
end
