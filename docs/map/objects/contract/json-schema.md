---
type: object
cluster: contract
universe: live
status: verified
entity: schema/v1.json
verified_on: 2026-10-24
verified_at: 6b41e31 plus the --confirm token (#42) and the error envelope fix (#46)
---

# JSON schema

Published contract of every `--json` output. Product: "the contract". File: `schema/v1.json`.

## Why this shape

One envelope for all commands, so agents parse one shape. Roadmap standard 4: contract independent of Ruby. Fields may be added in v1; existing fields keep meaning (`schema/v1.json:5`).

## Shape

- Envelope required: `schema`, `command`, `ok`, `status`, `dry_run` (`schema/v1.json:7-13`). Optional: `plan`, `result`, `error`, `undo`.
- `command` enum (`schema/v1.json:18`): branches, checkout, delete, reset, undo, snapshots, snapshot, gc, `hook install`, `hook status`, `skill install`, `worktree list`, `worktree add`, `worktree remove`, `worktree lock`, `worktree unlock`, `worktree move`, `worktree prune`, `worktree clean`, `clean`, `pick` and `mark`. `hook claude`, `skill show`, `schema`, `version` are not in it: they print outside the envelope.
- `status` enum (`schema/v1.json:35-44`): done, planned, noop, cancelled, failed, confirmation_required, error.
- `ok` true only for done/planned/noop/cancelled, else `error` required (`schema/v1.json:82-110`).
- `confirmation_required` requires `plan` (`schema/v1.json`). `error.confirm_token` (optional string) is set only for a change `gitflash undo` cannot revert: re-run with `--confirm TOKEN`.
- `undo` object: `{ snapshot, command }`, the snapshot saved before a change (`schema/v1.json:61-70`).
- Per-command `plan` / `result` under `$defs` (`schema/v1.json:308`): branch, checkout_*, delete_*, reset_*, snapshot, undo_*, snapshots_result, snapshot_result, gc_*, hook_install, hook_status, skill_install.
- `error.code` enum has 17 codes (`schema/v1.json:315-342`).
- Enforced in specs: `run_cli(...).json` fails on mismatch (`spec/support/cli_helper.rb:11-18`).

## Connected to

- **owned-by:** printed by `Cli#schema` (`lib/gitflash/cli.rb:85-87`)
- **joins:** [[ui-output]] builds the envelope, [[exit-codes]] feed `error`, [[branch]], [[snapshot]] `to_h` feed `$defs`
- **looks-like-but-is-not:** `Result` (git outcome), not the envelope

## If you change this

- **Hits:** [[ui-output]] envelope keys; every command's `plan` / `result` hash; [[branch]] and [[snapshot]] fields; error codes raised in `lib/`; specs using `.json`; downstream agents parsing v1.
- **Does not hit:** text output; [[repo]] git calls; [[command-descriptions]]; the hook protocol JSON of [[hook-claude]] (that is Claude Code's contract).
- New command: add to the `command` enum and add a per-command block, or validation fails.
- Breaking change needs `v2.json`, not an edit.
- **Outside-in:** `gitflash.gemspec:25-27` packages the file; `$id` URL (`schema/v1.json:3`); README link. Moving it breaks the gem.

## Surfaces

| Surface | Role |
|---|---|
| agents, scripts | read |
| `gitflash schema` | prints |
| rspec | validates |

## See

- Source: `schema/v1.json`
- `command` enum also has `gitflash`, used only for an `invalid_usage` error whose command line names no known command.
