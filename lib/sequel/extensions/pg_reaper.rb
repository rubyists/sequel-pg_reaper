# frozen_string_literal: true

require_relative '../pg_reaper'

# The pg_reaper extension retires pooled connections older than the Database's
# :connection_max_lifetime option (default 120s) as they are checked out.
Sequel::Database.register_extension(:pg_reaper) do |db|
  pool = db.pool.extend(Rubyists::Sequel::PgReaper::PoolMethods)
  lifetime = db.opts[:connection_max_lifetime]
  pool.connection_max_lifetime = lifetime if lifetime
end
