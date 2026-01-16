require "forwardable"
require_relative "sqlite3_rsync/version"
require_relative "sqlite3_rsync/configuration"
require_relative "sqlite3_rsync/syncer"
require_relative "sqlite3_rsync/railtie" if defined?(Rails::Railtie)

module Sqlite3Rsync
  class Error < StandardError; end

  class << self
    extend Forwardable

    attr_writer :configuration

    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def syncer
      Syncer
    end

    def_delegators :syncer, :restore, :sync, :sync_debounced, :start_loop, :stop_loop
  end
end
