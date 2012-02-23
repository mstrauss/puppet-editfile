# Puppet Type for editing text files
# (c)2011 Markus Strauss <Markus@ITstrauss.eu>
# License: see LICENSE file

require 'puppet/error'

Puppet.debug "Editfile::Regexp: Loading provider"

Puppet::Type.type(:editfile).provide(:regexp, :parent => Puppet::Provider) do

  desc 'Ensures that text matching a regular expression is -or is not- present in the given file.  This is mainly a wrapper for String#gsub, applied on the whole file at once.  Backreferences (\1, \2, etc.) and advanced Oniguruma features are therefore supported.'

  def create
    raise( Puppet::DevError, "We have been asked to create this resource, but it is already present." ) if exists?
    @data = read_file_as_string
    if matches_found?
      Puppet.debug "Editfile::Regexp#create: Replacing #{match_regex} with '#{line}'."
      @data.gsub!( match_regex, line )
    else
      # no match found ==> append at end of file
      Puppet.debug "Editfile::Regexp#create: Appending '#{line( :remove_break => true, :with_backrefs => false )}'"
      if @data[-1,1] == $/
        # newline at the end, proceed as usual
        @data << line( :append_break => true, :with_backrefs => false )
      else
        # no newline, we keep that state:
        @data << $/ << line( :remove_break => true, :with_backrefs => false )
      end
    end
    myflush
  end

  def destroy
    throw_on_missing_match       
    Puppet.debug "Editfile::Regexp#destroy: Destroying line '#{resource[:match]}', #{match_regex}"
    @data = read_file_as_string
    @data.gsub!( match_with_eol_regex, '' )
    myflush
  end

  def exists?
    Puppet.debug "Editfile::Regexp#exists?: We have been asked if #{@resource[:name]} exists."    
    if @resource[:ensure] == :absent
      # the resource exists -meaning, there are data to be purged- if matches are found
      status = matches_found?
    else
      if @resource[:always_ensure_matches].is_a?(TrueClass)
        # the resource does NOT exist, if matches are found OR the ensure-line is not present
        status = !( matches_found? or !line_found? )
      else
        # the resource does exist, if the ensure-regexp is present
        status = line_found?
      end
    end
    Puppet.debug "Editfile::Regexp#exists?: Answer is #{status or false}."
    status or false     # we wanna have an explicit Boolean here (for debug output)
  end
  
  
  private
  
  # this is the default provider for the editfile type
  def self.default?
    true
  end
  
  def matches_found?( regexp = match_regex )
    Puppet.debug "Editfile::Regexp#matches_found?: Checking for '#{regexp.to_s}' in file '#{@resource[:path]}'."
    if File.exists?( @resource[:path] )
      Puppet.debug "Editfile::Regexp#matches_found?: File exists."
      status = ( read_file_as_string =~ regexp )
      Puppet.debug( "Editfile::Regexp#matches_found?: " + ( status ? "Match found at position: #{status}" : "No match found." ) )
      return status
    else
      Puppet.debug "Editfile::Regexp#matches_found?: File does NOT exist."
      return false
    end
  end
  
  def line_found?
    if m = @resource[:creates]
      begin
        m = eval(m)
      rescue
        raise Puppet::Error, 'Unable to compile regular expression.'
      end
      matches_found?( m )
    else
      escaped_line = Regexp.escape( line_without_break )
      matches_found?( /^#{escaped_line}$/ )
    end
  end

  def read_file_as_string
    Puppet.debug "Editfile::Regexp#read_file_as_string: Reading file '#{@resource[:path]}'"
    begin
      IO.read( @resource[:path] )
    rescue Errno::ENOENT
      # an empty 'file'
      Puppet.debug "Editfile::Regexp#read_file_as_string: File does NOT exist."
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
      
  end
  
  # this is needed for deletions, when we wanna replace the whole line with an empty string;
  # only applies to non-exact operations
  def match_with_eol_regex
    return match_regex if resource[:exact]
    return /^(?>#{match_regex})#{$/}/
  end
  
  def line( options = {} )
    default_options = { :remove_break => false, :append_break => false, :with_backrefs => true }
    options = default_options.merge!( options )
    result = @resource[:line].clone   # we need a copy so not to modify the original @resource[:line]
    result.chomp! if options[:remove_break] or options[:append_break] or @resource[:exact] != true
    result << $/ if options[:append_break]
    result.gsub!(/\\[0-9]+/,'') unless options[:with_backrefs]
    result
  end
  
  def line_without_break
    line( :remove_break => true )
  end

  def line_with_break
    line( :append_break => true )
  end
    
  def myflush
    Puppet.debug "Editfile::Regexp#myflush: Flushing to file #{@resource[:path]}."
    File.open( @resource[:path], "w" ) do |f|
      f.write( @data )
      f.close
    end
  end
end
