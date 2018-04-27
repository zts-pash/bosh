module Bosh::Registry

  class << self

    attr_accessor :logger
    attr_accessor :http_port
    attr_accessor :http_user
    attr_accessor :http_password
    attr_accessor :db
    attr_accessor :instance_manager

    def configure(config)
      validate_config(config)

      @logger ||= Logger.new(config["logfile"] || STDOUT)
      if config["loglevel"].kind_of?(String)
        @logger.level = Logger.const_get(config["loglevel"].upcase)
      end

      @http_port = config["http"]["port"]
      @http_user = config["http"]["user"]
      @http_password = config["http"]["password"]

      @db = connect_db(config["db"])

      if config.has_key?("cloud")
        plugin = config["cloud"]["plugin"]
        begin
          require "bosh/registry/instance_manager/#{plugin}"
        rescue LoadError
          raise ConfigError, "Could not find Provider Plugin: #{plugin}"
        end
        @instance_manager = Bosh::Registry::InstanceManager.const_get(plugin.capitalize).new(config["cloud"])
      else
        @instance_manager = Bosh::Registry::InstanceManager.new
      end
    end

    def connect_db(db_config)
      connection_config = db_config.dup
      custom_connection_options = db_config.delete('connection_options') { {} }

      tls_options = connection_config.delete('tls') { {} }

      if tls_options.fetch('enabled', false)
        certificate_paths = tls_options.fetch('cert')
        db_ca_path = certificate_paths.fetch('ca')
        db_client_cert_path = certificate_paths.fetch('certificate')
        db_client_private_key_path = certificate_paths.fetch('private_key')

        db_ca_provided = tls_options.fetch('bosh_internal').fetch('ca_provided')
        mutual_tls_enabled = tls_options.fetch('bosh_internal').fetch('mutual_tls_enabled')

        case connection_config['adapter']
          when 'mysql2'
            # http://sequel.jeremyevans.net/rdoc/files/doc/opening_databases_rdoc.html#label-mysql+
            connection_config['ssl_mode'] = 'verify_identity'
            connection_config['sslverify'] = true
            connection_config['sslca'] = db_ca_path if db_ca_provided
            connection_config['sslcert'] = db_client_cert_path if mutual_tls_enabled
            connection_config['sslkey'] = db_client_private_key_path if mutual_tls_enabled
          when 'postgres'
            # http://sequel.jeremyevans.net/rdoc/files/doc/opening_databases_rdoc.html#label-postgres
            connection_config['sslmode'] = 'verify-full'
            connection_config['sslrootcert'] = db_ca_path if db_ca_provided

            postgres_driver_options = {
              'sslcert' => db_client_cert_path,
              'sslkey' => db_client_private_key_path,
            }
            connection_config['driver_options'] = postgres_driver_options if mutual_tls_enabled
        end
      end

      connection_config.delete_if { |_, v| v.to_s.empty? }
      connection_config = connection_config.merge(custom_connection_options)

      db = Sequel.connect(connection_config)
      if logger
        db.logger = @logger
        db.sql_log_level = :debug
      end

      db
    end

    def validate_config(config)
      unless config.is_a?(Hash)
        raise ConfigError, "Invalid config format, Hash expected, " \
                           "#{config.class} given"
      end

      unless config.has_key?("http") && config["http"].is_a?(Hash)
        raise ConfigError, "HTTP configuration is missing from config file"
      end

      unless config.has_key?("db") && config["db"].is_a?(Hash)
        raise ConfigError, "Database configuration is missing from config file"
      end

      if config.has_key?("cloud")
        unless config["cloud"].is_a?(Hash)
          raise ConfigError, "Cloud configuration is missing from config file"
        end

        if config["cloud"]["plugin"].nil?
          raise ConfigError, "Cloud plugin is missing from config file"
        end
      end
    end

  end
end
