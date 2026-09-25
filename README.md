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
version must be verified before relying on any plugin API assumption.

## Status

Bootstrap only — no functional code yet.
