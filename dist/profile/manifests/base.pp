# Base Profile
class profile::base {
  # Standard Library
  include ::stdlib

  # APT
  if $facts['os']['family'] == 'Debian' {
    # Patch until the apt module supports Ubuntu 16.04
    ensure_packages('software-properties-common')
    class { '::apt': require => Package['software-properties-common'] }

    # Upgrade system
    include ::unattended_upgrades
  }

  # Security
  class { '::sudo':
    purge               => false,
    config_file_replace => false,
  }
  include ::sudo::configs
  include ::ssh

  # Users
  lookup({
    'name'          => 'profile::base::users',
    'merge'         => 'hash',
    'default_value' => {}
  }).each |String $name, Hash $params| {
    user {
      default: * => {
                      ensure         => 'present',
                      shell          => '/bin/bash',
                      home           => "/home/${name}",
                      purge_ssh_keys => true,
                    };
      $name: * => $params;
    }
  }

  # SSH Keys(make sure the name us unique, even with existing keys)
  lookup({
    'name'          => 'profile::base::ssh_authorized_keys',
    'merge'         => 'hash',
    'default_value' => {}
  }).each |String $name, Hash $params| {
    ssh_authorized_key {
      default: * => {
                      ensure => 'present',
                      user   => 'root',
                    };
      $name: * => $params;
    }
  }

  # CRON Jobs
  lookup({
    'name'          => 'profile::base::cron_jobs',
    'merge'         => 'hash',
    'default_value' => {}
  }).each |String $name, Hash $params| {
    cron {
      default: * => {
                      ensure => 'present',
                      user   => 'root',
                    };
      $name: * => $params;
    }
  }

  # INI Settings
  lookup({
    'name'          => 'profile::base::ini_settings',
    'merge'         => 'hash',
    'default_value' => {}
  }).each |String $name, Hash $params| {
    ini_setting { $name:
      * => $params;
    }
  }

  # Packages
  ensure_packages(lookup({
    'name'          => "profile::base::${facts['os']['name']}::${facts['lsbdistcodename']}::packages",
    'merge'         => 'unique',
    'default_value' => []
  }))

  # Repositories
  lookup({
    'name'          => 'profile::base::vcsrepos',
    'merge'         => 'hash',
    'default_value' => {}
  }).each |String $name, Hash $params| {
    include ::profile::git
    vcsrepo {
      default: * => {
                      ensure   => 'latest',
                      provider => 'git',
                      revision => 'master',
                      require  => Package['git'],
                    };
      $name: * => $params;
    }
  }

  # Others
  include ::wget
  include ::ntp
  include ::profile::time
  include ::profile::misc
}
