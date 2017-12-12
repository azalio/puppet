# CA Certificates
class profile::ca_certs () {
  $update_certificates_command = $facts['os']['family'] ? {
    'Debian' => '/usr/sbin/update-ca-certificates',
  }

  # Populate certificates
  file {'CA Certificates':
    ensure  => 'directory',
    path    => '/usr/share/ca-certificates/ca_certs',
    purge   => true,
    recurse => true,
    source  => "puppet:///modules/${module_name}/ca_certs",
    notify  => Exec['update-ca-certificates'],
  }

  exec { 'update-ca-certificates':
    refreshonly => true,
    command     => $update_certificates_command,
  }
}