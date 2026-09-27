# Architecture link

Canonical Stage 1 architecture, invariants, and the frozen Integration Core
relationship contract live in `ekucher/bsystem-deploy` under `docs/stage-1/`.

This plugin is a consumer of that contract:
- Backend service identity (`SVC-redmine`) authenticates to Integration Core.
- User-initiated mutations include a trusted end-user actor context
  (`X-On-Behalf-Of`), verified by Integration Core — never trusted from the
  browser directly.
- Redmine's own native authorization (issue/project permissions) remains the
  final authority for what a user can see; Integration Core relationships never
  grant access on their own.

## Stage 1 implementation notes

See `docs/COMPATIBILITY.md` for the `requires_redmine` version, the
untested-against-a-live-instance caveat, how Core base URL / service token
configuration is supplied, and the currently-open dependency on Redmine's
login flow to obtain an end-user token for `X-On-Behalf-Of`.
