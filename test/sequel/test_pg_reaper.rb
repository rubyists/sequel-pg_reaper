# frozen_string_literal: true

require_relative '../test_helper'

LIFETIME = 0.05
POOLS = {
  threaded: {},
  timed_queue: {},
  sharded_threaded: { servers: { other: {} } },
  sharded_timed_queue: { servers: { other: {} } }
}.freeze

def reaper_db(pool_class, extra = {})
  db = Sequel.mock(extra.merge(pool_class:, max_connections: 2))
  db.extension :pg_reaper
  db.pool.connection_max_lifetime = LIFETIME
  db
end

def expire
  sleep LIFETIME * 2
end

POOLS.each do |pool_class, extra|
  describe "pg_reaper with #{pool_class} pool" do
    before do
      @db = reaper_db(pool_class, extra)
      @disconnected = []
      disconnected = @disconnected
      @db.define_singleton_method(:disconnect_connection) { |conn| disconnected << conn }
    end

    it 'reuses a connection younger than the lifetime' do
      first = @db.synchronize { |c| c }
      second = @db.synchronize { |c| c }

      _(second).must_be_same_as first
      _(@disconnected).must_be_empty
    end

    it 'replaces a connection older than the lifetime' do
      first = @db.synchronize { |c| c }
      expire
      second = @db.synchronize { |c| c }

      _(second).wont_be_same_as first
      _(@disconnected).must_equal [first]
    end

    it 'does not leak pool slots when replacing connections' do
      3.times do
        @db.synchronize { |c| c }
        expire
      end

      _(@db.pool.size).must_equal 1
    end

    it 'leaves an already checked out connection alone' do
      @db.synchronize do |outer|
        expire

        @db.synchronize { |inner| _(inner).must_be_same_as outer }
      end

      _(@disconnected).must_be_empty
    end

    it 'starts the clock for connections opened before the extension loaded' do
      db = Sequel.mock(pool_class:, max_connections: 2, **extra)
      first = db.synchronize { |c| c }
      db.extension :pg_reaper
      db.pool.connection_max_lifetime = LIFETIME

      _(db.synchronize { |c| c }).must_be_same_as first
      expire

      _(db.synchronize { |c| c }).wont_be_same_as first
    end
  end
end

describe 'pg_reaper configuration' do
  it 'defaults to 120 seconds' do
    db = Sequel.mock
    db.extension :pg_reaper

    _(db.pool.connection_max_lifetime).must_equal 120
  end

  it 'reads the lifetime from the connection_max_lifetime database option' do
    db = Sequel.mock(connection_max_lifetime: 90)
    db.extension :pg_reaper

    _(db.pool.connection_max_lifetime).must_equal 90
  end

  it 'rejects a lifetime that is not a positive number' do
    db = Sequel.mock
    db.extension :pg_reaper

    [0, -1, nil, '60'].each do |bad|
      _ { db.pool.connection_max_lifetime = bad }.must_raise ArgumentError
    end
  end

  it 'refuses single connection pools' do
    db = Sequel.mock(single_threaded: true)

    _ { db.extension :pg_reaper }.must_raise Sequel::Error
  end
end
