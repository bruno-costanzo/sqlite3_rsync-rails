module Sqlite3Rsync
  module Syncer
    class << self
      attr_accessor :sync_thread, :running, :debounce_mutex, :last_write_sync

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
        return if running

        self.running = true
        log "Starting sync loop (every #{config.interval}s)..."

        self.sync_thread = Thread.new do
          while running
            sleep config.interval
            sync if running
          end
        end
      end

      def stop_loop
        return unless running

        log "Stopping sync loop..."
        self.running = false

        sync

        sync_thread&.join(5)
        self.sync_thread = nil
        log "Sync loop stopped"
      end

      def sync_debounced
        return unless config.sync_on_write

        self.debounce_mutex ||= Mutex.new
        self.last_write_sync ||= Time.at(0)

        debounce_mutex.synchronize do
          now = Time.now
          if (now - last_write_sync) >= config.write_debounce_seconds
            self.last_write_sync = now
            sync
          end
        end
      end

      private

      def run_rsync(source, destination)
        cmd = build_command(source, destination)
        log "Running: #{cmd}"
        output = `#{cmd} -v 2>&1`
        success = $?.success?

        if success && output.include?("total size")
          stats = output.lines.last(2).map(&:strip).join(" | ")
          log stats
        end

        success
      end

      def build_command(source, destination)
        parts = ["sqlite3_rsync", source, destination, "--protocol", "1"]

        if config.ssh_key.present?
          parts << "--ssh"
          parts << ssh_wrapper_path
        end

        parts.join(" ")
      end

      def ssh_wrapper_path
        key_path = ssh_key_path
        wrapper_path = File.join(Dir.tmpdir, "sqlite3_rsync_ssh")

        script = <<~BASH
          #!/bin/bash
          exec ssh -i #{key_path} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$@"
        BASH

        File.write(wrapper_path, script)
        File.chmod(0755, wrapper_path)

        wrapper_path
      end

      def ssh_key_path
        return config.ssh_key if File.exist?(config.ssh_key.to_s)

        path = File.join(Dir.tmpdir, "sqlite3_rsync_key")
        key_content = normalize_ssh_key(config.ssh_key)

        log "Writing SSH key to #{path} (#{key_content.bytesize} bytes)"
        log "Key starts with: #{key_content[0..50]}..."

        File.write(path, key_content)
        File.chmod(0600, path)

        log "Key file exists: #{File.exist?(path)}, size: #{File.size(path)}"

        path
      end

      def normalize_ssh_key(key)
        key = key.strip.gsub(/\A"|"\z/, '')
        key = key.gsub(/\n\n+/, "\n")
        key = key.strip + "\n"
        key
      end

      def log(message)
        $stdout.puts("[sqlite3_rsync] #{message}")
      end
    end
  end
end
