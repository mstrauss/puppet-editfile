require 'spec_helper'
require 'tempfile'

def editfile_type
  Puppet::Type.type(:editfile)
end

def simple_provider
  editfile_type.provider(:simple)
end

def valid_options
  { :name => 'foo', :path => @tempfile, :ensure => 'This is the result line.' }
end

def editfile( options = {} )
  resource = editfile_type.new( valid_options.merge( options ) )
  simple_provider.new( resource )
end

def input_data( string )
  # set up example data
  File.open(@tempfile, 'w') do |f|
    f.write( string )
  end
end

def expect_data( string )
  IO.readlines(@tempfile, nil).first.should == string
end

def apply_ressource( options = {} )
  proc { editfile( options ).create }.should_not raise_error
end


describe simple_provider do
  
  before do
    # generate new tempfile path
    tmp = Tempfile.new('tmp')
    @tempfile = tmp.path
    tmp.close!
  end
  
  describe 'single line mode' do
    
    it 'should detect the missing ensure-line (and declare the resource missing)' do
      editfile.exists?.should be_false
    end
    
    it 'should replace exactly the matching line' do
      input_data "Test-File#{$/}This is the present line.#{$/}"
      apply_ressource :match => :present
      expect_data "Test-File#{$/}This is the result line.#{$/}"
    end

    it 'should append the line if no match is provided' do
      input_data "Test-File#{$/}This is the present line.#{$/}"
      apply_ressource :match => :undef
      expect_data "Test-File#{$/}This is the present line.#{$/}This is the result line.#{$/}"
    end
    
    it 'should append the line if no match is provided' do
      input_data "Test-File#{$/}This is the present line.#{$/}"
      apply_ressource
      expect_data "Test-File#{$/}This is the present line.#{$/}This is the result line.#{$/}"
    end

    
    # it 'should append the line if no match is provided and the file does not end with a newline character' do
    #   input_data "Test-File#{$/}This is the present line."
    #   apply_ressource :match => :undef
    #   expect_data [
    #     'Test-File' + $/,
    #     'This is the present line.' + $/,
    #     'This is the result line.',
    #   ]
    # end
    

  end
  
end

