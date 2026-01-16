require "open3"

module Sqlite3Rsync
  module Syncer
    DEBOUNCE_MUTEX = Mutex.new
    STATE_MUTEX = Mutex.new

    class << self
      attr_accessor :sync_thread, :running, :last_write_sync,
                    :cached_ssh_key_path, :cached_ssh_wrapper_path

      def config
        Sqlite3Rsync.configuration
      end

      def restore
        return unless config.valid?
        return if File.exist?(config.local_path)

        log "Restoring from #{config.remote}..."

        success = run_rsync(config.remote, config.local_path)

        if success
          log "Restore completed"
          config.on_restore&.call
        else
          log "No remote backup found, starting fresh"
        end
      end

      def sync
        return unless config.valid?
        return unless File.exist?(config.local_path)

        log "Syncing to #{config.remote}..."

        success = run_rsync(config.local_path, config.remote)

        if success
          log "Sync completed"
          config.on_sync&.call
        else
          log "Sync failed, will retry"
          config.on_error&.call
        end
      end

      def start_loop
        return unless config.valid?

        STATE_MUTEX.synchronize do
          return if running
          self.running = true
        end

        log "Starting sync loop (every #{config.interval}s)..."

        self.sync_thread = Thread.new do
          while running
            sleep config.interval
            begin
              sync if running
            rescue => e
              log "Sync error: #{e.message}"
              config.on_error&.call
            end
          end
        end
      end

      def stop_loop
        STATE_MUTEX.synchronize do
          return unless running
          self.running = false
        end

        log "Stopping sync loop..."

        sync

        if sync_thread&.join(5).nil?
          log "Warning: sync thread did not terminate in time"
          sync_thread&.kill
        end
        self.sync_thread = nil
        cleanup_temp_files
        log "Sync loop stopped"
      end

      def sync_debounced
        return unless config.sync_on_write

        self.last_write_sync ||= Time.at(0)

        should_sync = DEBOUNCE_MUTEX.synchronize do
          now = Time.now
          if (now - last_write_sync) >= config.write_debounce_seconds
            self.last_write_sync = now
            true
          else
            false
          end
        end

        sync if should_sync
      end

      private

      def run_rsync(source, destination)
        args = build_command_args(source, destination)
        output, status = Open3.capture2e(*args)

        if status.success? && output.include?("total size")
          stats = output.lines.last(2).map(&:strip).join(" | ")
          log stats
        end

        status.success?
      end

      def build_command_args(source, destination)
        args = ["sqlite3_rsync", source, destination, "--protocol", "1", "-v"]

        if config.ssh_key.present?
          args.concat(["--ssh", ssh_wrapper_path])
        end

        args
      end

      def ssh_wrapper_path
        return cached_ssh_wrapper_path if cached_ssh_wrapper_path && File.exist?(cached_ssh_wrapper_path)

        key_path = ssh_key_path
        wrapper_path = File.join(Dir.tmpdir, "sqlite3_rsync_ssh_#{Process.pid}")

        script = <<~BASH
          #!/bin/bash
          exec ssh -i #{key_path} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$@"
        BASH

        File.write(wrapper_path, script)
        File.chmod(0755, wrapper_path)

        self.cached_ssh_wrapper_path = wrapper_path
      end

      def ssh_key_path
        return config.ssh_key if File.exist?(config.ssh_key.to_s)
        return cached_ssh_key_path if cached_ssh_key_path && File.exist?(cached_ssh_key_path)

        path = File.join(Dir.tmpdir, "sqlite3_rsync_key_#{Process.pid}")
        key_content = normalize_ssh_key(config.ssh_key)

        File.write(path, key_content)
        File.chmod(0600, path)

        self.cached_ssh_key_path = path
      end

      def cleanup_temp_files
        [cached_ssh_key_path, cached_ssh_wrapper_path].compact.each do |path|
          File.delete(path) if File.exist?(path)
        end
        self.cached_ssh_key_path = nil
        self.cached_ssh_wrapper_path = nil
      end

      def normalize_ssh_key(key)
        key = key.strip.gsub(/\A"|"\z/, '')
        key = key.lines.map(&:strip).reject(&:empty?).join("\n")
        key = key.strip + "\n"
        key
      end

      def log(message)
        $stdout.puts("[sqlite3_rsync] #{message}")
      end
    end
  end
end
