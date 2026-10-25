---
type: object
cluster: core
universe: live
status: verified
entity: lib/gitflash/config.rb
verified_on: 2026-10-24
verified_at: 6b41e31 plus the repository worktree_dir limit (#47) and snapshot_exclude (#49)
---

# Config

User settings from `.gitflash.yml` and `~/.config/gitflash.yml`. Code: `Config` (`Data`), keys in `ConfigKeys`. Not `Hook::Settings` (Claude Code's settings file) and not `Configuration` (help text).

## Why this shape

One place reads the files and checks them, so commands receive a plain value. An unknown key or wrong type raises `invalid_config` (exit 2): a typo in `protected` must never silently unprotect a branch.

## Shape

- Keys: `protected` (name patterns, `File.fnmatch`), `stale_days` (default 30), `worktree_dir` (default `../%<repo>s.worktrees/%<branch>s`) (`lib/gitflash/config_keys.rb:5-17`).
- Precedence: repository file (main checkout root), user file, defaults, key by key; CLI flags are applied by commands and win. Exceptions: `protected` is the union of both files, so a repository can add protection but never remove the user's; `worktree_dir` from the user file wins over the repository's (`Config.load`).
- A repository's `worktree_dir` comes with the clone, so it must stay next to the main checkout: no absolute path or `~`, and it may not climb above the main checkout's parent (`ConfigKeys.contained?`, checked by `Config.check_repository_dir!`; `invalid_config` otherwise). The user file may point anywhere. `Config#worktree_path` checks a repository value again where it really leads (`ConfigKeys.check_contained!`: the real path of the deepest existing directory on the way), so a symbolic link in the repository cannot lead outside the main checkout's parent; `worktree_dir_from_repo` records where the value came from.
- `worktree_dir` is a template with only `%<repo>s` and `%<branch>s`, at most 512 characters, substituted as plain text (`ConfigKeys.template?`, `Config#worktree_path`); no `format`, so no width directives.
- `protected` adds to the fixed rule in [[delete]]; it never removes it.
- `snapshot_exclude` (list of patterns, default none; both files add up): untracked files whose path or name matches (`Config#snapshot_excluded?`, `File.fnmatch` with `FNM_PATHNAME | FNM_DOTMATCH`) stay out of snapshots ([[state-capture]]).

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
