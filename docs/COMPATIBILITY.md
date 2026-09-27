# Compatibility & Operator Configuration

## Redmine version

`requires_redmine version_or_higher: '5.0.0'` (declared in `init.rb`).

This plugin only relies on APIs stable across 5.x: `Redmine::Plugin.register`,
the `Redmine::Hook::ViewListener` mechanism, a plugin-owned `config/routes.rb`,
and native `Issue#visible?` / `Issue#editable?` authorization checks. It does
not use a database migration.

**Not verified against a live Redmine instance.** This repository had no
running Redmine host app available while this plugin was built, so nothing
here has actually been exercised inside Redmine. In particular:

- The view hook this plugin renders into,
  `view_issues_show_details_bottom`, is the standard Redmine 5.x hook the
  built-in "Related issues" block itself renders through on
  `issues/show.html.erb`. Some heavily customized themes or forks are known
  to reposition or omit standard hooks — confirm the panel actually appears
  before relying on it in production.
- Whether the target deployment's actual Redmine version matches `5.0.0` or
  higher has not been confirmed from this sandbox.

Before installing in any real environment, an operator should verify the
panel renders on a real issue show page and that add/remove round-trips
against a real Integration Core instance.

## Core connectivity configuration

Integration Core base URL and this plugin's own backend service identity
(`SVC-redmine`) bearer token are read from process environment variables —
there is no existing plugin-settings/config convention in this repository to
mirror, so this is the minimal mechanism introduced for Stage 1:

| Variable                        | Required | Meaning                                                        |
|----------------------------------|----------|-----------------------------------------------------------------|
| `BSYSTEM_CORE_BASE_URL`          | yes      | e.g. `https://integration-core.internal.example.com` (no trailing slash) |
| `BSYSTEM_CORE_SERVICE_TOKEN`     | yes      | `SVC-redmine`'s bearer token. **CREDENTIAL** — never commit, never log, never put in Redmine's own Settings table. |
| `BSYSTEM_CORE_OPEN_TIMEOUT`      | no       | TCP connect timeout in seconds (default `3`)                    |
| `BSYSTEM_CORE_READ_TIMEOUT`      | no       | Response read timeout in seconds (default `5`)                  |

These must be set in the Redmine process's own environment (e.g. the
Passenger/Puma service unit, or the container's env, alongside how
`.env`/secret injection is already handled for that Redmine deployment) —
never committed to this repository, per the platform-wide rule that
`CREDENTIAL`-classified values must never be committed or sent to an LLM.
See `.env.example`-equivalent guidance in the README.

If `BSYSTEM_CORE_BASE_URL` or `BSYSTEM_CORE_SERVICE_TOKEN` is unset, the
panel renders a clearly labeled "not configured" state; it never fails
silently or crashes the issue page.

## End-user actor identity (X-On-Behalf-Of) — unresolved dependency

Every relationship mutation Integration Core accepts requires an
`X-On-Behalf-Of: Bearer <end-user token>` header carrying a token Core can
independently verify (local JWT check, or a live authentik `UserInfo` call)
back to a `USR-*` Global ID. This plugin derives that token **only** from
`session[:bsystem_authentik_access_token]` — a key this plugin never writes
itself (see `RedmineBsystemIntegration::ActorTokenResolver`) and never
accepts from request params or client-supplied headers.

**This is a genuine, currently-open gap, not an oversight:** populating that
session key requires Redmine's own login flow to be wired to authentik (for
example, an OmniAuth/OpenID-Connect strategy that stores the resulting
end-user access token in the session at login). That wiring does not exist
in this repository yet, and deciding how Redmine's authentication maps onto
an authentik-issued end-user token is an owner/production identity decision
this plugin should not invent on its own.

Until that wiring exists, add/remove UI is present but every mutation
attempt fails closed with "your BSYSTEM identity token is not available in
this Redmine session" rather than omitting the header, sending a
fabricated/guessed value, or trusting anything the browser supplied. Listing
existing relationships is unaffected, since Core's read endpoint does not
require `X-On-Behalf-Of`.

## Known Core contract gap affecting "remove"

The relationship list response (`RelationshipView`) does not include the
relationship's numeric `id` — only the create response does. Since delete
requires that id, this plugin can only offer a "Remove" control for
relationships it created itself during the lifetime of its own
non-authoritative cache (`RedmineBsystemIntegration::RelationshipIdCache`,
backed by `Rails.cache`, safe to lose at any time). Relationships created by
any other means are shown but cannot be removed from this panel. This is
flagged here for whoever owns the Integration Core contract to consider
(e.g. adding `id` to `RelationshipView`) — it is not something this plugin
can correctly work around by inventing an id.

The cache key is `(unordered Global ID pair, relation_type)` — relation_type
is part of the key, not dropped, because Core allows more than one
relation_type between the same two Global IDs (e.g. both "tests" and
"documents"), each its own edge with its own id. An earlier revision of this
cache keyed by the pair alone, which collided two such edges onto one cached
id; removing one relation_type's row could then delete the *other*
relation_type's edge instead. Caught by a two-axis `/code-review` and fixed
before merge — see `test/unit/relationship_id_cache_test.rb`'s
`test_different_relation_types_between_the_same_pair_do_not_collide`.
