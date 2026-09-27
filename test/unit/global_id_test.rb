# frozen_string_literal: true
#
# Pure-Ruby unit tests for RedmineBsystemIntegration::GlobalId.
# No Rails/Redmine dependency: only needs an object responding to #id.
#
# Run: ruby -Ilib -Itest test/unit/global_id_test.rb

require 'minitest/autorun'
require File.expand_path('../../lib/redmine_bsystem_integration/global_id', __dir__)

FakeIssue = Struct.new(:id, :subject)

class GlobalIdTest < Minitest::Test
  def test_formats_with_tsk_prefix_and_six_digit_zero_padding
    issue = FakeIssue.new(42, 'Anything')
    assert_equal 'TSK-000042', RedmineBsystemIntegration::GlobalId.for_issue(issue)
  end

  def test_does_not_pad_beyond_six_digits_for_large_ids
    issue = FakeIssue.new(1_234_567, 'Anything')
    assert_equal 'TSK-1234567', RedmineBsystemIntegration::GlobalId.for_issue(issue)
  end

  def test_derives_only_from_immutable_id_never_from_subject_or_other_mutable_label
    issue_a = FakeIssue.new(7, 'Original subject')
    issue_b = FakeIssue.new(7, 'Completely renamed subject')

    assert_equal RedmineBsystemIntegration::GlobalId.for_issue(issue_a),
                 RedmineBsystemIntegration::GlobalId.for_issue(issue_b),
                 'Global ID must depend only on issue.id, per the Global ID invariant'
  end

  def test_different_ids_produce_different_global_ids
    refute_equal(
      RedmineBsystemIntegration::GlobalId.for_issue(FakeIssue.new(1, 'x')),
      RedmineBsystemIntegration::GlobalId.for_issue(FakeIssue.new(2, 'x'))
    )
  end
end
