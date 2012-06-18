# == Class: cloud_provisioner
#
# This class manages the installation of Cloud Provisioner on a node.
# Particularly it installs the node_aws Face application into the appropriate
# location on the system.
#
# === Parameters
#
# Document parameters here.
#
# [*puppet_installation_directory*]
#   The directory of the puppet installation. It defaults to the value of the
#   $puppet_install_dir Facter fact.
# [*ensure*]
#   The state of the node_aws sub application. Values can be
#   ['present','absent','installed','uninstalled']. Defaults to 'present'
#
# === Examples
#
#  class { 'cloud_provisioner':
#    ensure => present,
#  }
#
# === Copyright
#
# Copyright 2011 Puppet Labs Inc
#
class cloud_provisioner(
    $puppet_install_directory  = "${puppet_install_dir}/puppet",
    $ensure = 'present'
  ) {

  case $ensure {
    'present','installed':  { $ensure_safe = file   }
    'absent','uninstalled': { $ensure_safe = absent }
    default: {
      fail "Unknown value ${ensure} of 'ensure' parameter for Class[cloud-provisioner].  Accepted values are ['present','absent']"
    }
  }

  file { "${puppet_install_directory}/application/node_aws.rb":
    ensure => $ensure_safe,
    source => 'puppet:///modules/cloud_provisioner/node_aws.rb',
    mode   => 0644,
  }
}
