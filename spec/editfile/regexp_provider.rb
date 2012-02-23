require 'spec_helper'
require 'tempfile'

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
  else
    send_method = 'create'
  end
  proc { editfile( options ).send( send_method ) }.should_not raise_error
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

    it 'should recognize a regexp match parameter as such' do
      regexp = editfile( :match => '/test/i' ).send( :match_regex )
      regexp.is_a?(Regexp).should be_true
      regexp.to_s.should == '(?-mix:^.*(?>(?i-mx:test)).*$)'
    end
    
    it 'should convert a string match parameter to a regexp' do
      regexp = editfile( :match => 'test' ).send( :match_regex )
      regexp.is_a?(Regexp).should be_true
      regexp.to_s.should == '(?-mix:^.*(?>test).*$)'
    end

    # it 'should abort when a string match looks like a regexp' do
    #   proc { editfile( :match => '^.*bla.*\n' ).create }.should raise_error( Puppet::Error )
    # end
    
  end
  
  describe 'create' do
    
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

    it 'should support backreferences (exact matching)' do
      input_data "Line 1#{$/}Line 2#{$/}Line 3#{$/}"
      apply_ressource :match => '^Line (.*)\n', :ensure => "Result \\1\n", :exact => true
      expect_data "Result 1#{$/}Result 2#{$/}Result 3#{$/}"
    end

    it 'should support backreferences' do
      input_data "Line 1#{$/}Line 2#{$/}Line 3#{$/}"
      apply_ressource :match => '^Line (.*)', :ensure => 'Result \1'
      expect_data "Result 1#{$/}Result 2#{$/}Result 3#{$/}"
    end
    
    it 'should detect a present multi-line-ensure' do
      input_data "Line 1#{$/}Line 2#{$/}Line 3#{$/}"
      editfile( :ensure => "Line 2#{$/}Line 3" ).exists?.should be_true
    end
    
    it 'should detect an absent multi-line-ensure' do
      input_data "Line 1#{$/}Line 2#{$/}Line 3#{$/}"
      editfile( :ensure => "Line 3#{$/}Line 2").exists?.should be_false
    end

    describe 'should append the line if no match is provided' do
      it 'without EOL at EOF' do
        input_data "Test-File#{$/}This is the present line."
        apply_ressource :match => :undef
        expect_data "Test-File#{$/}This is the present line.#{$/}This is the result line."
      end

      it 'with EOL at EOF' do
        input_data "Test-File#{$/}This is the present line.#{$/}"
        apply_ressource :match => :undef
        expect_data "Test-File#{$/}This is the present line.#{$/}This is the result line.#{$/}"
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
      apply_ressource :match => '^DAEMON_OPTS\s?=\s?.+(\n\s+.+)*', :ensure => 'DAEMON_OPTS="-a :80 \
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
    
    it 'should handle the umask example well (exact matching)' do
      input_data "\# a comment line#{$/}UMASK\t002#{$/}"
      apply_ressource :match => '^UMASK.*\n', :ensure => "UMASK\t022\n", :exact => true
      expect_data "\# a comment line#{$/}UMASK\t022#{$/}"
    end

    it 'should handle the umask example well' do
      input_data "\# a comment line#{$/}UMASK\t002#{$/}"
      apply_ressource :match => '^UMASK', :ensure => "UMASK\t022"
      expect_data "\# a comment line#{$/}UMASK\t022#{$/}"
    end
    
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
      apply_ressource :match => '^Match User username(\n\s+.+)*', :ensure => 'Match User username
  ForceCommand internal-sftp
  ChrootDirectory /home/username
  PasswordAuthentication yes'
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
      apply_ressource :match => '^Match User username(\n\s+.+)*', :ensure => 'Match User username
  ForceCommand internal-sftp
  ChrootDirectory /home/username
  PasswordAuthentication yes'
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
      apply_ressource :match => '^Match User username(\n\s+.+)*', :ensure => 'Match User username
  ForceCommand internal-sftp
  ChrootDirectory /home/username
  PasswordAuthentication yes'
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
    
    it 'should handle the SSLHonorCipherOrder missing example' do
      input_data "#SSLStrictSNIVHostCheck On\n</IfModule>\n"
      apply_ressource :match => '^(SSLHonorCipherOrder .+\n)?</IfModule>', :ensure => 'SSLHonorCipherOrder on
</IfModule>', :exact => false
      expect_data '#SSLStrictSNIVHostCheck On
SSLHonorCipherOrder on
</IfModule>
'
    end

    it 'should handle the SSLHonorCipherOrder present example' do
      input_data "#SSLStrictSNIVHostCheck On\nSSLHonorCipherOrder on\n</IfModule>\n"
      apply_ressource :match => '^(SSLHonorCipherOrder .+\n)?</IfModule>', :ensure => 'SSLHonorCipherOrder on
</IfModule>', :exact => true
      expect_data "#SSLStrictSNIVHostCheck On\nSSLHonorCipherOrder on\n</IfModule>\n"
    end
    
    describe 'lookahead match' do
      
      after do
        apply_ressource :match => '\n(PARAMETER=123\n)?(?=last line)', :ensure => "\nPARAMETER=123\n", :exact => true
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
      it 'should put the MatchUser block just before EOF' do
        input_data '# a sample sshd config
Match User username
  ChrootDirectory /home/username
  PasswordAuthentication no
# end of example'
        apply_ressource :exact => true, :match => '/(^Match User username.*?)(^\S.*|\Z)/m', :ensure => '\2
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
        apply_ressource :exact => true, :match => '/(^Match User username.*?)(^\S.*|\Z)/m', :ensure => '\2
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
        apply_ressource :exact => true, :match => '/(^Match User username.*?)(^\S.*|\Z)/m', :ensure => '\2
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
      proc { editfile( :ensure => :absent ).destroy }.should_not raise_error
      expect_data "Abc 1#{$/}Cde 2#{$/}Efg 3#{$/}"
    end

    it 'should remove all matching lines, using string' do
      proc { editfile( :ensure => :absent, :match => 'C' ).destroy }.should_not raise_error
      expect_data "Abc 1#{$/}Efg 3#{$/}"
    end
    
    it 'should remove all matching lines, using regexp with newline (exact)' do
      proc { editfile( :ensure => :absent, :match => '/^.*c.*#{$/}/i', :exact => true ).destroy }.should_not raise_error
      expect_data "Efg 3#{$/}"
    end
    
    it 'should remove matching characters, using exact regexp' do
      proc { editfile( :ensure => :absent, :match => '/c/i', :exact => true ).destroy }.should_not raise_error
      expect_data "Ab 1#{$/}de 2#{$/}Efg 3#{$/}"
    end

    it 'should remove all matching lines' do
      proc { editfile( :ensure => :absent, :match => '/c/i' ).destroy }.should_not raise_error
      expect_data "Efg 3#{$/}"
    end

  end
  
end

