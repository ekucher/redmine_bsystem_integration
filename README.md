# redmine_bsystem_integration

Redmine plugin adding a native Related Objects panel on issue pages, backed by the
BSYSTEM Integration Core relationship API.

This repository is currently a bootstrap baseline only. Feature work happens on
`stage1/native-related-objects` and successor branches.

## Architecture

See the canonical BSYSTEM Stage 1 architecture documentation in `ekucher/bsystem-deploy`
(`docs/stage-1/`) for the overall system design, source-of-truth model, and security
invariants this plugin must respect.

## Compatibility

Targets Redmine 5.0+ (see `init.rb`). Compatibility with the actually deployed Redmine
version must be verified before relying on any plugin API assumption. See
`docs/COMPATIBILITY.md` for the full caveat and for how to configure Integration Core
connectivity (`BSYSTEM_CORE_BASE_URL`, `BSYSTEM_CORE_SERVICE_TOKEN`, and related
environment variables — never commit these).

## Status

Stage 1 MVP: a native "Related Objects" panel on the issue show page, backed by
Integration Core's relationship endpoints (list/create/delete). See
`docs/COMPATIBILITY.md` for open dependencies (end-user actor token wiring) and known
Core contract gaps this plugin works around.
