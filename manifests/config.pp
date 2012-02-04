define editfile::config( $path, $entry = false, $ensure, $sep = '=', $quote = false ) {

  if $entry == false {
    
    file_line { $name:
      path => $path,
      line => $ensure,
    }
    
  } else {

    if $quote == true {
      $_ensure = "${entry}${sep}\"${ensure}\""
    } else {
      $_ensure = "${entry}${sep}${ensure}"
    }

    editfile { $title:
      path   => $path,
      match  => "^#?\s*${entry}\s?",
      ensure => $ensure ? {
        absent  => $ensure,
        default => $_ensure,
      },
    }

  }
  
}
