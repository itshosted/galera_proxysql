# == Class: galera_proxysql::repo inherits galera
#
class galera_proxysql::repo (
  $http_proxy            = $::galera_proxysql::params::http_proxy,
  $manage_repo           = $::galera_proxysql::params::manage_repo
  ) inherits galera_proxysql::params {

  unless any2bool($manage_repo) == false {
    if ($http_proxy) { $proxy = $http_proxy } else { $proxy = absent }
    rpmkey { 'CD2EFD2A':
      ensure => present,
      source => 'http://www.percona.com/downloads/RPM-GPG-KEY-percona';
    }
    yumrepo { 'Percona':
      enabled    => '1',
      gpgcheck   => '1',
      proxy      => $proxy,
      mirrorlist => absent,
      baseurl    => "http://repo.percona.com/release/\$releasever/RPMS/\$basearch",
      descr      => 'Percona',
      gpgkey     => 'http://www.percona.com/downloads/RPM-GPG-KEY-percona',
      require    => Rpmkey['CD2EFD2A'];
    }
  }

}