require 'yaml'
require 'logger'
require 'fileutils'
module Castronaut

  class Configuration
    DefaultConfigFilePath = './castronaut.yml'
    
    attr_accessor :config_file_path, :config_hash
    
    def initialize(config_file_path = Castronaut::Configuration::DefaultConfigFilePath)
      @config_file_path = config_file_path
      @config_hash = parse_yaml_config(@config_file_path)
      parse_config_into_settings(@config_hash)
      setup_logger
    end
    
    private
      def parse_yaml_config(file_path)
        YAML::load_file(file_path)
      end
      
      def parse_config_into_settings(config)
        mod = Module.new { config.each_pair { |k,v| define_method(k) { v } } }
        self.extend mod
      end    
      
      def create_log_directory(dir)
        FileUtils.mkdir_p(dir) unless File.exist?(dir)
      end
      
      def setup_logger
        create_log_directory(log_directory)
        Logger.new("#{log_directory}/castronaut.log")
      end
  end
  
end