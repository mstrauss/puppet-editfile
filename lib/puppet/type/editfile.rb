# Puppet Type for editing text files
# (c)2011 Markus Strauss
# License: see LICENSE file


Puppet::Type.newtype(:editfile) do

  @doc = 'Performs regular expression edits on files.  By default (exact => false), all lines matching the regular expression given in the _match_ parameter will be replaced with the text given in the _ensure_ parameter.  To remove all lines matching the regular expression given in the _match_ parameter, set ensure => absent.'

  ensurable do
    
    desc 'When exact => false (the default):  Specify a replacement text for matching lines or _absent_ to remove all matching lines.  Backreferences are allowed (see example manifest).'
    nodefault
    
    newvalue(:absent) do
      @resource[:line] = ''
      provider.destroy
    end
    
    aliasvalue(:false, :absent)
    
    newvalue(/./) do
      provider.create
    end
    
    munge do |value|
      value = super(value)
      value, resource[:line] = :present, value unless value.is_a? Symbol
      value
    end
  end
  
  newparam( :line ) do
    desc "This is kind of a 'private' parameter. Do not use!"
  end
  
  newparam( :name ) do
    desc "any unique name"
    isnamevar
  end
  
  newparam(:path) do
    desc "The path to the file to edit.  Must be absolute."
  end

  newparam(:match) do
    desc "The text which should be handled by editfile.  Provide a regular expression."
  end
  
  newparam(:match_is_string) do
    desc "Set to 'true' if 'match' is a string."
  end
  
  newparam(:exact) do
    desc 'Shall we use exact matching? Exact matching means that all exact matches of the regular expression given through _match_ will be replaced with the text given in _ensure_ (using Ruby\'s String#gsub method).  Otherwise, _ensure_ will apply to whole file lines. See the example manifest for details.  Default value: false.'    
  end
  
  newparam(:always_ensure_matches) do
    desc 'The default behaviour of editfile is to do nothing when the ensure-regexp is already present in the file.  Set this to _true_ do have editfile run, even if the ensure-regexp _is_ found.'
  end
  
  newparam(:creates) do
    desc 'A regular expression which, when absent, causes the resource to apply.  This defaults to _ensure_.  Override to specify what will be created by the resource e.g. when you use backreferences in _ensure_.'
  end
  
  newparam(:no_fail_without_parent) do
    desc 'Set to "true" to ignore failures because of missing parent directories. Note: The usual behavior would be to bring an error if the parent directory does not exist.'
  end
  
  newparam(:no_append) do
    desc 'Set to "true" to not append anything to the end of file.'
  end

  validate do
    self[:match] = :undef if self[:match].nil? or self[:match] == ''
    self.fail "You need to specify a file path" unless @parameters.include?(:path)
    self.fail "You need to specify what to 'ensure'" unless self[:ensure]
    self[:exact] = false if self[:exact].nil?
    self.fail "'exact' needs to be 'true' or 'false'" unless [true, false].include?(self[:exact])
  end

end
