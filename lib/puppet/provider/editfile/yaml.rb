# Puppet Type for editing text files
# (c)2011 Markus Strauss <Markus@ITstrauss.eu>
# License: see LICENSE file

Puppet.debug "Editfile::Yaml: Loading provider"

require 'hashie'

Puppet::Type.type(:editfile).provide(:yaml, :parent => Puppet::Provider) do

  desc "Editing YAML files.
  Usage: 
    editfile { 'add/replace in a yaml file':
      provider => yaml,
      path     => 'my.yaml',
      match    => 'key.subkey',
      ensure   => { subsubkey1 => value1, subsubkey2 => { subhashkey => subhashvalue } },
    }
  Generates:
  --- 
    key.subkey: 
      subsubkey1: value1
      subsubkey2: 
        subhashkey: subhashvalue
  "

  # # the file must exist, otherwise we refuse to manage it
  # confine :exists => @resource[:path]

  def create
    Puppet.debug "Editfile::Yaml: Creating hash #{pretty_value} on key #{pretty_key}."
    eval( "read_file.#{key} = #{pretty_value}")
    myflush
  end

  def destroy
    Puppet.debug "Editfile::Yaml: Destroying key #{pretty_key}."
    read_file[ @resource[:match] ] = nil
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
  
  def matches_found?
    check_file and key_exists
  end
  
  def key_exists
    key_exist = begin
      !eval("read_file.#{key}").nil?
    rescue
      false
    end
    Puppet.debug "Editfile::Yaml: Key #{@resource[:match]} exists? #{key_exist}"
    key_exist
  end
  
  def value_exists
    value_exists = ( eval("read_file.#{key}") == value )
    Puppet.debug "Editfile::Yaml: Value #{pretty_value} exists on key #{@resource[:match]}? #{value_exists}"
    value_exists
  end

  def line_found?
    matches_found? and value_exists
  end
  
  def check_file
    file_here = File.exists?( @resource[:path] )
    Puppet.debug "Editfile::Yaml: File #{@resource[:path]} exists? #{file_here}"
    file_here
  end
  
  def value
    # @value ||= Hashie::Mash.new( @resource[:line] )
    @resource[:line]
  end
  
  def pretty_value
    value.inspect
  end
  
  def key
    # @key ||= Hashie::Mash.new( @resource[:match] )
    @resource[:match]
  end
  
  def pretty_key
    key.inspect
  end
  
  def read_file
    return @data if @data
    Puppet.debug "Editfile::Yaml: Reading file '#{@resource[:path]}'"
    begin
      @data = Hashie::Mash.new( YAML.load_file( @resource[:path] ) )
    rescue
      Puppet.debug "Editfile::Yaml: File does NOT exist. Starting with an empty hash."
      @data = Hashie::Mash.new
    end
  end

  def myflush
    Puppet.debug "Editfile::Yaml: Flushing to file #{@resource[:path]}."
    File.open( @resource[:path], "w" ) do |f|
      f.write( @data.to_yaml )
      f.close
    end
  end
end
