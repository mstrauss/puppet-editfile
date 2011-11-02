# Puppet Type for editing text files
# (c)2011 Markus Strauss <Markus@ITstrauss.eu>
# License: see LICENSE file

Puppet.debug "Editfile::Simple: Loading provider"

Puppet::Type.type(:editfile).provide(:simple, :parent => Puppet::Provider) do

  desc "Ensures that a line of text is present (or not) in the given file."

  # # the file must exist, otherwise we refuse to manage it
  # confine :exists => @resource[:path]

  def create
    Puppet.debug "Editfile::Simple: Creating line #{@resource[:line]}.  Replacing #{match_regex}."
    @data = read_file
    to_replace = []
    @data.each_index do |lineno|
      if @data[lineno] =~ match_regex
        to_replace << lineno
      end
    end
    if to_replace.empty?
      Puppet.debug 'Editfile::Simple: Nothing found. Creating the entry on the end of the file.'
      @data << line
    else
      Puppet.debug "Editfile::Simple: Content found on these lines: #{to_replace.join ','}"
      to_replace.each do |lineno|
        @data[lineno] = line
      end
    end
    myflush
  end

  def destroy
    Puppet.debug "Editfile::Simple: Destroying line #{resource[:match]}"
    @data = read_file
    @data = @data.select { |l| not l =~ match_regex }
    myflush
  end

  def exists?
    if @resource[:ensure] == :absent
      matches_found?
    else
      line_found?
    end
  end
  
  private
  
  # this is the default provider for the editfile type
  def self.default?
    true
  end
  
  def matches_found?
    Puppet.debug "Editfile::Simple: Checking existence of regexp '#{resource[:match]}' in file '#{@resource[:path]}':"
    if File.exists?( @resource[:path] )
      Puppet.debug "Editfile::Simple: File exists."
      if read_file.select { |l| l =~ match_regex }.empty?
        Puppet.debug "Editfile::Simple: '#{resource[:match]}' NOT found in file"
        return false
      else
        Puppet.debug "Editfile::Simple: '#{resource[:match]}' found in file. Resource exists."
        return true
      end
    else
      Puppet.debug "Editfile::Simple: File does NOT exist."
      return false
    end
  end
  
  def line_found?
    Puppet.debug "Editfile::Simple: Checking existence of line '#{line_without_break}' in file '#{@resource[:path]}':"
    if File.exists?( @resource[:path] )
      Puppet.debug "Editfile::Simple: File exists."
      if read_file.select { |l| l == line }.empty?
        Puppet.debug "Editfile::Simple: '#{line_without_break}' NOT found in file"
        return false
      else
        Puppet.debug "Editfile::Simple: '#{line_without_break}' found in file. Resource exists."
        return true
      end
    else
      Puppet.debug "Editfile::Simple: File does NOT exist."
      return false
    end
  end

  def read_file
    Puppet.debug "Editfile::Simple: Reading file '#{@resource[:path]}'"
    begin
      IO.readlines( @resource[:path] )
    rescue
      # an empty 'file'
      Puppet.debug "Editfile::Simple: File does NOT exist."
      ['']
    end
  end
  
  def match_regex
    @match_regex ||= Regexp.new(@resource[:match])
  end
  
  def line_without_break
    if [:present, :absent].include? @resource[:ensure]
      _line = @resource[:line] || ''
    else
      _line = @resource[:ensure]
    end
  end

  def line
    line_without_break + $/
  end
  
  def myflush
    Puppet.debug "Editfile::Simple: Flushing to file #{@resource[:path]}."
    File.open( @resource[:path], "w" ) do |f|
      f.write( @data )
      f.close
    end
  end
end
