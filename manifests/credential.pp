define cloud_provisioner::credential(
    $aws_access_key_id = undef,
    $aws_secret_access_key = undef,
    $vsphere_server = undef,
    $vsphere_username = undef,
    $vsphere_password = undef,
    $vsphere_expected_pubkey_hash = undef,
  ) {

  include concat::setup

  concat::fragment { $name:
    target  => $cloud_provisioner::fog_credential_file,
    content => template('cloud_provisioner/credential.erb'),
  }
}
