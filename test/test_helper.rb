# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

require 'sequel'

if (coverage = ENV.delete('COVERAGE'))
  require 'simplecov'

  SimpleCov.start do
    enable_coverage :branch
    command_name coverage
    add_filter '/test/'
  end
end

ENV['MT_NO_PLUGINS'] = '1' # Work around stupid autoloading of plugins
gem 'minitest'
require 'minitest/global_expectations/autorun'
