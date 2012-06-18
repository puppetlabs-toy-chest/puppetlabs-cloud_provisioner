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
# [*provisioner_account_home_directory*]
#   The full qualified path to the home directory of the user that will be controlling Cloud Provisioner
# [*default_aws_access_key_id*]
#   The AWS access key ID for the default credentials.
#   To obtain, take a look at this thread (https://forums.aws.amazon.com/thread.jspa?threadID=49738)
# [*default_aws_secret_access_key*]
#   The AWS access secret key for the default credentials.
#   To obtain, take a look at this thread (https://forums.aws.amazon.com/thread.jspa?threadID=49738)
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
    $ensure = 'present',
    $provisioner_account_home_directory = '/root',
    $default_aws_access_key_id = undef,
    $default_aws_secret_access_key = undef,
    $default_vsphere_server = undef,
    $default_vsphere_username = undef,
    $default_vsphere_password = undef,
    $default_vsphere_expected_pubkey_hash = undef,
  ) {

  include concat::setup
 
  #This variable is also used by the cloud_provisioner::credential defined type
  $fog_credential_file = "${provisioner_account_home_directory}/.fog"

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

  package { ['fog','guid']:
    ensure   => installed,
    provider => gem,
    require  => Class['ruby::dev'],
  }

  concat { $fog_credential_file:
    mode => 0644,
  }

  cloud_provisioner::credential { 'default':
    aws_access_key_id            => $default_aws_access_key_id,
    aws_secret_access_key        => $default_aws_secret_access_key,
    vsphere_server               => $default_vsphere_server,
    vsphere_username             => $default_vsphere_username,
    vsphere_password             => $default_vsphere_password,
    vsphere_expected_pubkey_hash => $default_vsphere_expected_pubkey_hash,
  }
}
