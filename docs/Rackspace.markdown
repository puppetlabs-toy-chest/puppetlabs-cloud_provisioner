# Cloud Provisioner Rackspace Support #

This Puppet module adds Rackspace support to Cloud Provisioner.

## Getting started ##

The node_rackspace requires fog gem.

    $ gem install fog

Add your Rackspace Cloud Server credentials to the fog configuration file.

    # ~/.fog
    default:
      :rackspace_username: rackspaceuser
      :rackspace_api_key: XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

## Creating Rackspace Cloud Servers ##

Creating new Rackspace Cloud Servers

    $ puppet node_rackspace create -f 1 -i 104 -n demo

    notice: Connecting ...
    notice: Connected to Rackspace
    notice: Complete
    20365648:
      name:      demo
      serverid:  20365648
      hostid:    2ff006e68257221aa583f5bb2753a622
      ipaddress: 50.57.180.98
      state:     BUILD
      progress:  0
      password:  *************


Create a Rackspace Cloud server and unmask the admin password in the output.

    $ puppet node_rackspace create -f 1 -i 104 -n demo --show-password

Create a Rackspace Cloud server and wait for it to boot.

    $ puppet node_rackspace create -f 1 -i 104 -n demo -w

Create a Rackspace Cloud Server, wait for it to boot, then add the specificed SSH public key.

    $ puppet node_rackspace create -f 1 -i 104 -n demo -p ~/.ssh/id_rsa.pub

## Listing image, flavors, and servers ##

Listing servers.

    $ puppet node_rackspace list servers

    notice: Connecting ...
    notice: Connected to Rackspace
    notice: Complete
    20365648:
      name:      demo
      serverid:  20365648
      hostid:    2ff006e68257221aa583f5bb2753a622
      ipaddress: 50.57.180.98
      state:     BUILD
      progress:  100


Listing images.

    $ puppet node_rackspace list images

    notice: Connecting ...
    notice: Connected to Rackspace
    notice: Complete
    Windows Server 2008 R2 x64 - SQL Web:
      id:      81
      updated: 2011-10-04T08:39:34-05:00
      status:  ACTIVE

    Ubuntu 10.04 LTS (lucid):
      id:      49
      updated: 2011-11-05T09:34:30-05:00
      status:  ACTIVE

    Oracle EL Server Release 5 Update 4:
      id:      40
      updated: 2010-10-28T11:40:20-05:00
      status:  ACTIVE

    Ubuntu 9.10 (karmic):
      id:      14362
      updated: 2009-11-06T05:09:40-06:00
      status:  ACTIVE

    ...


Listing flavors.

    $ puppet node_rackspace list flavors

    notice: Connecting ...
    notice: Connected to Rackspace
    notice: Complete
    256 server:
      id:   1
      ram:  256
      disk: 10

    512 server:
      id:   2
      ram:  512
      disk: 20

    1GB server:
      id:   3
      ram:  1024
      disk: 40

    ...


## Rebooting Servers ##

Servers can be rebooted by server id.

    $ puppet node_rackspace terminate 12345678

## Terminating Servers ##

Servers can be terminated by server id.

    $ puppet node_rackspace terminate 12345678