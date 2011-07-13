require 'puppet/cloudpack'

Puppet::Face.define :node, '0.0.1' do
  action :fingerprint do
    summary 'Make a best effort to securely obtain the SSH host key fingerprint'
    description <<-EOT
      If an image configured to print the SSH host key fingerprint to the
system console is being used, then we have a secure means to read the system
console and obtain the key fingerprint.  Many machine images do not print the
fingerprint to the console, so this action waits for console data to become
available through the EC2 API and looks for a pattern matching a host key
fingerprint.  If one is found, the fingerprint is returned otherwise a warning
is displayed.  In either case, if this command returns without an error then
the system is ready for use.
    EOT
    Puppet::CloudPack.add_fingerprint_options(self)
    when_invoked do |server, options|
      Puppet::CloudPack.fingerprint(server, options)
    end
  end
end

