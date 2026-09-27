# frozen_string_literal: true

module RedmineBsystemIntegration
  # Maps a Redmine Issue to its BSYSTEM Global ID (TSK-*).
  #
  # UNVERIFIED ASSUMPTION (flagged per the Stage 1 audit, not confirmed
  # against a live Integration Core): this plugin assumes Integration Core
  # already knows a Global ID of the form "TSK-%06d" for every Redmine issue,
  # derived from the issue's own immutable numeric `id` (never from title,
  # tracker name, or any other mutable label, per the Global ID invariant
  # "never derive stable identity from names/labels").
  #
  # What is genuinely unconfirmed: whether Integration Core has a backfill/
  # registration step that assigns a TSK-* Global ID to every existing (and
  # future) Redmine issue using exactly this numbering, or whether issue-to-
  # Global-ID assignment is a separate synchronization concern this plugin
  # does not yet participate in. If an issue has no corresponding Global ID
  # in Core, relationship calls will fail with the documented
  # `unknown_relationship_endpoint` (400) error, which this plugin surfaces
  # to the user rather than guessing or fabricating a mapping.
  module GlobalId
    PREFIX = 'TSK'

    module_function

    def for_issue(issue)
      format('%s-%06d', PREFIX, issue.id)
    end
  end
end
