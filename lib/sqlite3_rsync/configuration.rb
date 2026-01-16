module Sqlite3Rsync
  class Configuration
    attr_writer :remote, :ssh_key, :sync_on_write, :write_debounce_seconds
    attr_accessor :local_path, :interval, :on_sync, :on_restore, :on_error

    def initialize
      @local_path = nil
      @interval = 10
      @on_sync = nil
      @on_restore = nil
      @on_error = nil
    end

    def remote
      @remote || ENV["SQLITE_REMOTE"]
    end

    def ssh_key
      @ssh_key || ENV["SQLITE_SSH_KEY"]
    end

    def sync_on_write
      return @sync_on_write unless @sync_on_write.nil?
      ENV.fetch("SQLITE_SYNC_ON_WRITE", "false") == "true"
    end

    def write_debounce_seconds
      @write_debounce_seconds || ENV.fetch("SQLITE_WRITE_DEBOUNCE", 2).to_i
    end

    def local_path
      @local_path || default_local_path
    end

    def valid?
      remote.present? && local_path.present?
    end

    private

    def default_local_path
      return nil unless defined?(Rails)

      db_config = Rails.configuration.database_configuration[Rails.env]
      db_config["database"] if db_config["adapter"] == "sqlite3"
    end
  end
end
