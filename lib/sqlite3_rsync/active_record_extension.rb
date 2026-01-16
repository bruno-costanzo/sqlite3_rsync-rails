require "active_support/concern"

module Sqlite3Rsync
  module ActiveRecordExtension
    extend ActiveSupport::Concern

    included do
      after_commit :_sqlite3_rsync_sync_on_write, on: [:create, :update, :destroy]
    end

    private

    def _sqlite3_rsync_sync_on_write
      Sqlite3Rsync.sync_debounced
    rescue => e
      Sqlite3Rsync.configuration.on_error&.call
    end
  end
end
