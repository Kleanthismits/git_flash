---
type: object
cluster: contract
universe: live
status: verified
entity: command_descriptions.yml
verified_on: 2026-10-03
verified_at: dde88fd
---

# Command descriptions

Help text for commands. File: `command_descriptions.yml`, loaded as nested Structs.

## Why this shape

Long help text stays out of Thor definitions. `Cli` reads `descriptions.<cmd>.short|long`.

## Shape

- Keys with `short` and `long`: branches, checkout, delete, reset, undo, snapshot (`lib/gitflash/cli.rb:23-66`). `snapshots`, `gc`, `hook`, `schema`, `version` use inline strings in `cli.rb`. `HookCli` also holds its own long text (`lib/gitflash/hook_cli.rb:17-66`).
- Loader: `Configuration::Descriptions` (`lib/gitflash/configuration.rb:14-17`).

## Connected to

- **owned-by:** [[cli]] (`extend Configuration::Descriptions`, `cli.rb:7`)
- **looks-like-but-is-not:** not the JSON contract ([[json-schema]])

## If you change this

- **Hits:** `gitflash help` output. A missing key used by `cli.rb` raises NoMethodError at load.
- **Does not hit:** behavior, JSON, exit codes. Text can drift from behavior; check against command source.
- **Outside-in:** `gitflash.gemspec:25-27` packages the file; `Configuration` loads it by relative path (`configuration.rb:15`). Moving it breaks the gem.

## Surfaces

| Surface | Role |
|---|---|
| humans via `--help` | read |

## See

- Source: `command_descriptions.yml`
