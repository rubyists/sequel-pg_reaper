# frozen_string_literal: true

require 'sequel'
require_relative 'pg_reaper/version'

module Rubyists
  module Sequel
    # Retires pooled connections once they pass a maximum age, so clients move
    # to fresher pgdog pods before the old ones terminate
    module PgReaper
      DEFAULT_MAX_LIFETIME = 120

      # Extended onto the Database's connection pool
      module PoolMethods
        attr_reader :connection_max_lifetime

        def self.extended(pool)
          case pool.pool_type
          when :single, :sharded_single
            raise ::Sequel::Error, 'cannot load pg_reaper extension if using single or sharded_single connection pool'
          end

          pool.instance_exec do
            sync do
              @connection_timers ||= {}.compare_by_identity
              @connection_max_lifetime ||= DEFAULT_MAX_LIFETIME
            end
          end
        end

        # Maximum connection age in seconds, checked as a connection is checked out
        def connection_max_lifetime=(seconds)
          unless seconds.is_a?(Numeric) && seconds.positive?
            raise ArgumentError, 'connection_max_lifetime must be a positive number'
          end

          @connection_max_lifetime = seconds
        end

        private

        def make_new(*)
          conn = super
          sync { @connection_timers[conn] = ::Sequel.start_timer }
          conn
        end

        def disconnect_connection(conn)
          sync { @connection_timers.delete(conn) }
          super
        end

        # Connections opened before the extension loaded get their clock started on first checkout
        def expired?(conn)
          timer = sync { @connection_timers[conn] ||= ::Sequel.start_timer }
          ::Sequel.elapsed_seconds_since(timer) > @connection_max_lifetime
        end

        def forget_allocation(server)
          case pool_type
          when :sharded_threaded, :sharded_timed_queue
            sync { @allocated[server].delete(::Sequel.current) }
          else
            sync { @allocated.delete(::Sequel.current) }
          end
        end

        # Mirrors Sequel's connection_validator: drop the allocation, disconnect, and ask for another connection
        def acquire(*args)
          loop do
            conn = super
            return conn unless conn && expired?(conn)

            forget_allocation(args.last)
            disconnect_acquired_connection(conn, *args)
          end
        end
      end
    end
  end
end
