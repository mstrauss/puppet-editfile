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
    
    it 'should recognise a single-line-ensure as such' do
      editfile.send( :line_multiline? ).should be_false
    end

    it 'should detect a missing ensure-line (and declare the resource missing)' do
      editfile.exists?.should be_false
    end
    
    it 'should detect a present ensure-line (and declare the resource present)' do
      input_data "This is the result line.#{$/}"
      editfile.exists?.should be_true
    end
    
    it 'should replace exactly the matching line' do
      input_data "Test-File#{$/}This is the present line.#{$/}"
      apply_ressource :match => :present
      expect_data "Test-File#{$/}This is the result line.#{$/}"
    end
    
    it 'should replace all matching lines' do
      input_data "Line 1#{$/}Line 2#{$/}Line 3#{$/}"
      apply_ressource :match => 'Line', :ensure => 'Result'
      expect_data "Result#{$/}Result#{$/}Result#{$/}"
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

    # it 'should support backreferences' do
    #   input_data "Line 1#{$/}Line 2#{$/}Line 3#{$/}"
    #   apply_ressource :match => '^Line([^$])+$', :ensure => 'X\1'+$/
    #   expect_data "Result 1#{$/}Result 2#{$/}Result 3#{$/}"
    # end
    
    # it 'should append the line if no match is provided and the file does not end with a newline character' do
    #   input_data "Test-File#{$/}This is the present line."
    #   apply_ressource :match => :undef
    #   expect_data [
    #     'Test-File' + $/,
    #     'This is the present line.' + $/,
    #     'This is the result line.',
    #   ]
    # end
    

  end # single line mode
  
  
  describe 'multi-line mode' do
    
    before do
      input_data "Line 1#{$/}Line 2#{$/}Line 3#{$/}"
    end
  
    it 'should recognise a multi-line-ensure as such' do
      editfile( :ensure => "Line 2#{$/}Line 3" ).send( :line_multiline? ).should be_true
    end
    
    it 'should detect a present multi-line-ensure' do
      editfile( :ensure => "Line 2#{$/}Line 3" ).exists?.should be_true
    end
    
    it 'should detect an absent multi-line-ensure' do
      editfile( :ensure => "Line 3#{$/}Line 2").exists?.should be_false
    end
    
  end
    
end

