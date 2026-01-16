require_relative "active_record_extension"

module Sqlite3Rsync
  class Railtie < Rails::Railtie
    initializer "sqlite3_rsync.active_record" do
      ActiveSupport.on_load(:active_record) do
        if Sqlite3Rsync.configuration.sync_on_write
          include Sqlite3Rsync::ActiveRecordExtension
        end
      end
    end

    config.after_initialize do
      Sqlite3Rsync.restore if Sqlite3Rsync.configuration.valid?
      at_exit { Sqlite3Rsync.stop_loop }
    end
  end
end
