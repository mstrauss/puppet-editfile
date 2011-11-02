# Puppet Type for editing text files
# (c)2011 Markus Strauss
# License: see LICENSE file


Puppet::Type.newtype(:editfile) do

  @doc = "Ensures that a line of text is present (or not) in the given file."

  ensurable do
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
      value,resource[:line] = :present,value unless value.is_a? Symbol
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
    desc "The path to the file to edit.  Must be fully qualified."    
  end

  newparam(:match) do
    desc "The text which should be handled by editfile. Provide a regular
    expression."
  end

  validate do
    self.fail "You need to specify a file path" unless @parameters.include?(:path)
    self.fail "You need to specify what to 'ensure'" unless self[:ensure]
  end

end
