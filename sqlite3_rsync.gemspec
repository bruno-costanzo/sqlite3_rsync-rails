Gem::Specification.new do |spec|
  spec.name          = "sqlite3_rsync"
  spec.version       = "0.1.0"
  spec.authors       = ["Bruno Costanzo"]
  spec.email         = ["bruno.costanzo@renuo.ch"]

  spec.summary       = "SQLite database sync for Rails using sqlite3_rsync"
  spec.description   = "Automatically sync your SQLite database to a remote server for persistence in ephemeral environments"
  spec.homepage      = "https://github.com/ninech/sqlite3_rsync-rails"
  spec.license       = "MIT"

  spec.required_ruby_version = ">= 3.1.0"

  spec.files         = Dir["lib/**/*", "README.md", "LICENSE.txt"]
  spec.require_paths = ["lib"]

  spec.add_dependency "rails", ">= 7.0"
end
