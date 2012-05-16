require 'spec_helper'
require 'tempfile'

# TO DEBUG: Uncomment next line and place a 'debugger' where needed
# require 'ruby-debug'

def editfile_type
  Puppet::Type.type(:editfile)
end

def regexp_provider
  editfile_type.provider(:regexp)
end

def valid_options
  { :name => 'foo', :path => @tempfile, :ensure => 'This is the result line.', :match => 'bar' }
end

def editfile( options = {} )
  resource = editfile_type.new( valid_options.merge( options ) )
  regexp_provider.new( resource )
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
  if options[:ensure] == :absent
    send_method = 'destroy'
    # editfile( options ).exists?.should be_true
  else
    send_method = 'create'
    editfile( options ).exists?.should be_false
  end
  lambda { editfile( options ).send( send_method ) }.should_not raise_error
end

def apply_ressource_without_match( options = {} )
  options = { :name => 'foo', :path => @tempfile, :ensure => 'This is the result line.' }.merge(options)
  editfile( options ).exists?.should be_false
  lambda { editfile( options ).create }.should_not raise_error
end

def apply_ressource_exists( options = {} )
  editfile( options ).exists?.should be_true
  lambda { editfile( options ).send( :create ) }.should raise_error(Puppet::DevError)
end

def apply_editfile_config( options = {} )
  sep = ' = '
  entry = options[:entry]
  editfile_config_match = "/^(#?\s*#{entry}\s?(?!.*^#{entry})|#{entry}\s?)/m"
  
  value = options[:ensure]
  _ensure = "#{entry}#{sep}#{value}"
  apply_ressource :match => editfile_config_match, :ensure => _ensure

  # remove duplicate lines
  apply_ressource :match => "/^#{entry}#{sep}#{value}(?=.*^#{entry}#{sep})/m", :ensure => :absent
end


describe regexp_provider do
  
  before do
    # generate new tempfile path
    tmp = Tempfile.new('tmp')
    @tempfile = tmp.path
    tmp.close!
  end
  
  describe 'structure' do

    it 'should recognize a regexp match parameter as such (not exact)' do
      regexp = editfile( :match => '/test/i' ).send( :match_regex )
      regexp.is_a?(Regexp).should be_true
      regexp.to_s.should == '(?-mix:^.*(?>(?i-mx:test)).*$)'
    end
    
    it 'should recognize a regexp match parameter as such (exact with slashes)' do
      regexp = editfile( :match => '/test/i', :exact => true ).send( :match_regex )
      regexp.is_a?(Regexp).should be_true
      regexp.to_s.should == '(?i-mx:test)'
    end

    it 'should recognize a multiline regexp match parameter as such (exact)' do
      regexp = editfile( :match => "/bob\nsusan/m", :exact => true ).send( :match_regex )
      regexp.is_a?(Regexp).should be_true
      regexp.to_s.should == "(?m-ix:bob\nsusan)"
    end

    it 'should recognize a regexp match parameter as such (exact with %r{})' do
      regexp = editfile( :match => "%r{/dev/sda}i", :exact => true ).send( :match_regex )
      regexp.is_a?(Regexp).should be_true
      regexp.to_s.should == '(?i-mx:\/dev\\/sda)'
    end

    it 'should recognize a regexp match parameter as such (exact with %r[])' do
      regexp = editfile( :match => "%r[/dev/sda]i", :exact => true ).send( :match_regex )
      regexp.is_a?(Regexp).should be_true
      regexp.to_s.should == '(?i-mx:\/dev\\/sda)'
    end

    it 'should convert a string match parameter to a regexp' do
      regexp = editfile( :match => 'test' ).send( :match_regex )
      regexp.is_a?(Regexp).should be_true
      regexp.to_s.should == '(?-mix:^.*(?>test).*$)'
    end

    it 'should convert a string match parameter to an escaped regexp' do
      regexp = editfile( :match => '.?[]/*{}\\', :match_is_string => true ).send( :match_regex )
      regexp.is_a?(Regexp).should be_true
      regexp.to_s.should == '(?-mix:^.*(?>\.\?\[\]\/\*\{\}\\\\).*$)'
    end

    it 'should abort when a string match looks like a regexp' do
      lambda { editfile( :match => '^.*bla.*\n' ).create }.should raise_error( Puppet::Error )
    end
    
  end
  
  describe 'create' do
    
    it 'should create a non-existing file' do
      apply_ressource
      expect_data "This is the result line.\n"
    end
    
    describe 'when parent directory is missing' do
      it 'should fail' do
        lambda {
          editfile( :path => '/tmp/path/does/not/exist/file' ).send( :create )
        }.should raise_error(Errno::ENOENT, "No such file or directory - /tmp/path/does/not/exist/file")
      end
      
      it 'should not fail when "no_fail_without_parent"=true' do
        lambda {
          editfile( :path => '/tmp/path/does/not/exist/file', :no_fail_without_parent => true ).send( :create )
        }.should_not raise_error
      end
    end
    
    describe 'when match-regexp is found, but ensure-regexp is also found' do
      
      it 'should, by default, declare the resource present' do
        input_data "Line 1#{$/}This is the result line.#{$/}bar#{$/}"
        editfile.exists?.should be_true
      end
    
      it 'should declare the resource absent if _always_ensure_matches_ is true' do
        input_data "Line 1#{$/}This is the result line.#{$/}bar#{$/}"
        editfile( :always_ensure_matches => true ).exists?.should be_false
      end
      
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
    
    describe :no_append => false do
      it 'should append the line if no match is provided' do
        input_data "Test-File#{$/}This is the present line.#{$/}"
        apply_ressource_without_match
        expect_data "Test-File#{$/}This is the present line.#{$/}This is the result line.#{$/}"
      end
    
      it 'should append the line if no match is provided' do
        input_data "Test-File#{$/}This is the present line.#{$/}"
        apply_ressource
        expect_data "Test-File#{$/}This is the present line.#{$/}This is the result line.#{$/}"
      end
    end
    
    describe :no_append => true do
      it 'should not append the line if no match is provided' do
        input_data "Test-File#{$/}This is the present line.#{$/}"
        apply_ressource_without_match( :no_append => true )
        expect_data "Test-File#{$/}This is the present line.#{$/}"
      end
    
      it 'should append the line if no match is provided' do
        input_data "Test-File#{$/}This is the present line.#{$/}"
        apply_ressource( :no_append => true )
        expect_data "Test-File#{$/}This is the present line.#{$/}"
      end
    end
    
    describe 'with backreferences' do
      
      it 'should return false on exist? if we HAVE a match' do
        input_data "Line 1#{$/}Line 2#{$/}Line 3#{$/}"
        options = { :match => '^Line (.*)', :ensure => 'Result \1' }
        editfile( options ).exists?.should be_false
      end
      
      describe 'without "creates"' do
        it 'should return false on exist? if we have NO match (and append the stripped ensure-line)' do
          options = { :match => '/^Line (.*)/', :ensure => 'Result \1' }
          input_data "Result 1#{$/}Result 2#{$/}Result 3#{$/}"
          apply_ressource options
          expect_data "Result 1#{$/}Result 2#{$/}Result 3#{$/}Result #{$/}"
        end
      end
      
      describe 'with "creates"' do
        it 'should return true on exist? if we have a match via "creates"' do
          options = { :match => '/^Line (.*)/', :ensure => 'Result \1', :creates => '/^Result/' }
          input_data "Result 1#{$/}Result 2#{$/}Result 3#{$/}"
          editfile( options ).send( :line_has_backrefs? ).should be_true
          apply_ressource_exists options
          expect_data "Result 1#{$/}Result 2#{$/}Result 3#{$/}"
        end

        it 'should return false on exist? if we have NO match via "creates" (and append the stripped ensure-line)' do
          options = { :match => '/^Line (.*)/', :ensure => 'Result \1', :creates => '/^bla/' }
          input_data "Result 1#{$/}Result 2#{$/}Result 3#{$/}"
          editfile( options ).send( :line_has_backrefs? ).should be_true
          apply_ressource options
          expect_data "Result 1#{$/}Result 2#{$/}Result 3#{$/}Result #{$/}"
        end
      end

      it 'should be supported with exact matching' do
        input_data "Line 1#{$/}Line 2#{$/}Line 3#{$/}"
        apply_ressource :match => '/^Line (.*)\n/', :ensure => "Result \\1\n", :exact => true
        expect_data "Result 1#{$/}Result 2#{$/}Result 3#{$/}"
      end

      it 'should be supported' do
        input_data "Line 1#{$/}Line 2#{$/}Line 3#{$/}"
        apply_ressource :match => '/^Line (.*)/', :ensure => 'Result \1'
        expect_data "Result 1#{$/}Result 2#{$/}Result 3#{$/}"
      end
      
    end

    it 'should detect a present multi-line-ensure' do
      input_data "Line 1#{$/}Line 2#{$/}Line 3#{$/}"
      editfile( :ensure => "Line 2#{$/}Line 3" ).exists?.should be_true
    end
    
    it 'should detect an absent multi-line-ensure' do
      input_data "Line 1#{$/}Line 2#{$/}Line 3#{$/}"
      editfile( :ensure => "Line 3#{$/}Line 2").exists?.should be_false
    end
    
    describe :no_append => false do
      describe 'should append the line if no match is provided' do
        it 'without EOL at EOF' do
          input_data "Test-File#{$/}This is the present line."
          apply_ressource_without_match
          expect_data "Test-File#{$/}This is the present line.#{$/}This is the result line."
        end
        
        it 'with EOL at EOF' do
          input_data "Test-File#{$/}This is the present line.#{$/}"
          apply_ressource_without_match
          expect_data "Test-File#{$/}This is the present line.#{$/}This is the result line.#{$/}"
        end
      end
    end
    
    describe :no_append => true do
      describe 'should append the line if no match is provided' do
        it 'without EOL at EOF' do
          input_data "Test-File#{$/}This is the present line."
          apply_ressource_without_match( :no_append => true )
          expect_data "Test-File#{$/}This is the present line."
        end
        
        it 'with EOL at EOF' do
          input_data "Test-File#{$/}This is the present line.#{$/}"
          apply_ressource_without_match( :no_append => true )
          expect_data "Test-File#{$/}This is the present line.#{$/}"
        end
      end
    end
    
    
    # === real-life (multi-line) examples ===
    
    it 'should handle the varnish example' do
      input_data 'Line 1
Line 2
Line 3
DAEMON_OPTS="-a :80 \
  -T other \
  -f config \
  -S entries"
'
      apply_ressource :match => '/^DAEMON_OPTS\s?=\s?.+(\n\s+.+)*/', :ensure => 'DAEMON_OPTS="-a :80 \
          -T localhost:6082 \
          -f /etc/varnish/default.vcl \
          -S /etc/varnish/secret -s malloc,1G"'
      input_data 'Line 1
Line 2
Line 3
DAEMON_OPTS="-a :80 \
  -T localhost:6082 \
  -f /etc/varnish/default.vcl \
  -S /etc/varnish/secret -s malloc,1G"
'
    end
    
    
    describe 'umask example' do
      
      it 'should handle exact matching well' do
        input_data "\# a comment line#{$/}UMASK\t002#{$/}"
        apply_ressource :match => '/^UMASK.*\n/', :ensure => "UMASK\t022\n", :exact => true
        expect_data "\# a comment line#{$/}UMASK\t022#{$/}"
      end

      it 'should handle default matching well' do
        input_data "\# a comment line#{$/}UMASK\t002#{$/}"
        apply_ressource :match => '/^UMASK/', :ensure => "UMASK\t022"
        expect_data "\# a comment line#{$/}UMASK\t022#{$/}"
      end
      
    end
    
    
    describe 'MatchUser example' do
      regexp = '/^Match User username(\n\s+.+)*/'
      lines = 'Match User username
  ForceCommand internal-sftp
  ChrootDirectory /home/username
  PasswordAuthentication yes' 
      
      it 'should handle the MatchUser present example' do
        input_data '# a sample sshd config
Match User username
  ForceCommand internal-sftp
  ChrootDirectory /home/username
  PasswordAuthentication yes
Match User otheruser
  ForceCommand internal-sftp
  ChrootDirectory /home/otheruser
  PasswordAuthentication yes
# end of example'
        apply_ressource_exists :match => regexp, :ensure => lines
        expect_data '# a sample sshd config
Match User username
  ForceCommand internal-sftp
  ChrootDirectory /home/username
  PasswordAuthentication yes
Match User otheruser
  ForceCommand internal-sftp
  ChrootDirectory /home/otheruser
  PasswordAuthentication yes
# end of example'
      end

      it 'should handle the MatchUser missing example' do
        input_data '# a sample sshd config
Match User otheruser
  ForceCommand internal-sftp
  ChrootDirectory /home/otheruser
  PasswordAuthentication yes
# end of example'
        apply_ressource :match => regexp, :ensure => lines
        expect_data '# a sample sshd config
Match User otheruser
  ForceCommand internal-sftp
  ChrootDirectory /home/otheruser
  PasswordAuthentication yes
# end of example
Match User username
  ForceCommand internal-sftp
  ChrootDirectory /home/username
  PasswordAuthentication yes'
      end

      it 'should handle the MatchUser present but not correct example' do
        input_data '# a sample sshd config
Match User username
  PasswordAuthentication no
Match User otheruser
  ForceCommand internal-sftp
  ChrootDirectory /home/otheruser
  PasswordAuthentication yes
# end of example'
      apply_ressource :match => regexp, :ensure => lines
      expect_data '# a sample sshd config
Match User username
  ForceCommand internal-sftp
  ChrootDirectory /home/username
  PasswordAuthentication yes
Match User otheruser
  ForceCommand internal-sftp
  ChrootDirectory /home/otheruser
  PasswordAuthentication yes
# end of example'
      end
      
    end
    
    
    describe 'SSLHonorCipherOrder example' do
      regexp = '/^(SSLHonorCipherOrder .+\n)?<\/IfModule>/'
      lines = "SSLHonorCipherOrder on\n</IfModule>"

      it 'should handle the SSLHonorCipherOrder missing example' do
        input_data "#SSLStrictSNIVHostCheck On\n</IfModule>\n"
        apply_ressource :match => regexp, :ensure => lines, :exact => false
        expect_data "#SSLStrictSNIVHostCheck On\nSSLHonorCipherOrder on\n</IfModule>\n"
      end

      it 'should handle the SSLHonorCipherOrder present example' do
        input_data "#SSLStrictSNIVHostCheck On\nSSLHonorCipherOrder on\n</IfModule>\n"
        apply_ressource_exists :match => regexp, :ensure => lines, :exact => true
        expect_data "#SSLStrictSNIVHostCheck On\nSSLHonorCipherOrder on\n</IfModule>\n"
      end
      
    end
    
    describe 'lookahead match' do
      
      after do
        apply_ressource :match => '/\n(PARAMETER=123\n)?(?=last line)/', :ensure => "\nPARAMETER=123\n", :exact => true
        expect_data "first line#{$/}PARAMETER=123#{$/}last line"
      end

      it 'should insert before specific line' do
        input_data "first line#{$/}last line"
      end

      it 'should do nothing if already present' do
        input_data "first line#{$/}PARAMETER=123#{$/}last line"
      end

    end
    
    describe 'multiline reordering' do
      
      match = '/(^Match User username.*?)(^\S.*|\Z)/m'
      it 'should put the MatchUser block just before EOF' do
        input_data '# a sample sshd config
Match User username
  ChrootDirectory /home/username
  PasswordAuthentication no
# end of example'
        apply_ressource :exact => true, :match => match, :ensure => '\2
Match User username
  ForceCommand internal-sftp
  ChrootDirectory /home/username
  PasswordAuthentication yes'
        expect_data '# a sample sshd config
# end of example
Match User username
  ForceCommand internal-sftp
  ChrootDirectory /home/username
  PasswordAuthentication yes'
      end

      it 'should put the MatchUser block just before EOF (variant 2)' do
        input_data '# a sample sshd config
Match User username
  ForceCommand internal-sftp
  ChrootDirectory /home/username
  PasswordAuthentication yes'
        apply_ressource :exact => true, :match => match, :ensure => '\2
Match User username
  ForceCommand internal-sftp
  ChrootDirectory /home/username
  PasswordAuthentication yes'
        expect_data '# a sample sshd config

Match User username
  ForceCommand internal-sftp
  ChrootDirectory /home/username
  PasswordAuthentication yes'
      end

      it 'should append the MatchUser block if missing' do
        input_data '# a sample sshd config
Match User wrongusername
  ForceCommand internal-sftp
  ChrootDirectory /home/username
  PasswordAuthentication yes'
        apply_ressource :exact => true, :match => match, :ensure => '\2
Match User username
  ForceCommand internal-sftp
  ChrootDirectory /home/username
  PasswordAuthentication yes'
        expect_data '# a sample sshd config
Match User wrongusername
  ForceCommand internal-sftp
  ChrootDirectory /home/username
  PasswordAuthentication yes

Match User username
  ForceCommand internal-sftp
  ChrootDirectory /home/username
  PasswordAuthentication yes'
      end

    end
    
    describe 'section matching example' do
      
      section = 'section1'
      entry = 'entry'
      value = 'fixed value'

      # # WELL DONE! This one works, but explodes!
      # match_regexp = '/(^\[%s\]\n)((^(?!%s)[^\[].*\n)*)(%s\s+=.+?\n)?/'

      # Fix for the explosion???
      # match_regexp = '/(?>^\[%s\]\n)((?>.*(?=^%s\s*=))?)((?>^%s\s*=.*?\n)?)(?>(.*?)(?=^\[|\Z))/m'
      match_regexp = '/(?>^\[%s\]\n)(?# BLOCK 1:)((?>.*?(?=^%s\b|^\[))?)(?# BLOCK 2:)((?>^%s\b.*?\n)?)(?# BLOCK 3:)(.*?)(?=^\[|\Z)/m'
      
      line_regexp = "[%s]\n\\1%s = %s\n\\3"
      creates_regexp = '/^\[%s\]\n(^[^\[].*\n)*%s = %s$/'
      match = match_regexp % [section, entry, entry]
      line = line_regexp % [section, entry, value]
      creates = creates_regexp % [section, entry, value]
      options = { :match => match, :ensure => line, :creates => creates, :exact => true }
      
      it 'should correctly update the existing value in the existing section' do
        input_data '[section1]
entry = value
[section2]
entry = another value
'
        apply_ressource options
        expect_data '[section1]
entry = fixed value
[section2]
entry = another value
'
      end

      it 'should correctly update the existing value in the existing section (with extra lines)' do
        input_data '[section1]
first entry = first value
entry = value
[section2]
entry = another value
'
        apply_ressource options
        expect_data '[section1]
first entry = first value
entry = fixed value
[section2]
entry = another value
'
      end

      it 'should place a new value in the existing section (on top)' do
        input_data '[section1]
entry2 = value2
[section2]
# wrong section!
entry = fixed value
'
        apply_ressource options
        expect_data '[section1]
entry2 = value2
entry = fixed value
[section2]
# wrong section!
entry = fixed value
'
      end

      it 'should place a new value in the correct section (on bottom)' do
        input_data '[section2]
entry = section2 value
[section1]
entry2 = another value
'
        apply_ressource options
        expect_data '[section2]
entry = section2 value
[section1]
entry = fixed value
entry2 = another value
'
      end

      it 'should not do anything when last line of file is in focus' do
        input_data '[section2]
entry = any other value'
        apply_ressource options
        expect_data '[section2]
entry = any other value
[section1]
entry = fixed value
'
      end

      it 'should create section and value for non-existing section' do
        input_data '[section2]
entry = section2 value
[section3]
entry = section3 value
'
        apply_ressource options
        expect_data '[section2]
entry = section2 value
[section3]
entry = section3 value
[section1]
entry = fixed value

'
      end

      it 'should create file and data for non-existing file' do
        apply_ressource options
        expect_data '[section1]
entry = fixed value

'
      end
      
      it 'should do nothing if all data are there' do
        input_data '[section1]
first entry = first value
entry = fixed value
another entry = bla
[section2]
entry = value'
        apply_ressource_exists options
        expect_data '[section1]
first entry = first value
entry = fixed value
another entry = bla
[section2]
entry = value'
      end


      # --- Real life my.cnf example ---
      describe 'my.cnf idempotency example' do

        before do
          input_data '[isamchk]
read_buffer = 2M
sort_buffer_size = 20M
write_buffer = 2M
key_buffer = 20M
[mysqld]
myisam_sort_buffer_size = 8M
max_allowed_packet = 1M
read_rnd_buffer_size = 512K
read_buffer_size = 256K
sort_buffer_size = 512K
table_cache = 64
net_buffer_length = 8K
key_buffer = 16M
[myisamchk]
read_buffer = 2M
write_buffer = 2M
sort_buffer_size = 20M
key_buffer = 20M
[mysqldump]
max_allowed_packet = 16M'
        end

        it 'should be work with this' do
          section = 'mysqldump'
          entry = 'max_allowed_packet'
          value = '16M'
          match = match_regexp % [section, entry, entry]
          line = line_regexp % [section, entry, value]
          creates = creates_regexp % [section, entry, value]
          options = { :match => match, :ensure => line, :creates => creates, :exact => true }
          apply_ressource_exists options
        end

        it 'should be work with this too' do
          regexp = '/(^\[mysqld\]\n)(.*?)(^key_buffer\s+=.+?\n)?/m'
          line = "[mysqld]\n\\2key_buffer = 16M\n"
          creates = '/^\[mysqld\].*?^key_buffer = 16M(?=.*?(\[.+?\]|\Z))/m'
          options = { :match => regexp, :ensure => line, :creates => creates, :exact => true }
          apply_ressource_exists options
        end

        after do
          expect_data '[isamchk]
read_buffer = 2M
sort_buffer_size = 20M
write_buffer = 2M
key_buffer = 20M
[mysqld]
myisam_sort_buffer_size = 8M
max_allowed_packet = 1M
read_rnd_buffer_size = 512K
read_buffer_size = 256K
sort_buffer_size = 512K
table_cache = 64
net_buffer_length = 8K
key_buffer = 16M
[myisamchk]
read_buffer = 2M
write_buffer = 2M
sort_buffer_size = 20M
key_buffer = 20M
[mysqldump]
max_allowed_packet = 16M'
        end

      end
      
    end



    describe 'editfile::config resource' do
      
      it 'should update an existing entry' do
        input_data "# any comment#{$/}FOO=bar"
        apply_editfile_config :entry => 'FOO', :ensure => 'alice'
        expect_data "# any comment#{$/}FOO = alice"
      end

      it 'should update an existing comment if no other entry is present' do
        input_data "# any comment#{$/}# FOO=bar"
        apply_editfile_config :entry => 'FOO', :ensure => 'alice'
        expect_data "# any comment#{$/}FOO = alice"
      end

      it 'should NOT update an existing comment if another entry IS present' do
        input_data "# any comment#{$/}# FOO=bar#{$/}FOO=bob"
        apply_editfile_config :entry => 'FOO', :ensure => 'alice'
        expect_data "# any comment#{$/}# FOO=bar#{$/}FOO = alice"
      end

      it 'should update the last uncommented line and remove the others (uncommented lines)' do
        input_data "# any comment#{$/}FOO=bar#{$/}# FOO ist commented out#{$/}FOO=bob"
        apply_editfile_config :entry => 'FOO', :ensure => 'alice'
        expect_data "# any comment#{$/}# FOO ist commented out#{$/}FOO = alice"
      end
      
    end
    
    describe 'override with _creates_' do
      it 'should not do anything if creates hits' do
        input_data "Line 1#{$/}This is the result line.#{$/}bar#{$/}"
        editfile( :creates => '/^Line.*?^bar/m').exists?.should be_true
      end

      it 'should apply the ressource if creates misses' do
        input_data "Line 1#{$/}This is the result line.#{$/}bar#{$/}"
        editfile( :creates => '/^Line.*?^barx/m').exists?.should be_false
      end
    end
    
  end # create
  
  
  describe 'destroy' do

    before do
      input_data "Abc 1#{$/}Cde 2#{$/}Efg 3#{$/}"
    end
    
    it 'should remove nothing, using undefined match' do
      lambda { editfile( :ensure => :absent ).destroy }.should_not raise_error
      expect_data "Abc 1#{$/}Cde 2#{$/}Efg 3#{$/}"
    end

    it 'should remove all matching lines, using string' do
      lambda { editfile( :ensure => :absent, :match => 'C' ).destroy }.should_not raise_error
      expect_data "Abc 1#{$/}Efg 3#{$/}"
    end
    
    it 'should remove all matching lines, using regexp with newline (exact)' do
      lambda { editfile( :ensure => :absent, :match => '/^.*c.*#{$/}/i', :exact => true ).destroy }.should_not raise_error
      expect_data "Efg 3#{$/}"
    end
    
    it 'should remove matching characters, using exact regexp' do
      lambda { editfile( :ensure => :absent, :match => '/c/i', :exact => true ).destroy }.should_not raise_error
      expect_data "Ab 1#{$/}de 2#{$/}Efg 3#{$/}"
    end

    it 'should remove all matching lines' do
      lambda { editfile( :ensure => :absent, :match => '/c/i' ).destroy }.should_not raise_error
      expect_data "Efg 3#{$/}"
    end

  end
  
end

