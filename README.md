# sqlite3_rsync

SQLite database sync for Rails using sqlite3_rsync. Automatically sync your SQLite database to a remote server for persistence in ephemeral environments like Deploio.

## Installation

```ruby
gem 'sqlite3_rsync'
```

## Usage

### 1. Configure (optional if using ENV vars)

```ruby
# config/initializers/sqlite3_rsync.rb
Sqlite3Rsync.configure do |config|
  config.remote = ENV["SQLITE_REMOTE"]     # sync@storage:/data/myapp/db.sqlite
  config.ssh_key = ENV["SQLITE_SSH_KEY"]   # SSH private key content or path
  config.interval = 10                      # sync interval in seconds
  config.sync_on_write = true               # sync after each database write
  config.write_debounce_seconds = 2         # minimum seconds between write-triggered syncs
end
```

### 2. Enable Puma plugin

```ruby
# config/puma.rb
plugin :sqlite3_rsync
```

That's it! The gem will:

1. **On boot:** Restore database from remote (if exists)
2. **While running:** Sync to remote every N seconds
3. **On shutdown:** Final sync before stopping

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `SQLITE_REMOTE` | Remote path (e.g., `user@host:/path/db.sqlite`) | - |
| `SQLITE_SSH_KEY` | SSH private key (content or file path) | - |
| `SQLITE_SYNC_ON_WRITE` | Sync after each database write (`true`/`false`) | `false` |
| `SQLITE_WRITE_DEBOUNCE` | Minimum seconds between write-triggered syncs | `2` |

## Sync Modes

### Interval Sync (default)
Syncs every N seconds. Simple and predictable, but data written between syncs could be lost if the server crashes.

### Sync on Write
When `sync_on_write` is enabled, the gem also syncs after each database transaction commits. This provides better durability but increases sync operations.

**Debouncing:** To prevent overwhelming the system (e.g., a loop creating 100 records), write-triggered syncs are debounced. With `write_debounce_seconds = 2`, even 100 rapid writes will only trigger 1 sync.

**Recommendation:** Use both modes together—`sync_on_write` for immediate durability and interval sync (with a longer interval like 60s) as a safety net.

## How it works

```
App starts
    │
    ├─► Restore from remote (sqlite3_rsync pull)
    │
    ├─► Run migrations
    │
    ├─► Start Puma
    │       │
    │       └─► Start sync loop (every N seconds)
    │               │
    │               └─► sqlite3_rsync push
    │
App stops
    │
    └─► Final sync (sqlite3_rsync push)
```
