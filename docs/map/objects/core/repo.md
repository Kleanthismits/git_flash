---
type: object
cluster: core
universe: live
status: verified
entity: lib/gitflash/repo.rb
verified_on: 2026-10-03
verified_at: dde88fd
---

# Repo

Reads and changes branches, commits and HEAD through git. Never prompts or prints (`lib/gitflash/repo.rb:5-6`). Snapshots do not go through it: see [[snapshot-store]].

## Why this shape

Service layer shared by CLI and integrations. Parsing git output stays here and in [[branch]] / [[commit]].

## Shape

- Reads: `branches`, `current_branch`, `default_branch`, `commits(limit: 100)`, `resolve_commit` (`repo.rb:29-70`).
- Paths: `toplevel`, `main_root` (main checkout root, differs inside a linked worktree) (`repo.rb:40-49`). Used by [[undo]] and [[hook-install]].
- Writes: `checkout`, `delete_branch`, `reset` return `Result` (`repo.rb:72-84`, `run` at `repo.rb:120`).
- Default branch: origin/HEAD, else local `main` / `master` (`repo.rb:93-110`).
- Parsing contract with [[branch]] / [[commit]]: `BRANCH_FORMAT`, `COMMIT_FORMAT`, `SEPARATOR` (`repo.rb:7-14`).
- `ensure_work_tree!` raises `not_a_repository` (`repo.rb:20-26`).
- Injected `bash:` makes it stubbable (`repo.rb:16-18`).

## Connected to

- **owns:** [[bash-command]] calls
- **owned-by:** [[command-runner]] creates one per run (`command_runner.rb:10`)
- **joins:** [[branch]], [[commit]], `Result`
- **looks-like-but-is-not:** `Result` = outcome of a write, not the JSON envelope

## If you change this

- **Hits:** all branch/commit commands; [[branch]] / [[commit]] parsing; `spec/lib/gitflash/repo_spec.rb`; [[undo]] and [[hook-install]] via `toplevel` / `main_root`.
- **Does not hit:** [[ui-output]], [[json-schema]] (unless a returned field changes), [[snapshot-store]], [[restore]].
- Changing a git format string without [[branch]].parse breaks silently.

## Surfaces

| Surface | Role |
|---|---|
| commands | read and write |

## See

- Source: `lib/gitflash/repo.rb`
