# Puppet Type for editing text files
# (c)2011 Markus Strauss <Markus@ITstrauss.eu>
# License: see LICENSE file

require 'puppet/error'

Puppet.debug "Editfile::Simple: Loading provider"

Puppet::Type.type(:editfile).provide(:simple, :parent => Puppet::Provider) do

  desc 'Ensures that text matching a regular expression is -or is not- present in the given file.  This is mainly a wrapper for String#gsub, applied on the whole file at once.  Backreferences (\1, \2, etc.) and advanced Oniguruma features are therefore supported.'

  def create
    Puppet.debug "Editfile::Simple: Creating line '#{@resource[:line]}'.  Replacing #{match_regex}."
    @data = read_file_as_string
    if matches_found?
      @data.gsub!( match_regex, line )
    else
      # no match found ==> append at end of file
      Puppet.debug "Appending '#{line}'"
      if @data[-1,1] == $/
        # newline at the end, proceed as usual
        @data << line_with_break
      else
        # no newline, we keep that state:
        @data << $/ << line_without_break
      end
    end
    myflush
  end

  def destroy
    throw_on_missing_match       
    Puppet.debug "Editfile::Simple: Destroying line '#{resource[:match]}', #{match_regex}"
    @data = read_file_as_string
    @data.gsub!( match_with_eol_regex, '' )
    myflush
  end

  def exists?
    if @resource[:ensure] == :absent
      # the resource exists -meaning, there are data to be purged- if matches are found
      matches_found?
    else
      # the resource does NOT exist, if matches are found OR the ensure-line is not present
      not ( matches_found? or !line_found? )
    end
  end
  
  private
  
  # this is the default provider for the editfile type
  def self.default?
    true
  end
  
  def matches_found?( regexp = match_regex )
    Puppet.debug "Editfile::Simple: Checking existence of regexp '#{regexp.to_s}' in file '#{@resource[:path]}':"
    if File.exists?( @resource[:path] )
      Puppet.debug "Editfile::Simple: File exists."
      status = ( read_file_as_string =~ regexp )
      Puppet.debug "Match found at position: #{status}"
      return status
    else
      Puppet.debug "Editfile::Simple: File does NOT exist."
      return false
    end
  end
  
  def line_found?
    escaped_line = Regexp.escape( line_without_break )
    matches_found?( /^#{escaped_line}$/ )
  end

  def read_file_as_string
    Puppet.debug "Editfile::Simple: Reading file '#{@resource[:path]}'"
    begin
      IO.read( @resource[:path] )
    rescue Errno::ENOENT
      # an empty 'file'
      Puppet.debug "Editfile::Simple: File does NOT exist."
      ''
    end
  end
  
  def throw_on_missing_match
    throw Puppet::Error.new( 'If you wanna replace/delete the whole file, do not use Editfile, use other means. Aborting.' ) if  @resource[:match].nil? or @resource[:match] == ''
  end
  
  def match_regex
    # match.nil_or_empty? should be prohibited by the type
    throw_on_missing_match
    return @match_regex if @match_regex
    m = @resource[:match]
    if m.is_a? Symbol
      if m == :undef
        m = line_without_break
      else
        m = m.to_s
      end
    end
    
    # first character slash ==> we eval it
    begin
      m = eval(m) if m =~ %r{/.*/}
    rescue
      throw Puppet::Error.new( 'Unable to compile regular expression.')
    end
    
    unless @resource[:exact]
      # mangle regexp for line-matching - we anchor at EOL (and EOF) but do not include
      # these in the match
      @match_regex = /^.*(?>#{m}).*$/
    else
      @match_regex = Regexp.new( m )
    end
      
    # # abort on regexp strings ==> these should be regexps instead
    # if m.is_a? String
    #   if [ '[', ']', '.*', '.+', '^', '$' ].any? { |test| m.include? test }
    #     raise Puppet::Error.new 'This looks like a Regexp.  Please modify your manifest to use a Regexp instead of a String.  Regexp strings are no longer supported.'
    #   end
    #   escaped_match = Regexp.quote( m.chomp )
    #   @match_regex = /^.*#{escaped_match}.*\n/
    # else
    #   # @resource[:match] is then a Regexp hopefully
    #   @match_regex = m
    # end
  end
  
  # this is needed for deletions, when we wanna replace the whole line with an empty string;
  # only applies to non-exact operations
  def match_with_eol_regex
    return match_regex if resource[:exact]
    return /^(?>#{match_regex})#{$/}/
  end
  
  def line_without_break
    @resource[:line].chomp || ''
  end

  def line_with_break
    line_without_break + $/
  end
  
  def line
    if @resource[:exact]
      @resource[:line]
    else
      line_without_break
    end
  end
  
  def myflush
    Puppet.debug "Editfile::Simple: Flushing to file #{@resource[:path]}."
    File.open( @resource[:path], "w" ) do |f|
      f.write( @data )
      f.close
    end
  end
end
