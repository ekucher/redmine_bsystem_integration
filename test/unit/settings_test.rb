# frozen_string_literal: true
#
# Pure-Ruby unit tests for RedmineBsystemIntegration::Settings.
# No Rails/Redmine dependency: pure ENV reads.
#
# Run: ruby -Ilib -Itest test/unit/settings_test.rb

require 'minitest/autorun'
require File.expand_path('../../lib/redmine_bsystem_integration/settings', __dir__)

class SettingsTest < Minitest::Test
  ENV_KEYS = %w[BSYSTEM_CORE_BASE_URL BSYSTEM_CORE_SERVICE_TOKEN BSYSTEM_CORE_OPEN_TIMEOUT BSYSTEM_CORE_READ_TIMEOUT].freeze

  def setup
    @saved = ENV_KEYS.each_with_object({}) { |k, h| h[k] = ENV[k] }
    ENV_KEYS.each { |k| ENV.delete(k) }
  end

  def teardown
    ENV_KEYS.each { |k| ENV[k] = @saved[k] }
  end

  def test_defaults_when_unset
    assert_equal '', RedmineBsystemIntegration::Settings.core_base_url
    assert_equal '', RedmineBsystemIntegration::Settings.service_token
    assert_equal RedmineBsystemIntegration::Settings::DEFAULT_OPEN_TIMEOUT_SECONDS,
                 RedmineBsystemIntegration::Settings.open_timeout
    assert_equal RedmineBsystemIntegration::Settings::DEFAULT_READ_TIMEOUT_SECONDS,
                 RedmineBsystemIntegration::Settings.read_timeout
    refute RedmineBsystemIntegration::Settings.configured?
  end

  def test_reads_base_url_and_strips_trailing_slash
    ENV['BSYSTEM_CORE_BASE_URL'] = 'https://core.example.com/'
    assert_equal 'https://core.example.com', RedmineBsystemIntegration::Settings.core_base_url
  end

  def test_reads_service_token
    ENV['BSYSTEM_CORE_SERVICE_TOKEN'] = ' svc-token '
    assert_equal 'svc-token', RedmineBsystemIntegration::Settings.service_token
  end

  def test_reads_custom_timeouts
    ENV['BSYSTEM_CORE_OPEN_TIMEOUT'] = '7'
    ENV['BSYSTEM_CORE_READ_TIMEOUT'] = '11'
    assert_equal 7, RedmineBsystemIntegration::Settings.open_timeout
    assert_equal 11, RedmineBsystemIntegration::Settings.read_timeout
  end

  def test_invalid_timeout_falls_back_to_default
    ENV['BSYSTEM_CORE_OPEN_TIMEOUT'] = 'not-a-number'
    assert_equal RedmineBsystemIntegration::Settings::DEFAULT_OPEN_TIMEOUT_SECONDS,
                 RedmineBsystemIntegration::Settings.open_timeout
  end

  def test_configured_is_true_only_when_both_base_url_and_token_present
    ENV['BSYSTEM_CORE_BASE_URL'] = 'https://core.example.com'
    refute RedmineBsystemIntegration::Settings.configured?, 'token still missing'

    ENV['BSYSTEM_CORE_SERVICE_TOKEN'] = 'svc-token'
    assert RedmineBsystemIntegration::Settings.configured?
  end
end
