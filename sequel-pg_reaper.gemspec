# frozen_string_literal: true

require_relative 'lib/sequel/pg_reaper/version'

Gem::Specification.new do |spec|
  spec.name = 'sequel-pg_reaper'
  spec.version = Rubyists::Sequel::PgReaper::VERSION
  spec.authors = ['bougyman']
  spec.email = ['bougyman@users.noreply.github.com']

  spec.summary = 'Recycles Sequel connections by age so pgdog pods can drain cleanly during rollouts.'
  spec.description = 'Retires pooled Sequel connections after a maximum lifetime, so clients reach fresher pgdog pods.'
  spec.homepage = 'https://github.com/rubyists/sequel-pg_reaper'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.3.0'

  spec.metadata['allowed_push_host'] = 'https://rubygems.org'
  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata['rubygems_mfa_required'] = 'true'

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ ci/ test/ .git .release-please .rubocop .version Gemfile Rakefile mise.toml])
    end
  end
  spec.require_paths = ['lib']

  spec.add_dependency 'sequel', '~> 5.0'
end
