Puppet CloudPack
================

Puppet Plugins for managing in the cloud.

This module requires Puppet 2.7.0 or later.

Getting Started
===============

 * [Getting Started With CloudPack](http://docs.puppetlabs.com/guides/cloud_pack_getting_started.html)

Building the Module
===================

The [Puppet Module Tool](https://github.com/puppetlabs/puppet-module-tool) may
be used to build an installable package of this Puppet Module.

    $ puppet-module build
    ======================================================
    Building /Users/jeff/src/modules/cloudpack for release
    ------------------------------------------------------
    Done. Built: pkg/puppetlabs-cloudpack-0.0.1.tar.gz

To install the packaged module:

    $ cd <modulepath> (usually /etc/puppet/modules)
    $ puppet-module install ~/src/modules/cloudpack/pkg/puppetlabs-cloudpack-0.0.1.tar.gz
    Installed "puppetlabs-cloudpack-0.0.1" into directory: cloudpack
