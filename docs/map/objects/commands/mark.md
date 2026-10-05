---
type: object
cluster: commands
universe: live
status: verified
entity: lib/gitflash/commands/mark.rb
verified_on: 2026-10-05
verified_at: cb85dd2
---

# Mark command

Set or clear the agent / human owner of branches. Code: `Commands::Mark`.

## Why this shape

`wt add` only marks branches it creates. Branches made with plain git stay unmarked, so `clean --agent` cannot find them. `gitflash mark` lets an agent (or its instructions) mark them at the start of a session. It works for every agent, unlike a hook.

## Shape

- `mark [BRANCH...] [--owner agent|human] [--clear]`. No names: the current branch (`invalid_usage` on a detached HEAD). Owner defaults to `agent`. `--owner` with `--clear` is `invalid_options`; `--owner` values outside the enum are rejected by Thor itself (exit 1, plain text).
- Every name must exist (`unknown_branch`); nothing is written when one is unknown.
- No confirm, no snapshot: only a git config key changes and the command reverses it. `--dry-run` supported.
- Result rows carry `owner` and `previous`; status `noop` when nothing changes (`lib/gitflash/commands/mark.rb`).

## Connected to

- **joins:** [[ownership]] (`mark`, `clear`, `all`), [[repo]], [[json-schema]] `mark_*`, [[clean]] (`--agent`)
- **looks-like-but-is-not:** `git branch --edit-description`

## If you change this

- **Hits:** [[json-schema]] `mark_plan` / `mark_result`; `spec/lib/gitflash/cli_mark_spec.rb`.
- **Does not hit:** [[snapshot-store]], [[hook-claude]] (a `PostToolUse` hook that marks automatically is a separate, not yet built step).

## Surfaces

| Surface | Role |
|---|---|
| agents, humans | write |

## See

- Source: `lib/gitflash/commands/mark.rb`
