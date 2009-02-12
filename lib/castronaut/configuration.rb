require 'yaml'
require 'logger'
require 'fileutils'

class Hodel3000CompliantLogger < Logger
  def format_message(severity, timestamp, msg, progname)
    "#{timestamp.strftime("%b %d %H:%M:%S")} [#{$PID}]: #{severity} - #{progname.gsub(/\n/, '').lstrip}\n"
  end
end

module Castronaut

  class Configuration
    DefaultConfigFilePath = './castronaut.yml'

    attr_accessor :config_file_path, :config_hash, :logger

    def self.load(config_file_path = Castronaut::Configuration::DefaultConfigFilePath)
      config = Castronaut::Configuration.new
      config.config_file_path = config_file_path
      config.config_hash = parse_yaml_config(config_file_path)
      config.parse_config_into_settings(config.config_hash)
      config.logger = config.setup_logger
      config.debug_initialize if config.logger.debug?
      config.connect_activerecord 
      config.setup_expiry_times
      config
    end

    def self.parse_yaml_config(file_path)
      YAML::load_file(file_path)
    end

    def parse_config_into_settings(config)
      mod = Module.new do
        config.each_pair do |k,v|
          if self.methods.include?(k.to_s)
            STDERR.puts "#{self.class} - Configuration tried to define #{k}, which was already defined." unless ENV["test"] == "true"
            next
          end
          define_method(k) { v }
        end
      end
      self.extend mod
    end

    def create_directory(dir)
      FileUtils.mkdir_p(dir) unless File.exist?(dir)
    end

    def setup_logger
      create_directory(log_directory)
      log = Hodel3000CompliantLogger.new("#{log_directory}/castronaut.log", "daily")
      log.level = eval(log_level)
      log
    end

    def setup_expiry_times
      expiry_proc = lambda { |key|
        return 0 if config_hash[key].nil? || config_hash[key] == "0"
        len_and_unit = config_hash[key].scan(/(\d+)(\w*)/).pop
        raise ArgumentError, "invalid ticket expiry format; either leave blank or use format length[unit]; i.e., 60m, 36h" if len_and_unit.nil? || len_and_unit.empty?

        case len_and_unit.last
        when /^m/i: return len_and_unit.first.to_i
        when /^h/i: return len_and_unit.first.to_i * 60
        when /^d/i: return len_and_unit.first.to_i * 24 * 60
        when /^(\s*)$/: return len_and_unit.first.to_i 
        else
          raise ArgumentError, "invalid expiry length"
        end
      }
      mod = Module.new do
        define_method(:login_expiry_time) { 
          expiry_proc.call(:login_ticket_expiry) 
        }
        define_method(:session_expiry_time) {
          expiry_proc.call(:session_ticket_expiry)
        }
      end
      self.extend mod
      return self.login_expiry_time, self.session_expiry_time
    end

    def debug_initialize
      logger.debug "#{self.class} - initializing with parameters"
      config_hash.each_pair do |key, value|
        logger.debug "--> #{key} = #{value.inspect}"
      end
      logger.debug "#{self.class} - initialization complete"
    end

    def can_fire_callbacks?
      config_hash.keys.include?('callbacks') && !config_hash['callbacks'].nil?
    end

    def connect_activerecord
      create_directory('db')

      ActiveRecord::Base.logger = logger
      ActiveRecord::Base.colorize_logging = false

      connect_cas_to_activerecord
      connect_adapter_to_activerecord if cas_adapter.has_key?('database')
    end

    def connect_cas_to_activerecord
      logger.info "#{self.class} - Connecting to cas database using #{cas_database.inspect}"
      ActiveRecord::Base.establish_connection(cas_database)

      migration_path = File.expand_path(File.join(File.dirname(__FILE__), 'db'))

      logger.debug "#{self.class} - Migrating to the latest version using migrations in #{migration_path}"
      ActiveRecord::Migrator.migrate(migration_path, ENV["VERSION"] ? ENV["VERSION"].to_i : nil)
    end

    def connect_adapter_to_activerecord
      logger.info "#{self.class} - Connecting to cas adapter database using #{cas_adapter['database'].inspect}"
      if cas_adapter['adapter'] == "database"
        Castronaut::Adapters::RestfulAuthentication::User.establish_connection(cas_adapter['database'])
        Castronaut::Adapters::RestfulAuthentication::User.logger = logger
      elsif cas_adapter['adapter'] == "development"
        Castronaut::Adapters::Development::User.establish_connection(cas_adapter['database'])
        Castronaut::Adapters::Development::User.logger = logger
      end

      unless ENV["test"] == "true"
        if Castronaut::Adapters::RestfulAuthentication::User.connection.tables.empty?
          STDERR.puts "#{self.class} - There are no tables in the given database.\nConfig details:\n#{config_hash.inspect}"
          Kernel.exit(0)
        end
      end
    end
  end

end
