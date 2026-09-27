# frozen_string_literal: true

module RedmineBsystemIntegration
  # Non-authoritative, best-effort cache mapping a (Global ID, Global ID,
  # relation_type) triple to the numeric relationship id Integration Core
  # returned when this plugin created that relationship.
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
  # Keyed by (unordered Global ID pair, relation_type). relation_type is
  # part of the key — not dropped — because Integration Core's own model
  # allows more than one relation_type between the same two Global IDs
  # (e.g. both "tests" and "documents"), each a distinct edge with its own
  # id. Keying by the pair alone would collide the two edges onto one
  # cached id, and clicking "Remove" on one relation_type's row could then
  # delete the *other* relation_type's edge instead — not the target object
  # this cache exists to protect, but still the wrong edge.
  module RelationshipIdCache
    NAMESPACE = 'bsystem_integration:relationship_id'
    TTL = 30.days

    module_function

    def remember(global_id_a, global_id_b, relation_type, id)
      return if id.nil?

      Rails.cache.write(cache_key(global_id_a, global_id_b, relation_type), id, expires_in: TTL)
    end

    def lookup(global_id_a, global_id_b, relation_type)
      Rails.cache.read(cache_key(global_id_a, global_id_b, relation_type))
    end

    def forget(global_id_a, global_id_b, relation_type)
      Rails.cache.delete(cache_key(global_id_a, global_id_b, relation_type))
    end

    def cache_key(global_id_a, global_id_b, relation_type)
      pair = [global_id_a.to_s, global_id_b.to_s].sort
      "#{NAMESPACE}:#{pair.join('|')}:#{relation_type}"
    end
  end
end
