# == Class: galera_proxysql::proxysql::proxysql
#
# === Parameters & Variables
#
# [*galera_hosts*] <Hash>
#   list of hosts, ipv4 (optionally ipv6) belonging to the cluster: not less than 3, not even.
#   check examples on README.md
#
# [*http_proxy*] <String>
#   default: undef  http proxy used for instance by gpg key
#   Example: 'http://proxy.example.net:8080'
#
# [*limitnofile*] <String>
#   default: undef (number of open files)
#
# [*manage_repo*] <Bool>
#   default: true => please check repo.pp to understand what repos are neeeded
#
# [*proxysql_hosts*] <Hash>
#   list of hosts, ipv4 (optionally ipv6) belonging to ProxySQL cluster.
#   Currently only 2 hosts are supported. Check examples on README.md
#
# [*proxysql_admin_password*] <Sensitive>
#   proxysql user password
#
# [*proxysql_vip*] <Hash>
#   host, ipv4 (optionally ipv6) for the VIP
#
# [*trusted_networks*] <Array>
#   default: undef => List of IPv4 and/or IPv6 host and or networks.
#            It's used by iptables to determine from where to allow access to MySQL
#
#
class galera_proxysql::proxysql::proxysql (
  String $percona_major_version  = $galera_proxysql::params::percona_major_version,
  Boolean $force_ipv6            = $galera_proxysql::params::force_ipv6,
  Hash $galera_hosts             = $galera_proxysql::params::galera_hosts,
  Boolean $manage_repo           = $galera_proxysql::params::manage_repo,
  Hash $proxysql_hosts           = $galera_proxysql::params::proxysql_hosts,
  Hash $proxysql_vip             = $galera_proxysql::params::proxysql_vip,
  Hash $proxysql_users           = $galera_proxysql::params::sqlproxy_users,
  Array $trusted_networks        = $galera_proxysql::params::trusted_networks,
  String $network_interface      = $galera_proxysql::params::network_interface,
  String $proxysql_version       = $galera_proxysql::params::proxysql_version,
  String $proxysql_mysql_version = $galera_proxysql::params::proxysql_mysql_version,
  $limitnofile                   = $galera_proxysql::params::limitnofile,
  $http_proxy                    = $galera_proxysql::params::http_proxy,

  # Passwords
  Variant[Sensitive, String] $monitor_password        = $galera_proxysql::params::monitor_password,
  Variant[Sensitive, String] $proxysql_admin_password = $galera_proxysql::params::proxysql_admin_password

) inherits galera_proxysql::params {

  if $monitor_password =~ String {
    notify { '"monitor_password" String detected!':
      message => 'It is advisable to use the Sensitive datatype for "monitor_password"';
    }
    $monitor_password_wrap = Sensitive($monitor_password)
  } else {
    $monitor_password_wrap = $monitor_password
  }
  if $proxysql_admin_password =~ String {
    notify { '"proxysql_admin_password" String detected!':
      message => 'It is advisable to use the Sensitive datatype for "proxysql_admin_password"';
    }
    $proxysql_admin_password_wrap = Sensitive($proxysql_admin_password)
  } else {
    $proxysql_admin_password_wrap = $proxysql_admin_password
  }

  $proxysql_key_first = keys($proxysql_hosts)[0]
  $vip_key = keys($proxysql_vip)[0]
  $vip_ip = $proxysql_vip[$vip_key]['ipv4']
  if has_key($proxysql_hosts[$proxysql_key_first], 'ipv6') {
    $ipv6_true = true
  } else {
    $ipv6_true = undef
  }

  $list_top = "{\n    address = \""
  $list_bottom = '"
    port = 3306
    hostgroup = 0
    status = "ONLINE"
    weight = 1
    compression = 0
    max_replication_lag = 0
  },'
  $list_bottom_write = '"
    port = 3306
    hostgroup = 1
    status = "ONLINE"
    weight = 1
    compression = 0
    max_replication_lag = 0
  },'
  $galera_keys = keys($galera_hosts)
  if ($force_ipv6) {
    $transformed_data = $galera_keys.map |$items| { $galera_hosts[$items]['ipv6'] }
  } else {
    $transformed_data = $galera_keys.map |$items| { $galera_hosts[$items]['ipv4'] }
  }

  $_server_list = join($transformed_data, "${list_bottom}${list_top}")
  $server_list = "  ${list_top}${_server_list}${list_bottom}"

  $_server_list_write = join($transformed_data, "${list_bottom_write}${list_top}")
  $server_list_write = "${list_top}${_server_list_write}${list_bottom_write}".chop()

  class {
    '::galera_proxysql::repo':
      http_proxy  => $http_proxy,
      manage_repo => $manage_repo;
    '::galera_proxysql::proxysql::service':
      limitnofile => $limitnofile;
    '::galera_proxysql::proxysql::keepalived':
      use_ipv6          => $ipv6_true,
      proxysql_hosts    => $proxysql_hosts,
      network_interface => $network_interface,
      proxysql_vip      => $proxysql_vip;
    '::galera_proxysql::firewall':
      use_ipv6         => $ipv6_true,
      galera_hosts     => $galera_hosts,
      proxysql_hosts   => $proxysql_hosts,
      proxysql_vip     => $proxysql_vip,
      trusted_networks => $trusted_networks;
    '::mysql::client':
      package_name => "Percona-XtraDB-Cluster-client-${percona_major_version}";
  }

  package {
    "Percona-Server-shared-compat-${percona_major_version}":
      ensure  => installed,
      require => Class['::galera_proxysql::repo'],
      before  => Class['::mysql::client'];
    'proxysql':
      ensure  => $proxysql_version,
      require => [Class['::mysql::client', '::galera_proxysql::repo']];
  }

  file {
    default:
      owner => root,
      group => root;
    '/usr/bin/proxysql_galera_checker':
      mode    => '0755',
      require => Package['proxysql'],
      notify  => Service['proxysql'],
      source  => "puppet:///modules/${module_name}/proxysql_galera_checker";
    '/var/lib/mysql':
      ensure  => directory,
      owner   => proxysql,
      group   => proxysql,
      require => Package['proxysql'],
      notify  => Service['proxysql'];
    '/root/.my.cnf':
      content => Sensitive("[client]\nuser=monitor\npassword=${monitor_password_wrap.unwrap}\nprompt = \"\\u@\\h [DB: \\d]> \"\n");
    '/etc/proxysql-admin.cnf':
      mode    => '0640',
      group   => proxysql,
      require => Package['proxysql'],
      notify  => Service['proxysql'],
      content => Sensitive(epp("${module_name}/proxysql-admin.cnf.epp", {
        'monitor_password'        => Sensitive($monitor_password_wrap),
        'proxysql_admin_password' => Sensitive($proxysql_admin_password_wrap)
      }));
  }

$proxysql_cnf_second_content = "  {
    username = \"monitor\"
    password = \"${monitor_password_wrap.unwrap}\"
    default_hostgroup = 0
    active = 1
  }"

  concat { '/etc/proxysql.cnf':
    owner   => 'proxysql',
    group   => 'proxysql',
    mode    => '0640',
    order   => 'numeric',
    require => Package['proxysql'],
    notify  => Service['proxysql'];
  }

  concat::fragment {
    'proxysql_cnf_header':
      target  => '/etc/proxysql.cnf',
      content => epp("${module_name}/proxysql_header.cnf.epp", {
        'proxysql_admin_password' => Sensitive($proxysql_admin_password_wrap),
        'proxysql_mysql_version'  => $proxysql_mysql_version,
        'monitor_password'        => Sensitive($monitor_password_wrap),
        'server_list_write'       => $server_list_write,
        'server_list'             => $server_list
      }),
      order   => '1';
    'proxysql_cnf_second':
      target  => '/etc/proxysql.cnf',
      content => $proxysql_cnf_second_content,
      order   => '2';
    'proxysql_cnf_footer':
      target  => '/etc/proxysql.cnf',
      content => epp("${module_name}/proxysql_footer.cnf.epp"),
      order   => '999999999';
  }

  $proxysql_users.each | $sqluser, $sqlpass | {
    $concat_order = fqdn_rand(999999997, "${sqluser}${sqlpass}")+2
    concat::fragment { "proxysql_cnf_fragment_${sqluser}_${sqlpass}":
      target  => '/etc/proxysql.cnf',
      content => ",{\n    username = \"${sqluser}\"\n    password = \"${sqlpass}\"\n    default_hostgroup = 0\n    active = 1\n  }",
      order   => $concat_order;
    }
  }

  # we need a fake exec in common with galera nodes to let galera
  # use the `before` statement defined in the same firewall class
  unless defined(Exec['bootstrap_or_join']) {
    exec { 'bootstrap_or_join':
      command     => 'echo',
      path        => '/usr/bin:/bin',
      refreshonly => true;
    }
  }
  unless defined(Exec['join_existing']) {
    exec { 'join_existing':
      command     => 'echo',
      path        => '/usr/bin:/bin',
      refreshonly => true;
    }
  }

}
