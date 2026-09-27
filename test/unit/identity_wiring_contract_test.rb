# frozen_string_literal: true
#
# Static source-contract tests for the two files that cannot be exercised
# behaviorally without a full Redmine boot (BsystemRelationshipsController
# subclasses Redmine's ApplicationController; Hooks subclasses
# Redmine::Hook::ViewListener). These do NOT execute the controller/hook --
# they read the plain Ruby source text and assert specific, security-load-
# bearing patterns are present/absent. This is a real, executable (no Rails
# required) test, but it is a weaker guarantee than a real request/response
# functional test -- see test/functional/*_test.rb for the assertions that
# genuinely require the real Redmine test harness and could not be run here.
#
# Run: ruby -Itest test/unit/identity_wiring_contract_test.rb

require 'minitest/autorun'

class IdentityWiringContractTest < Minitest::Test
  CONTROLLER_SRC = File.read(File.expand_path('../../app/controllers/bsystem_relationships_controller.rb', __dir__))
  HOOKS_SRC = File.read(File.expand_path('../../lib/redmine_bsystem_integration/hooks.rb', __dir__))
  ROUTES_SRC = File.read(File.expand_path('../../config/routes.rb', __dir__))

  # -- Controller: actor identity must come from session, never params -----

  def test_controller_derives_actor_token_from_session_and_current_user_only
    assert_match(/ActorTokenResolver\.resolve\(\s*session:\s*session,\s*user:\s*User\.current\s*\)/, CONTROLLER_SRC)
  end

  def test_controller_never_reads_an_identity_value_out_of_params
    refute_match(/params\[:actor_token\]/, CONTROLLER_SRC)
    refute_match(/params\[:on_behalf_of\]/, CONTROLLER_SRC)
    refute_match(/params\[:token\]/, CONTROLLER_SRC)
    refute_match(/params\[:user_id\]/, CONTROLLER_SRC)
  end

  # -- Controller: native Redmine authorization, no bespoke permission -----

  def test_controller_gates_view_on_native_issue_visibility
    assert_match(/@issue\.visible\?\(User\.current\)/, CONTROLLER_SRC)
  end

  def test_controller_gates_mutation_on_native_issue_editability
    assert_match(/@issue\.editable\?\(User\.current\)/, CONTROLLER_SRC)
  end

  def test_controller_declares_no_custom_permission
    refute_match(/Redmine::AccessControl/, CONTROLLER_SRC)
  end

  # -- Delete must only ever reference the relationship id, never construct
  #    a path touching the issue or another entity's own record.

  def test_controller_delete_call_site_only_passes_relationship_id_and_actor_token
    assert_match(/core_client\.delete_relationship\(id:\s*params\[:id\],\s*actor_token:\s*actor_token\)/, CONTROLLER_SRC)
  end

  # -- Hook: must gate on native visibility before rendering anything ------

  def test_hook_checks_issue_visibility_before_rendering
    guard_index = HOOKS_SRC.index("issue.visible?(User.current)")
    render_index = HOOKS_SRC.index('render_to_string')
    refute_nil guard_index, 'hook must call issue.visible?(User.current)'
    refute_nil render_index, 'hook must render the panel'
    assert_operator guard_index, :<, render_index, 'visibility check must happen before rendering'
  end

  # -- Routes: only index/create/destroy are exposed, nested under issues --

  def test_routes_expose_only_index_create_destroy_nested_under_issues
    assert_match(/resources :issues do/, ROUTES_SRC)
    assert_match(/resources :bsystem_relationships,\s*only:\s*%i\[index create destroy\]/, ROUTES_SRC)
  end

  def test_routes_do_not_expose_update_or_edit
    refute_match(/:update/, ROUTES_SRC)
    refute_match(/:edit\b/, ROUTES_SRC)
  end
end
