# editfile::config
#
# This resource is an example of what you can do with editfile.
# editfile::config manages simple configuration files which follow the scheme
# PARAMETER = VALUE
# A special feature is, that existing entries which are deactived with the pound sign, are reused.
# E.g. >># PARAMETER = DEFAULT VALUE<< will we reused, but ONLY if there is no other line like >>PARAMETER = ANYTHING<<.
#
# @param[String]  $title  : any unique resource name
# @param[String]  $path   : the file path
# @param[String]  $entry  : which configuration entry to set
# @param[String]  $ensure : set the configuration entry to this value, or use 'absent' to remove the entry $entry
# @param[String]  $sep    : the separator to use, e.g. set to ' = '
# @param[Boolean] $quote  : shall the value be quoted, like >> ENTRY = "value" <<
define editfile::config( $path, $entry = false, $ensure, $sep = '=', $quote = false, $no_fail_without_parent = false ) {

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
    
    Editfile {
      path   => $path,
    }

    if $ensure == absent {
      editfile { "$title":
        # we remove all matching entries, but not the comment lines
        match  => "/^${entry}${sep}/",
        ensure => absent,
      }
    } else {
      
      editfile { "${title}":
        # either match the with leading pound sign AND no other entry without pound - to replace the deactivated entry
        # OR
        # match simply without the pound sign - to replace an active entry
        # OR
        # if there is no match, editfile automatically appends our entry at EOF
        match  => "/^(#?\s*${entry}\s?(?!.*^${entry})|${entry}\s?)/m",
        ensure => $_ensure,
        no_fail_without_parent => $no_fail_without_parent,
      }
      
    }

  }
  
}
