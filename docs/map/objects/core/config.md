---
type: object
cluster: core
universe: live
status: verified
entity: lib/gitflash/config.rb
verified_on: 2026-10-05
verified_at: 6a94ddd
---

# Config

User settings from `.gitflash.yml` and `~/.config/gitflash.yml`. Code: `Config` (`Data`), keys in `ConfigKeys`. Not `Hook::Settings` (Claude Code's settings file) and not `Configuration` (help text).

## Why this shape

One place reads the files and checks them, so commands receive a plain value. An unknown key or wrong type raises `invalid_config` (exit 2): a typo in `protected` must never silently unprotect a branch.

## Shape

- Keys: `protected` (name patterns, `File.fnmatch`), `stale_days` (default 30), `worktree_dir` (default `../%<repo>s.worktrees/%<branch>s`) (`lib/gitflash/config_keys.rb:5-17`).
- Precedence: repository file (main checkout root), user file, defaults. CLI flags are applied by commands and win (`lib/gitflash/config.rb:11-20`).
- `protected` adds to the fixed rule in [[delete]]; it never removes it.

## Connected to

- **joins:** [[repo]] (`main_root` gives the file location), [[exit-codes]] (`invalid_config`), [[json-schema]] (error enum)
- **looks-like-but-is-not:** [[hook-install]] settings, [[command-descriptions]]

## If you change this

- **Hits:** every command that reads a setting; the error enum in [[json-schema]]; user files on disk (a renamed key now fails loudly).
- **Does not hit:** [[snapshot-store]].

## Surfaces

| Surface | Role |
|---|---|
| humans, agents | read (files) |

## See

- Source: `lib/gitflash/config.rb`, `lib/gitflash/config_keys.rb`
