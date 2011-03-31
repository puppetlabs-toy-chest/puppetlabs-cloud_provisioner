require 'rubygems'
require 'fog'

Puppet::String.define :node, '0.0.1' do
  action :bootstrap do
    option '--image=', '-i='
    option '--keypair=', '-k='
    option '--group=', '-g=', '--security-group='
    option '--login=', '-l=', '--username='
    option '--keyfile='
    option '--tarball=', '--puppet='
    option '--answers='
    invoke do |name, options|
      server = self.create(nil, options)
      self.init(nil, server, options)
    end
  end

  action :init do
    option '--login=', '-l=', '--username='
    option '--keyfile=', '-k='
    option '--tarball=', '--puppet='
    option '--answers='
    invoke do |name, server, options|
      server.username = options['login']
      server.private_key_path = options['keyfile']

      print "Waiting for SSH response ..."
      retries = 0
      begin
        # TODO: Certain cases cause this to hang?
        server.ssh(['hostname'])
      rescue
        sleep 60
        retries += 1
        print '.'
        raise "SSH not responding; aborting." if retries > 5
        retry
      end
      puts " Done"

      print "Uploading Puppet ..."
      server.scp(options['tarball'], '/tmp/puppet.tar.gz')
      puts " Done"

      print "Uploading Puppet Answer File ..."
      server.scp(option['answers'], '/tmp/puppet.answers')
      puts " Done"

      print "Installing Puppet ..."
      steps = [
        'tar -xvzf /tmp/puppet.tar.gz -C /tmp',
        '/tmp/puppet-enterprise-1.0-all/puppet-enterprise-installer -a /tmp/puppet.answers'
      ]
      server.ssh(steps.map { |c| server.username == 'root' ? cmd : "sudo #{c}" })
      puts " Done"
    end
  end
end
