define editfile::config( $path, $entry, $ensure, $sep = '=', $quote = true ) {

  if $quote == true {
    $_ensure = "${entry}${sep}\"${ensure}\""
  } else {
    $_ensure = "${entry}${sep}${ensure}"
  }
  
  editfile { $title:
    path    => $path,
    match  => "^#?\s*${entry}\s?${sep}",
    ensure => $ensure ? {
      absent  => $ensure,
      default => $_ensure,
    },
  }
  
}
