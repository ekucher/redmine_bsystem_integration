#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Fail when any file in this repo references a hostname that is neither a
# reserved documentation domain (RFC 2606/6761) nor an explicitly allowed
# real service.
#
# Why this exists: a real stage deployment hostname (qa-stage.byte.pp.ua)
# and a maintainer's own real domain (qa.maksr.dev) both ended up committed
# in a sibling repository during a Stage 1 SSO round -- one in a brand-new
# test file, one copy-pasted across several pre-existing docs/config-example
# files as an illustrative address. This is the same check, ported to this
# repo's pure-Ruby (no gems) test convention.
#
# Deliberately does not shell out to `git ls-files`: the CI job that runs
# this executes inside a bare `ruby:*-slim` container, where `git` is not
# guaranteed to be installed (actions/checkout falls back to downloading a
# tarball via the GitHub API when it isn't). A plain directory walk needs no
# such assumption.
#
# Run: ruby scripts/check_no_real_hostnames.rb

require 'find'

# Real services this repo's docs legitimately reference.
ALLOWED_HOSTS = %w[127.0.0.1 github.com].freeze

# RFC 2606 / RFC 6761 reserve these for documentation and examples.
RESERVED_HOST_RE = /(?:\A|\.)(?:example|invalid|test|localhost)(?:\.[a-z]{2,})?\z/i.freeze

HOST_RE = %r{https?://([a-zA-Z0-9][a-zA-Z0-9.-]*)}.freeze

# Directories that are either version control internals or would only ever
# contain generated/vendored content no human wrote by hand.
EXCLUDE_DIR = /\A(?:\.git|node_modules|vendor|coverage)\z/.freeze

root = File.expand_path('..', __dir__)
files = []
Find.find(root) do |path|
  base = File.basename(path)
  if File.directory?(path)
    Find.prune if base.match?(EXCLUDE_DIR)
    next
  end
  files << path
end

findings = []

files.each do |path|
  rel = path.sub("#{root}/", '')
  begin
    text = File.read(path, encoding: 'UTF-8')
  rescue ArgumentError, Errno::ENOENT
    next # binary or unreadable -- not source a human wrote by hand
  end

  text.each_line.with_index(1) do |line, lineno|
    line.scan(HOST_RE).each do |(hostname_with_case)|
      hostname = hostname_with_case.split(':').first.downcase
      # A bare single label (no dot) is never a real, publicly-resolvable
      # domain -- an obvious placeholder, not something this check catches.
      next unless hostname.include?('.')
      next if ALLOWED_HOSTS.include?(hostname)
      next if hostname.match?(RESERVED_HOST_RE)

      findings << "#{rel}:#{lineno}: host '#{hostname}' is not a reserved documentation domain or an allowed real service"
    end
  end
end

if findings.any?
  puts 'Found real-looking hostnames committed to the repo:'
  puts
  findings.each { |f| puts "  #{f}" }
  puts
  puts "#{findings.size} finding(s). Use a reserved documentation domain instead " \
       '(e.g. core.example.com, *.example.invalid), or add the host to ALLOWED_HOSTS ' \
       'in scripts/check_no_real_hostnames.rb if it is a real third-party service ' \
       'this plugin legitimately references.'
  exit 1
end

puts "checked #{files.size} file(s): no committed real-looking hostname"
