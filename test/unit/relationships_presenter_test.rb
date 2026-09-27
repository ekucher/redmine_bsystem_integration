# frozen_string_literal: true
#
# Pure-Ruby unit tests for RedmineBsystemIntegration::RelationshipsPresenter.
#
# RelationshipsPresenter itself has no Rails dependency, but it calls
# ::I18n.t for translated messages. Rather than pull in the real i18n gem
# (which may not be present outside a full Redmine install), this test
# supplies a minimal fake I18n module -- I18n is a collaborator here, not
# the subject under test, so faking it is a legitimate isolation choice
# (unlike faking CoreClient's own HTTP behavior, which is covered for real
# in core_client_test.rb).
#
# Run: ruby -Ilib -Itest test/unit/relationships_presenter_test.rb

require 'minitest/autorun'

unless defined?(I18n)
  module I18n
    def self.t(key)
      key.to_s
    end
  end
end

require File.expand_path('../../lib/redmine_bsystem_integration/settings', __dir__)
require File.expand_path('../../lib/redmine_bsystem_integration/core_client', __dir__)
require File.expand_path('../../lib/redmine_bsystem_integration/relationships_presenter', __dir__)

class RelationshipsPresenterTest < Minitest::Test
  ENV_KEYS = %w[BSYSTEM_CORE_BASE_URL BSYSTEM_CORE_SERVICE_TOKEN].freeze

  def setup
    @saved_env = ENV_KEYS.each_with_object({}) { |k, h| h[k] = ENV[k] }
    @original_list_relationships = RedmineBsystemIntegration::CoreClient.instance_method(:list_relationships)
  end

  def teardown
    ENV_KEYS.each { |k| ENV[k] = @saved_env[k] }
    RedmineBsystemIntegration::CoreClient.define_method(:list_relationships, @original_list_relationships)
  end

  def stub_list_relationships(&block)
    RedmineBsystemIntegration::CoreClient.define_method(:list_relationships, &block)
  end

  def test_unconfigured_when_settings_not_configured
    ENV.delete('BSYSTEM_CORE_BASE_URL')
    ENV.delete('BSYSTEM_CORE_SERVICE_TOKEN')

    result = RedmineBsystemIntegration::RelationshipsPresenter.build(global_id: 'TSK-000001')

    assert_equal :unconfigured, result.status
    assert_equal [], result.relationships
    refute_nil result.message
  end

  def test_ok_status_carries_relationships_through_unchanged
    ENV['BSYSTEM_CORE_BASE_URL'] = 'https://core.example.com'
    ENV['BSYSTEM_CORE_SERVICE_TOKEN'] = 'tok'
    data = [{ 'global_id' => 'TST-000012', 'relation_type' => 'tested-by', 'direction' => 'incoming' }]
    stub_list_relationships { |global_id:| data }

    result = RedmineBsystemIntegration::RelationshipsPresenter.build(global_id: 'TSK-000001')

    assert_equal :ok, result.status
    assert_equal data, result.relationships
    assert_nil result.message
  end

  def test_degraded_status_on_core_client_unavailable
    ENV['BSYSTEM_CORE_BASE_URL'] = 'https://core.example.com'
    ENV['BSYSTEM_CORE_SERVICE_TOKEN'] = 'tok'
    stub_list_relationships { |global_id:| raise RedmineBsystemIntegration::CoreClient::Unavailable, 'down' }

    result = RedmineBsystemIntegration::RelationshipsPresenter.build(global_id: 'TSK-000001')

    assert_equal :degraded, result.status
    assert_equal [], result.relationships
    refute_nil result.message
  end

  def test_error_status_on_core_client_request_error_preserves_message
    ENV['BSYSTEM_CORE_BASE_URL'] = 'https://core.example.com'
    ENV['BSYSTEM_CORE_SERVICE_TOKEN'] = 'tok'
    stub_list_relationships do |global_id:|
      raise RedmineBsystemIntegration::CoreClient::RequestError.new('bad global id', status: 400, code: 'unknown_relationship_endpoint')
    end

    result = RedmineBsystemIntegration::RelationshipsPresenter.build(global_id: 'TSK-000001')

    assert_equal :error, result.status
    assert_equal 'bad global id', result.message
  end

  def test_degraded_and_error_are_distinguishable_statuses
    # This is the core "distinguish degraded from a normal error response"
    # requirement: the two failure modes must not collapse into the same
    # status, since the UI renders different messaging for each.
    ENV['BSYSTEM_CORE_BASE_URL'] = 'https://core.example.com'
    ENV['BSYSTEM_CORE_SERVICE_TOKEN'] = 'tok'

    stub_list_relationships { |global_id:| raise RedmineBsystemIntegration::CoreClient::Unavailable, 'x' }
    degraded = RedmineBsystemIntegration::RelationshipsPresenter.build(global_id: 'TSK-1')

    stub_list_relationships { |global_id:| raise RedmineBsystemIntegration::CoreClient::RequestError.new('x', status: 400) }
    errored = RedmineBsystemIntegration::RelationshipsPresenter.build(global_id: 'TSK-1')

    refute_equal degraded.status, errored.status
  end
end
