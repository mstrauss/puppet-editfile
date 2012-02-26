# update match user block and fix sshd_config
# (match blocks must always be at EOF)
define sshd::matchuser( $ssh_chroot_dir, $ensure = present ) {
  $creates = "Match User ${name}
    ForceCommand internal-sftp
    ChrootDirectory ${ssh_chroot_dir}
    PasswordAuthentication yes"
  $creates_escaped = inline_template( '<%= Regexp.escape(creates).gsub("/", "\\/") %>' )
  editfile { "match $name in sshd_config":
    path   => '/etc/puppet/modules/editfile/doc/examples/broken_sshd_config',
    match  => "/(^Match User ${name}.*?)(^\\S.*|\\Z)/m",
    ensure => $ensure ? {
      present => "\\2\n${creates}\n",
      default => absent,
    },
    exact => true,
    creates => "/^${creates_escaped}\n+(^Match User.*?(?=^\\S.*|\\Z))*?(?=\\Z)/m",
  }
  
}
sshd::matchuser { 'username': ssh_chroot_dir => '/var/www' }

editfile {
  'enable global umask':
    path   => '/etc/puppet/modules/editfile/doc/examples/pam-common-session',
    # replace any existing line containing 'pam_umask' OR append at EOF
    match =>  'pam_umask',
    ensure => "session\toptional\tpam_umask.so umask=0002",
    ;
}

# postfix::maincf makes use of editfile::config to manage the postfix configuration
define postfix::maincf( $ensure = present ) {
  editfile::config { "main.cf ${name}":
    # require => Package[postfix],
    path    => '/etc/puppet/modules/editfile/doc/examples/postifx-maincf',
    entry   => $name,
    sep     => ' = ',
    ensure  => $ensure,
    # notify  => Service[postfix],
  }
}

postfix::maincf {
  # set the relay host
  'relayhost': ensure => 'outboundrelay.lan';
  # give me the bounces!
  'notify_classes': ensure => '2bounce, resource, software';
  # multiline edits are well supported too
  'smtpd_recipient_restrictions':
    ensure => '
      permit_mynetworks,
      permit_sasl_authenticated,
      reject_unauth_destination,
      reject_rbl_client cbl.abuseat.org,
      reject_rbl_client dnsbl.sorbs.net,
      check_policy_service unix:private/policyd-spf',
    ;
}

# mangle ip addresses
editfile {
  'mangle ips with plain search/replace':
    path   => '/etc/puppet/modules/editfile/doc/examples/ips.txt',
    match  => '10.1.3.23',
    # 'match_is_string' will be removed in a future version; for now it is
    # necessary to set it to 'true if you do hava a search string that uses any
    # characters which hava special meaning in regular expressions
    match_is_string => true,
    ensure => '172.23.3.23',
    ;
  'or with regexp':
    path   => '/etc/puppet/modules/editfile/doc/examples/ips.txt',
    match  => '/10.1.0.([0-9]{1,3})/',
    ensure => '172.16.44.\1',
    ;
}

# insert a line just before another line
editfile {
  'insert before specific line':
    path   => '/etc/puppet/modules/editfile/doc/examples/some_lines.txt',
    # text to insert
    ensure => "i do not understand a word\n",
    # before the other text
    match  => "/(?=^cillum)/",
    exact => true,
    ;
}
