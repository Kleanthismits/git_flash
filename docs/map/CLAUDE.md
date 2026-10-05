# gitflash map

Catalog of what gitflash is made of and what a change hits. Source stays truth; cards cite it.
Mapped on branch `phase3_cleanup` (0.6.0 released, 0.7.0 in progress). Cards state the commit they were verified at.

gitflash = Ruby CLI (Thor). Safety net and cleanup for git repos that AI agents work in. One JSON contract (`schema/v1.json`).

## Name collisions

| Product word | Code name |
|---|---|
| the contract | `schema/v1.json`, printed by `gitflash schema` |
| report / envelope | `Ui#report` builds it. `Result` is a git outcome, not the envelope. |
| confirmation | `ConfirmationRequired` (exit 2) + `Prompt` + `--yes` |
| undo point | `Snapshot`, stored as a commit under `refs/gitflash/snapshots/`. Not a git stash. |
| the hook | `gitflash hook claude` (`Hook::Claude`). Output is Claude Code's protocol, not the envelope. |
| exit codes | 0 ok, 1 `Error`, 2 `UsageError` / `ConfirmationRequired`. `hook claude` always 0. |

## Universes

- **live:** branches, checkout, delete, reset, undo, snapshot, snapshots, gc, hook claude/install/status, clean, pick, mark, worktree list/add/remove/lock/unlock/move/prune/clean, `.gitflash.yml`, ownership marks (set by `wt add` and `mark`); `Repo`, `Ui`, snapshot classes, `schema/v1.json`
- **ghost:** `docs/ROADMAP.md` phase 4+ (MCP, Skill). Not in `lib/`. Do not implement against.
- **leftover:** none found

## Route

| If | Go to |
|---|---|
| need what noun X is | `objects/_index.md`, then one card |
| changing X, what else moves | `effects/CONTEXT.md` |
| adding a card | `_templates/object.md`, rules in `_meta/schema.md` |
| how to walk this map | `CONTEXT.md` |

Twins `AGENTS.md` and `routing.md` are copies of this file. Edit `CLAUDE.md` only, then run `docs/map/_meta/sync-twins.sh`.
