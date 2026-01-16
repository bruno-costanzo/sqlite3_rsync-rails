require "sqlite3_rsync"

Puma::Plugin.create do
  def start(launcher)
    launcher.events.on_booted do
      Sqlite3Rsync.start_loop
    end

    launcher.events.on_stopped do
      Sqlite3Rsync.stop_loop
    end

    launcher.events.on_restart do
      Sqlite3Rsync.stop_loop
    end
  end
end
