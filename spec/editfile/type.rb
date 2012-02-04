require 'spec_helper'

# require 'ruby-debug/debugger'

editfile = Puppet::Type.type(:editfile)
valid_options = { :name => 'foo', :path => '/tmp/path', :ensure => 'bar' }

describe editfile do

  before do
    @editfile = editfile.new( valid_options )
  end

  it 'should have a default provider inheriting from Puppet::Provider' do
    editfile.defaultprovider.ancestors.should be_include(Puppet::Provider)
  end
  
  it 'should have a valid provider' do
    @editfile.provider.class.ancestors.should be_include(Puppet::Provider)
  end
  
  it "should have :name be its namevar" do
    editfile.key_attributes.should == [:name]
  end
  
  describe 'basic structure' do
    properties = [:ensure]
    params = [:name, :provider, :path, :match]

    properties.each do |property|
      it "should have a #{property} property" do
        editfile.attrtype(property).should == :property
        editfile.attrclass(property).ancestors.should be_include(Puppet::Property)
      end

      it "should have documentation for its #{property} property" do
        editfile.attrclass(property).doc.should be_instance_of(String)
      end
    end

    params.each do |param|
      it "should have a #{param} parameter" do
        editfile.attrtype(param).should == :param
        editfile.attrclass(param).ancestors.should be_include(Puppet::Parameter)
      end

      it "should have documentation for its #{param} parameter" do
        editfile.attrclass(param).doc.should be_instance_of(String)
      end
    end
  end

  describe "when validating values" do
    it "should support present as a value for ensure" do
      proc { editfile.new( valid_options.merge( :ensure => :present ) ) }.should_not raise_error
    end

    it "should support absent as a value for ensure" do
      proc { editfile.new( valid_options.merge( :ensure => :absent ) ) }.should_not raise_error
    end

    # it "should not accept spaces in resourcename" do
    #   proc { editfile.new( valid_options.merge( :name => "foo bar") ) }.should raise_error
    # end
    
    # it 'should not accept an empty path' do
    #   proc { editfile.new( valid_options.merge( :path => '' ) ) }.should raise_error
    # end
    
    # it 'should not accept unqualified path' do
    #   expect { @editfile[:path] = 'file' }.should raise_error(Puppet::Error, /File paths must be fully qualified/)
    # end
    
  end
  
  describe 'when munging values' do
    it 'should set ensure to :present when ensure is a string' do
      editfile.new( valid_options.merge( :ensure => 'a text' ) )[:ensure].should == :present
    end

    it 'should set match to :undef when match is empty' do
      editfile.new( valid_options.merge( {} ) )[:match].should == :undef
    end
  end
  
  
  it 'should create a non-existing file' do
    resource = Puppet::Type.type(:editfile).new(
      :name  => 'arbitrary_title',
      :path   => "/tmp/testfile",
      :ensure => 'absent',
      :provider => 'simple' )
      # :line => 'The file should be created with this content.' )
    catalog = Puppet::Resource::Catalog.new
    catalog.add_resource( resource )
    
    # debugger
    
    transaction = Puppet::Transaction.new( catalog )
    resource_status = transaction.resource_harness.evaluate( resource )
    # puts "Resource error: " + resource_status.events.first.message if resource_status.failed
    # puts resource_status.inspect
    resource_status.should_not be_failed
  end
  
end