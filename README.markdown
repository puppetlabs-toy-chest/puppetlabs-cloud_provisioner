Puppet Cloud Provisioner
========================

Puppet Module to launch and manage Cloud instances.

This module requires Puppet 2.7.0 or later.

Getting Started
===============

 * [Getting Started With Cloud Provisioner](http://docs.puppetlabs.com/guides/cloud_pack_getting_started.html)

Reporting Issues
----------------

Please report any problems you have with the Cloud Provisioner module in the project page issue tracker at:

 * [Cloud Provisioner Issues](http://projects.puppetlabs.com/projects/cloud-pack/issues)

Getting Started with Amazon EC2
===============================

Before launching instances with the Cloud Provisioner module, you'll need to register
with Amazon AWS and obtain your access credentials.

 * [Amazon Web Services Registration](http://www.amazon.com/gp/aws/registration/registration-form.html)

Once registered, obtain your Access Key ID and Access Key.  Place them into the
~/.fog file with the following syntax:

    :default:
      :aws_access_key_id: AKIAIXXXXXXXXXXXXXXX
      :aws_secret_access_key: jcjnhaXXXXXXXXXXXXXXXXXXXX/XXXXXXXXXXXXX

Once you have your Access key and ID in the ~/.fog file, you'll also need to
generate your SSH private key in the AWS console.  The filesystem path to this
private key is what you should provide to the --keyfile option.

Finally, you'll probably want to configure the default EC2 security group to
allow SSH (Port 22) access.  This can be accomplished through the Amazon EC2
console.  The install actions will fail if they cannot access the target system
on port 22 (SSH).

Required Gems
=============

 * guid (>= 0.1.1)
 * fog (0.7.2)

Note, the rspec unit tests currently have problems with Fog 0.9.0, but the
command line actions themselves appear to work.  If you have problems with
Cloud Provisioner, please try the specific version of Fog.  You may install 0.7.2
using the following command:

    gem install fog -v 0.7.2 --no-ri --no-rdoc

AMI Image
---------

Picking an AMI image can be daunting.  There are a lot of them out there.

During development of Cloud Provisioner, I often used the following CentOS image which
is compatible with [AWS Free Usage Tier][free tier] amazon instances:

 * ami-2342a94a (US-East region) CentOS 5 (Login: root)
 * ami-25df8e60 (US-West region) CentOS 5 (Login: root)

A Ubuntu based AMI in the East region also works well with the [AWS Free Usage Tier][free tier] Amazon instances:

 * ami-06ad526f (US-East region) Ubuntu (Login: ubuntu)

Launching EC2 Instances
=======================

With your EC2 credentials placed in ~/.fog and your SSH private key available
on your system, you may launch a new instance with this module installed using
the following single command:

    $ puppet node create --image ami-2342a94a --keypair jeff --type t1.micro
    notice: Creating new instance ...
    notice: Creating new instance ... Done
    notice: Creating tags for instance ...
    notice: Creating tags for instance ... Done
    notice: Launching server i-e5c00f84 ...
    ##############
    notice: Server i-e5c00f84 is now launched
    notice: Server i-e5c00f84 public dns name: ec2-107-20-18-142.compute-1.amazonaws.com
    ec2-107-20-18-142.compute-1.amazonaws.com

Once launched, you should be able to SSH to the new system using the private
key associated with the keypair specified in the create action:

    $ ssh -i ~/.ssh/jeff.pem root@ec2-107-20-18-142.compute-1.amazonaws.com
    RSA key fingerprint is a1:88:33:fa:de:d7:7c:a8:84:ae:89:73:01:a2:2b:e8.
    Are you sure you want to continue connecting (yes/no)? yes
    Warning: Permanently added 'ec2-107-20-18-142.compute-1.amazonaws.com,107.20.18.142' (RSA) to the list of known hosts.
    [root@domU-12-31-39-07-8C-79 ~]# quit

Finally, you're able to install Puppet or Puppet Enterprise on the newly
launched system:

    $ puppet node install --login root --keyfile ~/.ssh/jeff.pem ec2-107-20-18-142.compute-1.amazonaws.com
    notice: Waiting for SSH response ...
    notice: Waiting for SSH response ... Done
    notice: Installing Puppet ...
    66421292-9dee-7f41-624e-6ad2c50d78c1

If you need more detailed information, please use the --verbose and --debug
options to get more detailed output from the command.

As we can see, this installs Puppet using ruby gems:

    $ ssh root@ec2-107-20-18-142.compute-1.amazonaws.com puppet --version
    2.6.4

Puppet Installation
===================

The following installation scripts are available to install puppet on a target
system.  These script are appropriate values for the --install-script option to
the puppet node install action.

 * gems (default) - Installs Puppet and Facter from RubyGems.

 * puppet-enterprise - Installs Puppet by uploading a copy of the puppet
enterpise tarball from your workstation to the target node along with an
automated answers file.

 * puppet-enterprise-s3 - Installs Puppet by downloading a copy of Puppet
Enterprise 1.1 from Puppet Labs.  This may be much faster than the
puppet-enterprise script if you have limited upload bandwidth.

Building the Module
===================

The [Puppet Module Tool](https://github.com/puppetlabs/puppet-module-tool) may
be used to build an installable package of this Puppet Module.

    $ puppet-module build
    ==============================================================
    Building /Users/jeff/src/modules/cloud-provisioner for release
    --------------------------------------------------------------
    Done. Built: pkg/puppetlabs-cloud-provisioner-0.0.1git-95-g6541187.tar.gz

To install the packaged module:

    $ cd <modulepath> (usually /etc/puppet/modules)
    $ puppet-module install ~/src/modules/cloud-provisioner/pkg/puppetlabs-cloud-provisioner-0.0.1git-95-g6541187.tar.gz
    Installed "puppetlabs-cloud-provisioner-0.0.1git-95-g6541187.tar.gz" into directory: cloud-provisioner

External Documentation
======================

 * [free tier]: http://aws.amazon.com/free/ "AWS Free Usage Tier"

