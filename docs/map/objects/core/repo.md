---
type: object
cluster: core
universe: live
status: verified
entity: lib/gitflash/repo.rb
verified_on: 2026-11-22
verified_at: 6fad98e plus RBS signatures (phase 5)
---

# Repo

Reads and changes branches, commits and HEAD through git. Never prompts or prints (`lib/gitflash/repo.rb`). Snapshots do not go through it: see [[snapshot-store]].

## Why this shape

Service layer shared by CLI and integrations. Parsing git output stays here and in [[branch]] / [[commit]].

## Shape

- Reads: `branches` (`merged_status: true` adds merge status and reflog activity, two git calls), `current_branch`, `default_branch`, `commits(limit: 100)`, `resolve_commit` (`repo.rb`).
- Paths: `toplevel`, `main_root` (main checkout root, differs inside a linked worktree) (`repo.rb`). Used by [[undo]] and [[hook-install]].
- Writes: `checkout`, `delete_branch`, `reset` return `Result` (`repo.rb`, `run` at `repo.rb`).
- Default branch: origin/HEAD, else local `main` / `master` (`repo.rb`).
- Parsing contract with [[branch]] / [[commit]]: `BRANCH_FORMAT`, `COMMIT_FORMAT`, `SEPARATOR` (`repo.rb`).
- `ensure_work_tree!` raises `not_a_repository` (`repo.rb`).
- Injected `bash:` makes it stubbable (`repo.rb`); the `_Bash` interface in the signatures names what it needs (`exec`, `capture`).
- Signatures: `sig/gitflash/repo.rbs` (Repo, `_Bash`) and `sig/gitflash/records.rbs` (`Branch`, `Commit`, `Result`, `Error`, `UsageError`, only what Repo's signatures need). CI runs `rbs -I sig validate` and the Repo and CLI specs under `rbs/test` with `RBS_TEST_TARGET=Gitflash::Repo`.

## Connected to

- **owns:** [[bash-command]] calls
- **owned-by:** [[command-runner]] creates one per run (`command_runner.rb:10`)
- **joins:** [[branch]], [[commit]], `Result`
- **looks-like-but-is-not:** `Result` = outcome of a write, not the JSON envelope

## If you change this

- **Hits:** all branch/commit commands; [[branch]] / [[commit]] parsing; `spec/lib/gitflash/repo_spec.rb`; [[undo]] and [[hook-install]] via `toplevel` / `main_root`.
- **Does not hit:** [[ui-output]], [[json-schema]] (unless a returned field changes), [[snapshot-store]], [[restore]].
- Changing a git format string without [[branch]].parse breaks silently.
- A new, renamed or retyped method, or a changed field of a returned record: update `sig/gitflash/`. CI's `rbs/test` step fails on a call that does not match.

## Surfaces

| Surface | Role |
|---|---|
| commands | read and write |

## See

- Source: `lib/gitflash/repo.rb`
