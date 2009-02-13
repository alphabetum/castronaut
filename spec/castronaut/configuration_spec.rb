require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))
require 'yaml'

describe Castronaut::Configuration do

  before(:all) do
    @test_config_file = File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'config', 'castronaut.example.yml'))
  end

  describe "initialization" do

    it 'gets session and login expiry from config and formats' do
      config = Castronaut::Configuration.new
      config.stub!(:config_hash).and_return( "service_ticket_expiry" => "1", "login_ticket_expiry" => "2h")
      config.setup_expiry_times
      config.service_expiry_time.should == 1
      config.login_expiry_time.should == 120 
    end

    it "defaults expiry times to 0 (which is never)" do
      config = Castronaut::Configuration.new
      config.stub!(:config_hash).and_return({})
      config.setup_expiry_times
      config.service_expiry_time.should == 0
      config.login_expiry_time.should == 0
    end

    it "raises an exception w/ non-numeric expiry times" do
      config = Castronaut::Configuration.new
      config.stub!(:config_hash).and_return({"service_ticket_expiry" => "one fine day"})
      lambda {config.setup_expiry_times}.should raise_error(ArgumentError)
    end

    it "raises an exception w/ invalid quantifier for expiry times" do
      config = Castronaut::Configuration.new
      config.stub!(:config_hash).and_return({"service_ticket_expiry" => "10nanoseconds"})
      lambda {config.setup_expiry_times}.should raise_error(ArgumentError)
    end

    it "defaults to minutes for expiry times" do
      config = Castronaut::Configuration.new
      config.stub!(:config_hash).and_return({"service_ticket_expiry" => "1"})
      config.setup_expiry_times
      config.service_expiry_time.should == 1
    end

    it "accepts hours" do
      config = Castronaut::Configuration.new
      config.stub!(:config_hash).and_return({"service_ticket_expiry" => "1h"})
      config.setup_expiry_times
      config.service_expiry_time.should == 60
    end

    it "accepts days" do
      config = Castronaut::Configuration.new
      config.stub!(:config_hash).and_return({"service_ticket_expiry" => "1d"})
      config.setup_expiry_times
      config.service_expiry_time.should == 60 * 24
    end

    it "defaults the config file path to ./castronaut.yml if none is given" do
      Castronaut::Configuration.stub!(:parse_yaml_config).and_return({})

      config = Castronaut::Configuration.new
      config.stub!(:parse_config_into_settings)
      config.stub!(:connect_activerecord)
      config.stub!(:setup_logger).and_return(stub_everything)
      Castronaut::Configuration.stub!(:new).and_return(config)

      Castronaut::Configuration.load.config_file_path.should == './castronaut.yml'
    end

    it "uses whatever file path is passed to it as the alternate path" do
      Castronaut::Configuration.stub!(:parse_yaml_config).and_return({})

      config = Castronaut::Configuration.new
      config.stub!(:parse_config_into_settings)
      config.stub!(:connect_activerecord)
      config.stub!(:setup_logger).and_return(stub_everything)
      Castronaut::Configuration.stub!(:new).and_return(config)

      Castronaut::Configuration.load("/foo/bar/baz").config_file_path.should == '/foo/bar/baz'
    end

    it "parses the file with YAML::load_file into a hash" do
      YAML.should_receive(:load_file).with(/castronaut\.example\.yml/).and_return({})

      config = Castronaut::Configuration.new
      config.stub!(:parse_config_into_settings)
      config.stub!(:connect_activerecord)
      config.stub!(:setup_logger).and_return(stub_everything)
      Castronaut::Configuration.stub!(:new).and_return(config)

      Castronaut::Configuration.load(@test_config_file)
    end

    it "exposes the loaded YAML config at :config_hash" do
      config_hash = {}
      Castronaut::Configuration.stub!(:parse_yaml_config).and_return(config_hash)

      config = Castronaut::Configuration.new
      config.stub!(:parse_config_into_settings)
      config.stub!(:connect_activerecord)
      config.stub!(:setup_logger).and_return(stub_everything)
      Castronaut::Configuration.stub!(:new).and_return(config)

      Castronaut::Configuration.load(@test_config_file).config_hash = config_hash
    end

    it "creates the log directory if it doesn't already exist" do
      config = Castronaut::Configuration.new
      config.stub!(:connect_activerecord)
      Castronaut::Configuration.stub!(:new).and_return(config)

      File.stub!(:exist?).and_return(false)
      FileUtils.should_receive(:mkdir_p)
      Castronaut::Configuration.load(@test_config_file)
    end

    it "creates an instance of Logger pointing to the log directory" do
      config = Castronaut::Configuration.new
      config.stub!(:connect_activerecord)
      Castronaut::Configuration.stub!(:new).and_return(config)
      Hodel3000CompliantLogger.should_receive(:new).with("log/castronaut.log", anything).and_return(stub_everything)

      Castronaut::Configuration.load(@test_config_file)
    end

    it "exposes the logger at :logger" do
      Castronaut::Configuration.load(@test_config_file).logger.should_not be_nil
    end

    it "sets the loggers level from the configuration" do
      Castronaut::Configuration.load(@test_config_file).logger.level.should == Logger::DEBUG
    end

    it "rotates the logger daily" do
      config = Castronaut::Configuration.new
      config.stub!(:connect_activerecord)
      Castronaut::Configuration.stub!(:new).and_return(config)

      Hodel3000CompliantLogger.should_receive(:new).with("log/castronaut.log", "daily").and_return(stub_everything)

      Castronaut::Configuration.load(@test_config_file)
    end

  end

  describe "configuration settings" do

    before(:all) do
      @yml_config = YAML::load_file(@test_config_file)
    end

    it "load of Yaml config for testing should not be nil" do
      @yml_config.should_not be_nil
    end

    %w{organization_name environment server_port log_directory log_level ssl_enabled cas_database cas_adapter}.each do |config_setting|

      describe config_setting do

        it "defines a method for the #{config_setting}" do
          Castronaut::Configuration.load(@test_config_file).respond_to?(config_setting).should be_true
        end

        it "sets the #{config_setting} to the value of the same key in the YAML config" do
          Castronaut::Configuration.load(@test_config_file).send(config_setting).should == @yml_config[config_setting]
        end

      end

    end

  end

  describe "when evil is afoot" do

    it "fails to define any methods from the configuration hash that are already methods on the object" do
      config = Castronaut::Configuration.new
      config.parse_config_into_settings({ :to_s => 'blah'})
      config.to_s.should_not == 'blah'
    end

  end

  describe "connecting the adapter to active record" do

    it "establishes a connection on the restful auth user" do
      Castronaut::Adapters::RestfulAuthentication::User.should_receive(:establish_connection)
      Castronaut::Configuration.load(@test_config_file)
    end

    it "checks if there are any tables in the adapter db" do
      Castronaut::Adapters::RestfulAuthentication::User.stub!(:establish_connection)
      Castronaut::Adapters::RestfulAuthentication::User.connection.stub!(:tables).and_return(['table'])
      Castronaut::Configuration.load(@test_config_file)
    end

    describe "when there are no tables on the adapter db" do

      xit "notifies the user on STDERR" do
        Castronaut::Adapters::RestfulAuthentication::User.stub!(:establish_connection)
        Castronaut::Adapters::RestfulAuthentication::User.connection.stub!(:tables).and_return([])
        Kernel.stub!(:exit)
        STDERR.should_receive(:puts)
        Castronaut::Configuration.load(@test_config_file)
      end

      xit "does a system exit(0)" do
        Castronaut::Adapters::RestfulAuthentication::User.stub!(:establish_connection)
        Castronaut::Adapters::RestfulAuthentication::User.connection.stub!(:tables).and_return([])
        Kernel.should_receive(:exit).with(0)
        STDERR.stub!(:puts)
        Castronaut::Configuration.load(@test_config_file)
      end

    end
  end

end
