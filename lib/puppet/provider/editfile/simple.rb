# Puppet Type for editing text files
# (c)2011 Markus Strauss <Markus@ITstrauss.eu>
# License: GPLv3

VERBOSE = true
DEBUG = false
puts "Loading provider editfile/editfile." if DEBUG

Puppet::Type.type(:editfile).provide(:simple, :parent => Puppet::Provider) do

  desc "Ensures that a line of text is present (or not) in the given file."

  # # the file must exist, otherwise we refuse to manage it
  # confine :exists => @resource[:path]

  def create
    replace_regex
    puts "Creating line #{@resource[:line]}.  Replacing #{replace_regex}." if DEBUG
    @data = read_file
    to_replace = []
    @data.each_index do |lineno|
      if @data[lineno] =~ replace_regex
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
    puts "Destroying line #{resource[:line]}" if VERBOSE
    @data = read_file
    @data = @data.select { |l| not l == line }
    myflush
  end

  def exists?
    puts "Checking existence of line '#{resource[:line]}' in file '#{@resource[:path]}':" if VERBOSE
    if File.exists?( @resource[:path] )
      puts "  File exists. Line #{line} exits?" if DEBUG
      if read_file.select { |l| l == line }.empty?
        puts "  '#{resource[:line]}' NOT found in file" if VERBOSE
        return false
      else
        puts "  '#{resource[:line]}' found in file. Resource exists." if VERBOSE
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
  
  def replace_regex
    @replace_regex ||= Regexp.new(@resource[:replace])
  end
  
  def line
    @line ||= ( @resource[:line] + $/ )
  end
  
  def myflush
    puts "Flushing to file #{@resource[:path]}." if DEBUG
    File.open( @resource[:path], "w" ) do |f|
      f.write( @data )
      f.close
    end
  end
end
