# AWS CloudWatch Logs
class profile::aws::cloudwatch {

  class { '::cloudwatchlogs': region => 'us-east-1' }
  Concat['/etc/awslogs/awslogs.conf'] -> Exec['cloudwatchlogs-install']

  lookup({
    'name'          => 'profile::aws::cloudwatch::logs',
    'merge'         => 'hash',
    'default_value' => {}
  }).each |String $name, Hash $params| {
    cloudwatchlogs::log { $name:
      * => $params;
    }
  }
}
