# Puppet Type for editing text files
# (c)2011 Markus Strauss
# License: GPLv3


Puppet::Type.newtype(:editfile) do

  @doc = "Ensures that a line of text is present (or not) in the given file."

  ensurable do
    
    defaultto :present
    
    newvalue(:present) do
      provider.create
    end
    
    newvalue(:absent) do
      provider.destroy
    end
  end

  newparam( :name ) do
    desc "any unique name"
    isnamevar
  end

  newparam(:path) do
    desc "The path to the file to edit.  Must be fully qualified."    
  end

  newparam(:line) do
    desc "A whole line of text you want to have in the file."
    
    validate do |line|
      unless line.instance_of?( String ); raise ArgumentError, "'line' must be a string"; end
    end
  end

  newparam(:replace) do

    desc "An optional text which should be removed from the file. It it is a
      string all substring-matching lines are removed, if it is a regular
      expression, all matching lines are removed."

  end

  validate do
    self.fail "You need to specify a file path" unless @parameters.include?(:path)
    self.fail "You need to specify a line you wanna see in the file" unless @parameters.include?(:line)
  end

end
