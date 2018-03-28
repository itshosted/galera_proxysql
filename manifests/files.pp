
# == Class: galera_proxysql::files
#
# This Class provides files
#
class galera_proxysql::files (
  $percona_major_version        = $::galera_proxysql::params::percona_major_version,
  $backup_compress              = $::galera_proxysql::params::backup_compress,
  $backup_dir                   = $::galera_proxysql::params::backup_dir,
  $backup_retention             = $::galera_proxysql::params::backup_retention,
  $galera_cluster_name          = $::galera_proxysql::params::galera_cluster_name,
  $galera_hosts                 = $::galera_proxysql::params::galera_hosts,
  $innodb_buffer_pool_instances = $::galera_proxysql::params::innodb_buffer_pool_instances,
  $innodb_flush_method          = $::galera_proxysql::params::innodb_flush_method,
  $innodb_io_capacity           = $::galera_proxysql::params::innodb_io_capacity,
  $innodb_log_file_size         = $::galera_proxysql::params::innodb_log_file_size,
  $logdir                       = $::galera_proxysql::params::logdir,
  $max_connections              = $::galera_proxysql::params::max_connections,
  $monitor_password             = $::galera_proxysql::params::monitor_password,
  $monitor_username             = $::galera_proxysql::params::monitor_username,
  $query_cache                  = $::galera_proxysql::params::query_cache,
  $root_password                = $::galera_proxysql::params::root_password,
  $sst_password                 = $::galera_proxysql::params::sst_password,
  $thread_cache_size            = $::galera_proxysql::params::thread_cache_size,
  $tmpdir                       = $::galera_proxysql::params::tmpdir,
  $slow_query_time              = $::galera_proxysql::params::slow_query_time,
  ) inherits galera_proxysql::params {

  unless defined( File['/root/bin'] ) {
    file { '/root/bin':
      ensure => directory,
      mode   => '0755';
    }
  }

  file {
    default:
      ensure  => file,
      mode    => '0644',
      owner   => 'root',
      group   => 'root',
      require => [
        FIle['/root/bin'],
        Package["Percona-XtraDB-Cluster-full-${percona_major_version}"]
      ];
    '/etc/my.cnf':
      source => "puppet:///modules/${module_name}/my.cnf";
    '/etc/my.cnf.d':
      ensure  => directory,
      purge   => true,
      recurse => true,
      force   => true;
    '/usr/bin/galera_wizard.py':
      mode    => '0755',
      content => template("${module_name}/galera_wizard.py");
    '/root/galera_params.py':
      content => template("${module_name}/galera_params.py.erb"),
      notify  => Service['xinetd'];
    '/root/bin/hotbackup.sh':
      mode    => '0755',
      content => template("${module_name}/hotbackup.sh.erb"),
      require => File['/root/bin'],
      notify  => Service['xinetd'];
    '/root/.my.cnf':
      mode    => '0660',
      notify  => Xinetd::Service['galerachk'],
      content => template("${module_name}/root_my.cnf.erb");
    '/etc/sysconfig/clustercheck':
      notify  => Xinetd::Service['galerachk'],
      content => template("${module_name}/clustercheck.erb");
    '/usr/bin/clustercheck':
      mode   => '0755',
      notify => Xinetd::Service['galerachk'],
      source => "puppet:///modules/${module_name}/clustercheck";
    '/etc/my.cnf.d/client.cnf':
      source  => "puppet:///modules/${module_name}/client.cnf";
    '/etc/my.cnf.d/mysql-clients.cnf':
      source  => "puppet:///modules/${module_name}/mysql-clients.cnf";
    '/etc/my.cnf.d/server.cnf':
      mode    => '0640',
      content => template("${module_name}/server.cnf.erb");
    '/etc/my.cnf.d/wsrep.cnf':
      mode    => '0640',
      content => template("${module_name}/wsrep.cnf.erb");
    '/etc/my.cnf.d/mysqld_safe.cnf':
      mode   => '0644',
      source => "puppet:///modules/${module_name}/mysqld_safe.cnf";
  }

  file_line { 'mysql_systemd':
    ensure             => present,
    path               => '/usr/bin/mysql-systemd',
    line               => 'export HTTP_PROXY=http://squid.puppetlabs.vm:3128',
    match              => '/usr/sbin/mysqld --initialize --datadir',
    append_on_no_match => false,
    require            => Package["Percona-XtraDB-Cluster-full-${percona_major_version}"];
  }

  exec { 'galera_systemctl_daemon_reload':
    command     => 'systemctl daemon-reload',
    path        => '/usr/bin:/usr/sbin:/bin:/usr/local/bin',
    onlyif      => 'which systemctl',
    refreshonly => true;
  }

}