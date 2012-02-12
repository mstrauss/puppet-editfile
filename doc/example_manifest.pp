editfile {
  'fix umask':
    path   => '/etc/login.defs.example',
    match  => '^UMASK.*\n',
    ensure => "UMASK\t022",
    exact => true,
    ;
  'fix parameter name':
    path   => '/my/file/path',
    match  => '^WRONG PARAMETER NAME=(.*)',
    ensure => 'RIGHT PARAMETER NAME=\1',
    ;
  'sshd_config, enforce matchuser block':
    path   => '/etc/ssh/sshd_config',
    match  => "^Match User username(\n\s+.+)*",
    ensure => "Match User username
      ForceCommand internal-sftp
      ChrootDirectory /home/username
      PasswordAuthentication yes",
    ;
  # 'insert before specific line':
  #   path   => '/my/file/path',
  #   match  => '(?=^insert before this line$)',
  #   ensure => 'INSERTED BEFORE LAST LINE', :exact => true
  #   match => '(?=^last line$)', :ensure => 'INSERTED BEFORE LAST LINE', :exact => true
}

