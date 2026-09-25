# frozen_string_literal: true

module RedmineBsystemIntegration
  # Non-authoritative, best-effort cache mapping a (Global ID, Global ID)
  # pair to the numeric relationship id Integration Core returned when this
  # plugin created that relationship.
  #
  # WHY THIS EXISTS (a real Core contract gap, not a design choice): the
  # list endpoint's RelationshipView response
  # (openapi.yaml:3292-3309 / relationships.go:125-135) is
  # {"global_id","relation_type","direction","created_at"} — it never
  # includes the relationship's numeric `id`. Only the create response
  # (relationships.go:112-120) includes `id`. But DELETE requires that id
  # (DELETE /api/service/v1/relationships/{id}). So a relationship that was
  # created by any other means (another tool, a previous plugin
  # installation, direct API use) cannot be deleted from this panel — this
  # plugin has no authoritative way to learn its id. This is flagged for
  # Lead/Core team as a candidate contract improvement (e.g. adding `id` to
  # RelationshipView); it is not something this plugin can work around
  # authoritatively.
  #
  # This cache only smooths over the common case of "I just added this
  # relationship in this panel, let me remove it again." It uses Rails.cache
  # (whatever store Redmine is configured with, memory by default) — it is
  # explicitly NOT a system of record, holds no data Integration Core does
  # not already hold, and is always safe to lose (a restart, a cache clear,
  # or a different Redmine process simply means the remove button does not
  # appear for that relationship until it is re-created).
  #
  # Simplification: keyed by the unordered Global ID pair only (not by
  # relation_type spelling), since Integration Core's create is idempotent
  # per (from, relation_type, to) triple and this plugin does not currently
  # need to distinguish multiple simultaneous relation types between the
  # same two Global IDs.
  module RelationshipIdCache
    NAMESPACE = 'bsystem_integration:relationship_id'
    TTL = 30.days

    module_function

    def remember(global_id_a, global_id_b, id)
      return if id.nil?

      Rails.cache.write(cache_key(global_id_a, global_id_b), id, expires_in: TTL)
    end

    def lookup(global_id_a, global_id_b)
      Rails.cache.read(cache_key(global_id_a, global_id_b))
    end

    def forget(global_id_a, global_id_b)
      Rails.cache.delete(cache_key(global_id_a, global_id_b))
    end

    def cache_key(global_id_a, global_id_b)
      pair = [global_id_a.to_s, global_id_b.to_s].sort
      "#{NAMESPACE}:#{pair.join('|')}"
    end
  end
end
