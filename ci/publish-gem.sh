#!/usr/bin/env bash
# Builds the gem and pushes it to rubygems.org. In CI (no ~/.gem) GEM_TOKEN is
# required. Locally, keep your key in ~/.gem/credentials.

: "${GEM_NAME:=sequel-pg_reaper}"

repo_top=$(git rev-parse --show-toplevel) || exit 1
cd "$repo_top" || exit 1

if [ ! -d ~/.gem ]
then
    if [ -z "$GEM_TOKEN" ]
    then
        printf 'No GEM_TOKEN provided, cannot publish\n' >&2
        exit 1
    fi
    mkdir -p ~/.gem
    printf '%s\n:rubygems: %s\n' '---' "$GEM_TOKEN" > ~/.gem/credentials
    chmod 600 ~/.gem/credentials
fi

if [ -f .version.txt ]
then
    version=$(<.version.txt)
else
    version=$(git describe --tags --abbrev=0 | sed -e 's/^v//')
fi

gem_file="$GEM_NAME-$version.gem"
if [ "${TRACE:-false}" = true ]
then
    printf 'DEBUG: Building and publishing %s\n' "$gem_file" >&2
fi

bundle exec gem build "$GEM_NAME.gemspec" || exit 1
bundle exec gem push -k rubygems --host https://rubygems.org "$gem_file"
