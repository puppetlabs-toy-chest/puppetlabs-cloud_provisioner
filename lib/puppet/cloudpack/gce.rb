require 'puppet/cloudpack'

# This is a container for various horrible procedural code used to set up the
# face actions for the `node_gce` face.  It lives here because the design of
# faces -- reinventing the Ruby object model, poorly -- makes it impossible to
# do standard things such as module inclusion, or inheritance, that would
# normally solve these problems in a real OO system.
module Puppet::CloudPack::GCE
  module_function

  def options(to, *which)
    which.each do |name|
      send("add_#{name}", to)
    end
  end

  def add_project(to)
    to.option '--project SCP-1125' do
      summary 'The project to list instances from'
      required
    end
  end

  def add_zone(to)
    to.option '--zone us-central1-a' do
      summary 'Limit to instances in the specified zone'
      default_to { 'us-central1-a' }
    end
  end

  def add_wait(to)
    to.option '--[no-]wait' do
      summary 'wait for instance creation to complete before returning'
      default_to { true }
    end
  end

  def add_image(to)
    to.option '--image <name|url>' do
      summary 'the disk image name, or full URL, to boot from'
      required
    end

    to.option '--image-search <project, project>' do
      summary 'the additional projects to search for images by name'
      description <<-EOT
        The additional projects to search for images by name.

        Google Compute supplies a number of default images, but they live
        in their own little world -- distinct projects.  This allows you to
        set the search path for images specified by name.

        It should be a comma separated list of projects.
      EOT

      default_to do
        require 'puppet/google_api'
        Puppet::GoogleAPI::StandardImageProjects.join(',')
      end

      before_action do |action, args, options|
        # Fun times, but for consistency to the user...
        options[:image_search] = options[:image_search].split(',').map(&:strip)
      end
    end
  end

  def add_login(to)
    to.option '--login <username>', '-l <username>', '--username <username>' do
      summary 'The login user to create on the target system.'
      description <<-EOT
        The login user to create on the target system.  This, along with the
        SSH public key, is added to the instance metadata -- which in turn will
        cause the Google supplied scripts to create the appropriate account
        on the instance.
      EOT
    end

    to.option '--key <keyname | path>' do
      summary 'The SSH keypair name or file to install on the created user account.'
      description <<-EOT
        The SSH keypair name or file to install on the created user account.

        The normal value is a keypair name -- relative to ~/.ssh -- that is used
        to locate the private and public keys.  On the target system, only the
        public key is stored.  The private key never leaves your machine.
      EOT

      default_to do
        if File.exist?('~/.ssh/google_compute_engine')
          '~/.ssh/google_compute_engine'
        else
          'id_rsa'
        end
      end

      before_action do |action, args, options|
        # First, make sure the pathname is absolute; this turns relative names
        # into names relative to the .ssh directory, but preserves an
        # absolute path.
        key = Pathname(options[:key]).expand_path('~/.ssh')

        # Figure out if we got pointed to the public key; we keep this option
        # pointing at the private key by convention.
        if key.read =~ /PUBLIC KEY|^ssh-/ and key.extname.downcase == '.pub'
          key = key.sub_ext('')
        end

        # Now, verify that we are pointed to a private key file.
        unless key.read =~ /PRIVATE KEY/
          raise <<EOT
SSH keypair #{options[:key]} does not have private and public key data where I
expect it to be, and I can't figure out how to locate the right parts.

We assume that the private key material is in `.../example-key`, and that the
public key material is in a corresponding `.../example-key.pub` file.

If the option is relative, we assume the base directory is `~/.ssh`.

Please point the key option at the private key file, and put the public key in
place next to it with an additional `.pub` extension.
EOT
        end

        # Finally, update the option to reflect our changes.
        options[:key] = key.to_s
      end
    end
  end
end
