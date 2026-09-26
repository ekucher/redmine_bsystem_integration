# frozen_string_literal: true
#
# Pure-Ruby unit tests for RedmineBsystemIntegration::ActorTokenResolver.
#
# No Rails/Redmine dependency -- the resolver only touches plain Hash-like
# `session` and a `user` object responding to #logged?.
#
# Run: ruby -Ilib -Itest test/unit/actor_token_resolver_test.rb

require 'minitest/autorun'
require File.expand_path('../../lib/redmine_bsystem_integration/actor_token_resolver', __dir__)

FakeUser = Struct.new(:logged) do
  def logged?
    !!logged
  end
end

class ActorTokenResolverTest < Minitest::Test
  SESSION_KEY = RedmineBsystemIntegration::ActorTokenResolver::SESSION_KEY

  def test_returns_nil_when_user_is_nil
    result = RedmineBsystemIntegration::ActorTokenResolver.resolve(
      session: { SESSION_KEY => 'real-token' }, user: nil
    )
    assert_nil result
  end

  def test_returns_nil_when_user_is_anonymous
    anon = FakeUser.new(false)
    result = RedmineBsystemIntegration::ActorTokenResolver.resolve(
      session: { SESSION_KEY => 'real-token' }, user: anon
    )
    assert_nil result
  end

  def test_returns_nil_when_session_is_nil
    result = RedmineBsystemIntegration::ActorTokenResolver.resolve(session: nil, user: FakeUser.new(true))
    assert_nil result
  end

  def test_returns_nil_when_session_key_absent
    result = RedmineBsystemIntegration::ActorTokenResolver.resolve(session: {}, user: FakeUser.new(true))
    assert_nil result
  end

  def test_returns_nil_when_session_value_is_empty_string
    result = RedmineBsystemIntegration::ActorTokenResolver.resolve(
      session: { SESSION_KEY => '' }, user: FakeUser.new(true)
    )
    assert_nil result
  end

  def test_returns_token_when_logged_in_user_has_session_token
    result = RedmineBsystemIntegration::ActorTokenResolver.resolve(
      session: { SESSION_KEY => 'real-token' }, user: FakeUser.new(true)
    )
    assert_equal 'real-token', result
  end

  # -- Anti-spoofing: the resolver must have no notion of "params" at all,
  #    and must ignore any session keys other than the one documented
  #    constant it was built around.

  def test_ignores_decoy_session_keys_that_look_like_request_supplied_identity
    decoy_session = {
      :actor_token => 'attacker-supplied-value',
      'actor_token' => 'attacker-supplied-value',
      :params => { actor_token: 'attacker-supplied-value' },
      :on_behalf_of => 'attacker-supplied-value'
      # deliberately no SESSION_KEY entry
    }

    result = RedmineBsystemIntegration::ActorTokenResolver.resolve(session: decoy_session, user: FakeUser.new(true))

    assert_nil result, 'resolver must fail closed, not fall back to any decoy/attacker-shaped session key'
  end

  def test_real_session_key_wins_even_alongside_decoy_keys
    mixed_session = {
      :actor_token => 'attacker-supplied-value',
      SESSION_KEY => 'genuine-authentik-token'
    }

    result = RedmineBsystemIntegration::ActorTokenResolver.resolve(session: mixed_session, user: FakeUser.new(true))

    assert_equal 'genuine-authentik-token', result
  end

  def test_resolve_signature_accepts_no_params_or_request_shaped_argument
    # Reflection guard: if someone later adds a `params:` (or similar)
    # keyword to make this resolver reachable from request-controlled data,
    # this test fails even before any behavioral exploit is written.
    parameters = RedmineBsystemIntegration::ActorTokenResolver.method(:resolve).parameters
    keyword_names = parameters.select { |type, _| %i[key keyreq].include?(type) }.map { |_, name| name }

    assert_equal %i[session user].sort, keyword_names.sort
    refute_includes keyword_names, :params
  end
end
