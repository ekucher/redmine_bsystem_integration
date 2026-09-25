# frozen_string_literal: true
#
# Pure-Ruby unit tests for RedmineBsystemIntegration::RelationshipIdCache.
#
# CAVEAT (read before trusting this file wholesale): the real module relies
# on two Rails/ActiveSupport conventions it does not define itself --
# `Rails.cache` and `Integer#days`. Rather than requiring the full Redmine
# app (not available in this sandbox), this file substitutes minimal fakes
# for both *before* requiring the library file, so only this module's own
# logic (key derivation, unordered-pair symmetry, remember/lookup/forget)
# is under test. This does NOT verify real Rails.cache behavior (actual
# store backend, real expiry semantics, thread/process boundaries) -- that
# would require the real Redmine test harness. Treat the "actually run"
# claim for this file as scoped strictly to the module's own logic.
#
# Run: ruby -Ilib -Itest test/unit/relationship_id_cache_test.rb

require 'minitest/autorun'

# Minimal fake of the one ActiveSupport core extension this module needs at
# load time (TTL = 30.days).
class Integer
  def days
    self
  end unless method_defined?(:days)
end

# Minimal fake of Rails.cache: a plain in-memory hash, ignoring expires_in
# (expiry itself is Rails/ActiveSupport::Cache behavior, not this module's).
module Rails
  class FakeCache
    def initialize
      @store = {}
    end

    def write(key, value, **_opts)
      @store[key] = value
    end

    def read(key)
      @store[key]
    end

    def delete(key)
      @store.delete(key)
    end
  end

  def self.cache
    @cache ||= FakeCache.new
  end
end unless defined?(Rails)

require File.expand_path('../../lib/redmine_bsystem_integration/relationship_id_cache', __dir__)

class RelationshipIdCacheTest < Minitest::Test
  def setup
    RedmineBsystemIntegration::RelationshipIdCache.forget('TSK-000001', 'TST-000012')
  end

  def test_lookup_is_nil_before_anything_remembered
    assert_nil RedmineBsystemIntegration::RelationshipIdCache.lookup('TSK-000001', 'TST-000012')
  end

  def test_remember_then_lookup_round_trips_the_id
    RedmineBsystemIntegration::RelationshipIdCache.remember('TSK-000001', 'TST-000012', 55)
    assert_equal 55, RedmineBsystemIntegration::RelationshipIdCache.lookup('TSK-000001', 'TST-000012')
  end

  def test_lookup_is_order_independent_pair_key
    RedmineBsystemIntegration::RelationshipIdCache.remember('TSK-000001', 'TST-000012', 55)
    assert_equal 55, RedmineBsystemIntegration::RelationshipIdCache.lookup('TST-000012', 'TSK-000001')
  end

  def test_remember_with_nil_id_does_not_overwrite_or_store_anything
    RedmineBsystemIntegration::RelationshipIdCache.remember('TSK-000001', 'TST-000012', 55)
    RedmineBsystemIntegration::RelationshipIdCache.remember('TSK-000001', 'TST-000012', nil)
    assert_equal 55, RedmineBsystemIntegration::RelationshipIdCache.lookup('TSK-000001', 'TST-000012')
  end

  def test_forget_clears_the_stored_id
    RedmineBsystemIntegration::RelationshipIdCache.remember('TSK-000001', 'TST-000012', 55)
    RedmineBsystemIntegration::RelationshipIdCache.forget('TSK-000001', 'TST-000012')
    assert_nil RedmineBsystemIntegration::RelationshipIdCache.lookup('TSK-000001', 'TST-000012')
  end

  def test_different_pairs_do_not_collide
    RedmineBsystemIntegration::RelationshipIdCache.remember('TSK-000001', 'TST-000012', 55)
    RedmineBsystemIntegration::RelationshipIdCache.remember('TSK-000002', 'TST-000012', 66)

    assert_equal 55, RedmineBsystemIntegration::RelationshipIdCache.lookup('TSK-000001', 'TST-000012')
    assert_equal 66, RedmineBsystemIntegration::RelationshipIdCache.lookup('TSK-000002', 'TST-000012')
  ensure
    RedmineBsystemIntegration::RelationshipIdCache.forget('TSK-000002', 'TST-000012')
  end
end
