require 'test_helper'

class ClientTest < TinyTds::TestCase
  
  
  context 'With valid credentials' do
    
    setup do
      @client = TinyTds::Client.new(connection_options)
    end
    
    should 'not be closed' do
      assert !@client.closed?
    end
    
    should 'allow client connection to be closed' do
      assert @client.close
      assert @client.closed?
    end
    
    should 'have a getters for the tds version information (brittle since conf takes precedence)' do
      assert_equal 9, @client.tds_version
      assert_equal 'DBTDS_8_0 - Microsoft SQL Server 2000', @client.tds_version_info
    end
    
    should 'use UTF-8 client charset/encoding by default' do
      assert_equal 'UTF-8', @client.charset
      assert_equal Encoding.find('UTF-8'), @client.encoding if ruby19?
    end
    
    should 'have a #escape method used for quote strings' do
      assert_equal "''hello''", @client.escape("'hello'")
    end
    
    should 'allow valid iconv character set' do
      ['CP850', 'CP1252', 'ISO-8859-1'].each do |encoding|
        client = TinyTds::Client.new(connection_options.merge(:encoding => encoding))
        assert_equal encoding, client.charset
        assert_equal Encoding.find(encoding), client.encoding if ruby19?
      end
    end
  
  end
  
  context 'With in-valid options' do
  
    should 'raise an argument error when no :username is supplied' do
      assert_raise(ArgumentError) { TinyTds::Client.new :username => nil }
    end
    
    should 'raise TinyTds exception with undefined :dataserver' do
      options = connection_options.merge :login_timeout => 1, :dataserver => '127.0.0.2'
      action = lambda { TinyTds::Client.new(options) }
      assert_raise_tinytds_error(action) do |e|
        assert [20008,20009].include?(e.db_error_number)
        assert_equal 9, e.severity
        assert_match %r{unable to (open|connect)}i, e.message, 'ignore if non-english test run'
      end
    end
    
    should 'raise TinyTds exception with long query past :timeout option' do
      client = TinyTds::Client.new(connection_options.merge(:timeout => 1))
      action = lambda { client.execute("WaitFor Delay '00:00:02'").do }
      assert_raise_tinytds_error(action) do |e|
        assert_equal 20003, e.db_error_number
        assert_equal 6, e.severity
        assert_match %r{timed out}i, e.message, 'ignore if non-english test run'
      end
      assert_nothing_raised { client.execute('SELECT 1 AS [one]').do }
    end
    
    should 'not timeout per sql batch when not under transaction' do
      client = TinyTds::Client.new(connection_options.merge(:timeout => 2))
      assert_nothing_raised do
        client.execute("WaitFor Delay '00:00:01'").do
        client.execute("WaitFor Delay '00:00:01'").do
        client.execute("WaitFor Delay '00:00:01'").do
      end
    end
    
    should 'not timeout per sql batch when under transaction' do
      client = TinyTds::Client.new(connection_options.merge(:timeout => 2))
      begin
        client.execute("BEGIN TRANSACTION").do
        assert_nothing_raised do
          client.execute("WaitFor Delay '00:00:01'").do
          client.execute("WaitFor Delay '00:00:01'").do
          client.execute("WaitFor Delay '00:00:01'").do
        end
      ensure
        client.execute("COMMIT TRANSACTION").do
      end
    end
    
    should 'not have problems if the connection times out' do
      client = TinyTds::Client.new(connection_options.merge(:timeout => 1))
      
      client.execute('SELECT 1 AS [one]').do
      sleep 60
      assert_nothing_raised do
        client.execute('SELECT 2 as [two]').do
      end
    end
    
    should 'raise TinyTds exception with wrong :username' do
      options = connection_options.merge :username => 'willnotwork'
      action = lambda { TinyTds::Client.new(options) }
      assert_raise_tinytds_error(action) do |e|
        assert_equal 18456, e.db_error_number
        assert_equal 14, e.severity
        assert_match %r{login failed}i, e.message, 'ignore if non-english test run'
      end
    end
    
    should 'fail miserably with unknown encoding option' do
      options = connection_options.merge :encoding => 'ISO-WTF'
      action = lambda { TinyTds::Client.new(options) }
      assert_raise_tinytds_error(action) do |e|
        assert_equal 20017, e.db_error_number
        assert_equal 9, e.severity
        assert_match %r{unexpected eof from the server}i, e.message, 'ignore if non-english test run'
      end
    end
  
  end
  
  
  
end

