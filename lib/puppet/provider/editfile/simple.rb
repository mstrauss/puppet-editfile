# Puppet Type for editing text files
# (c)2011 Markus Strauss <Markus@ITstrauss.eu>
# License: see LICENSE file

VERBOSE = true
DEBUG = false
puts "Loading provider editfile/editfile." if DEBUG

Puppet::Type.type(:editfile).provide(:simple, :parent => Puppet::Provider) do

  desc "Ensures that a line of text is present (or not) in the given file."

  # # the file must exist, otherwise we refuse to manage it
  # confine :exists => @resource[:path]

  def create
    puts "Creating line #{@resource[:line]}.  Replacing #{match_regex}." if DEBUG
    @data = read_file
    to_replace = []
    @data.each_index do |lineno|
      if @data[lineno] =~ match_regex
        to_replace << lineno
      end
    end
    if to_replace.empty?
      puts 'Nothing found. Creating the entry on the end of the file.' if VERBOSE
      @data << line
    else
      puts "Content found on these lines: #{to_replace.join ','}" if VERBOSE
      to_replace.each do |lineno|
        @data[lineno] = line
      end
    end
    myflush
  end

  def destroy
    puts "Destroying line #{resource[:match]}" if VERBOSE
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
  
  def matches_found?
    puts "Checking existence of regexp '#{resource[:match]}' in file '#{@resource[:path]}':" if VERBOSE
    if File.exists?( @resource[:path] )
      puts "  File exists." if DEBUG
      if read_file.select { |l| l =~ match_regex }.empty?
        puts "  '#{resource[:match]}' NOT found in file" if VERBOSE
        return false
      else
        puts "  '#{resource[:match]}' found in file. Resource exists." if VERBOSE
        return true
      end
    else
      puts "  File does NOT exist." if VERBOSE
      return false
    end
  end
  
  def line_found?
    puts "Checking existence of line '#{line_without_break}' in file '#{@resource[:path]}':" if VERBOSE
    if File.exists?( @resource[:path] )
      puts "  File exists." if DEBUG
      if read_file.select { |l| l == line }.empty?
        puts "  '#{line_without_break}' NOT found in file" if VERBOSE
        return false
      else
        puts "  '#{line_without_break}' found in file. Resource exists." if VERBOSE
        return true
      end
    else
      puts "  File does NOT exist." if VERBOSE
      return false
    end
  end

  private

  def read_file
    puts "Reading file '#{@resource[:path]}'" if DEBUG
    begin
      IO.readlines( @resource[:path] )
    rescue
      # an empty 'file'
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
    puts "Flushing to file #{@resource[:path]}." if DEBUG
    File.open( @resource[:path], "w" ) do |f|
      f.write( @data )
      f.close
    end
  end
end
