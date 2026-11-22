---
type: object
cluster: contract
universe: live
status: verified
entity: command_descriptions.yml
verified_on: 2026-11-22
verified_at: 6fad98e plus the Data descriptions (phase 5)
---

# Command descriptions

Help text for commands. File: `command_descriptions.yml`, loaded once into a frozen Hash of `Description` records (`Data.define(:short, :long)`).

## Why this shape

Long help text stays out of Thor definitions. `Cli` and `WorktreeCli` read `description(:<cmd>).short|long`.

## Shape

- Keys with `short` and `long`: branches, checkout, delete, mark, clean, reset, undo, snapshot, pick (`lib/gitflash/cli.rb`). `worktree_remove` has only `long` (`short` is nil), read by `WorktreeCli`. Other commands use inline strings in `cli.rb`, `hook_cli.rb`, `skill_cli.rb`, `worktree_cli.rb`.
- Loader: `Configuration::Descriptions.all` (memoized, frozen, strings frozen); `description(name)` fetches one (`lib/gitflash/configuration.rb`).

## Connected to

- **owned-by:** [[cli]] (`extend Configuration::Descriptions`, `cli.rb:7`)
- **looks-like-but-is-not:** not the JSON contract ([[json-schema]])

## If you change this

- **Hits:** `gitflash help` output. A missing key used by `cli.rb` raises KeyError naming it at load. A new key needs no code: `description(:new_key)` reads it.
- **Does not hit:** behavior, JSON, exit codes. Text can drift from behavior; check against command source.
- **Outside-in:** `gitflash.gemspec:25-27` packages the file; `Descriptions::FILE` loads it by relative path (`configuration.rb`). Moving it breaks the gem.

## Surfaces

| Surface | Role |
|---|---|
| humans via `--help` | read |

## See

- Source: `command_descriptions.yml`
