# gitflash roadmap (0.5 → 1.0)

This roadmap comes from a discovery done after the 0.4.0 release, revised after phase 1 was built. Each finding was measured on the code or checked against a source. Sources are listed at the end.

## Positioning

> **gitflash is a safety net and cleanup tool for git repositories that AI coding agents work in. It works on plain git, with no new tool or model to adopt, and speaks one JSON contract through the CLI, an Agent Skill, MCP and agent hooks.**

Every feature must pass this test: *does it make git safer or easier for agents in a way other tools do not?* Features that only polish the human terminal experience are low priority; lazygit and fzf already do that well.

### What already exists

| Tool | What it does | What it does not cover |
| --- | --- | --- |
| Official `mcp-server-git` | Generic git tools for agents | Guardrails, undo |
| `selfagency/git-mcp` | 80+ git actions over MCP, confirmations for destructive operations, worktrees, pull requests (TypeScript) | Undo; little adoption |
| jj (Jujutsu) | Operation log and `jj undo` | Requires adopting a new version control tool |
| GitButler | MCP server, Claude Code hooks, virtual branches | Requires the GitButler app and its branch model |
| agentjj | Git layer for agents with checkpoints and undo | Archived in February 2026 |
| Claude Code checkpoints | Undo for Claude's file edits | Changes made through shell commands and by most subagents |

Undo on its own is not unique. What no tool covers is **undo for plain git, with nothing new to adopt, for the operations agent harnesses do not track**: Claude Code's documentation states that changes made by shell commands (such as `git reset --hard` or `git branch -D`) cannot be undone with `/rewind`.

### The four standards

1. **One flow for every change.** Every command that changes the repository follows the same steps: plan, confirm, snapshot, execute, report. The report always has the same shape and says how to undo the change.
2. **Protection for commands agents run themselves.** A hook snapshots the repository before an agent runs a destructive git command, and can block it with a safer alternative. The agent keeps using plain git.
3. **Cleanup for parallel agent work.** gitflash knows which branches and worktrees agents created, reports which are merged, stale, dirty or orphaned, and removes them safely.
4. **One published contract.** A versioned JSON Schema and fixed exit codes, identical for the CLI, the Skill, MCP and hooks. The contract does not depend on Ruby.

### Risks

- **Ruby as the runtime.** Agent tools are mostly installed with `npx` or `uvx`, and many agent environments have no Ruby. gitflash stays on Ruby for now; keeping the contract language-neutral keeps a later port possible without breaking agents.
- **The name.** "gitflash" is easy to confuse with "git-flow". Keep the name, but always pair it with a tagline that says what it does.

## Where gitflash stands

### Phase 1 — Non-interactive core (implemented, not yet released)

- `Repo` service layer returning `Branch` and `Commit` records; the CLI and future integrations share it.
- `gitflash branches` reports last commit, ahead/behind, upstream gone and merge status against the default branch (`origin/HEAD`, else `main` or `master`). Filters: `--merged`, `--gone`, `--stale DAYS`.
- `checkout BRANCH`, `delete BRANCH...` and `reset COMMIT` run without menus. `--json`, `--yes` and `--dry-run` work on every command.
- Without a terminal, gitflash never waits for input: it exits with code 2 and explains what to pass, or returns the plan and asks for `--yes`.
- `delete` keeps unmerged branches unless `--force` is given and protects the default branch. `reset --soft` was added.

### The JSON contract, version 1 (implemented, not yet released)

Every `--json` run prints one object in the same envelope, defined in [`schema/v1.json`](../schema/v1.json) and printed by `gitflash schema`:

```json
{
  "schema": 1,
  "command": "delete",
  "ok": false,
  "status": "confirmation_required",
  "dry_run": false,
  "plan": { "branches": ["old-feature"], "force": false },
  "error": { "code": "confirmation_required", "message": "...", "exit_code": 2 }
}
```

- `status` is one of `done`, `planned`, `noop`, `cancelled`, `failed`, `confirmation_required` or `error`. `ok` is true for the first four.
- `plan` describes the change; `result` describes what happened and what is needed to revert it (for example, each deleted branch with its last commit, and the previous HEAD after a reset).
- `error.code` is a stable identifier to branch on; `error.message` is for humans.
- Exit codes: `0` ok, `1` git failed, `2` invalid usage or confirmation required.
- Every JSON test output is validated against the schema, so the contract cannot drift silently.

### Measurements

Measured with Ruby 3.3.2 and the installed gem 0.4.0:

| Measurement | Time |
| --- | --- |
| `gitflash help` | ~0.35 s |
| `ruby -e 1` (Ruby startup alone) | ~0.29 s |
| `require 'tty-prompt'` | ~136 ms, only when a menu is shown |

Speed is not a problem worth solving further; a rewrite in another language is not justified by performance.

## Roadmap

### Phase 2 — Snapshots, undo and the agent hook (0.6.0)

This is the core of the positioning.

- **Snapshots.** Before any change, gitflash records:
  - the refs it will touch, as `refs/gitflash/snapshots/<id>/...`
  - uncommitted work, with `git stash create` (captures the working tree without changing it)
  - a journal entry in `.git/gitflash/journal.jsonl`
- **`undo` in every result.** Every `done` result gets an `undo` id. `gitflash undo [ID] [--list] [--json]` restores branches, HEAD and uncommitted work.
- **`gitflash hook`**, a Claude Code `PreToolUse` hook for shell commands (and a generic form for other agents):
  - recognises destructive git commands: `reset --hard`, `clean -f`, `checkout -- .`, `restore .`, `branch -D`, `push --force`, `stash drop`/`clear`, `rebase`
  - takes a snapshot before the command runs
  - optionally blocks the command and suggests the gitflash equivalent
- **`gitflash gc --older-than 30d`** removes old snapshots.

### Phase 3 — Cleanup for parallel agent work (0.7.0)

- **Ownership.** Branches and worktrees created through gitflash, or by an agent session, are marked as agent-created (for example in git config), so cleanup can tell them apart from human work.
- **`gitflash clean`** selects merged, upstream-gone, stale and agent-created branches and removes them with snapshots.
- **Worktree management — `gitflash worktree` (alias `wt`)**, agent-first:
  - `wt list [--json]`: path, branch, HEAD, dirty state, ahead/behind, merged status, lock state, missing directory, owner.
  - `wt add [branch]`: from an existing, remote or new branch, at a configurable location (default `../<repo>.worktrees/<branch>`).
  - `wt remove` and `wt clean`: refuse dirty worktrees unless `--force`, snapshot first. `wt prune`, `wt lock`, `wt unlock`, `wt move`.
  - Agents use the absolute paths from `wt list`; no directory switching is needed.
- **Cherry-pick picker — `gitflash pick`**, useful for moving fixes between agent branches:
  1. Choose a source branch.
  2. gitflash lists the commits on it whose change is not on the current branch yet (`git log --cherry-mark --right-only HEAD...<source>`). Commits already applied are marked and not selected.
  3. Choose commits. Rows show SHA, subject, author, date and a diff summary.
  4. gitflash snapshots, then applies them oldest first (`-x` records the origin, `--no-commit` combines them).
  5. On a conflict it stops and lists the conflicted files; `pick --continue`, `--abort` and `--skip` wrap git's own commands, and `undo` returns to the starting point.
  - For agents: `gitflash pick <source> --list --json` and `gitflash pick <source> <sha>... --yes --json`.
- **Configuration.** `.gitflash.yml` in the repository and `~/.config/gitflash.yml` for protected branch patterns, the stale threshold and default flags.

### Phase 4 — Agent integrations (0.8.0)

All of them use the same JSON contract.

1. **Agent Skill.** `skills/gitflash/SKILL.md` ships in the gem and explains when to use gitflash, the envelope, the plan → `--yes` flow and `undo`. `gitflash skill install [--claude|--path DIR]` copies it into an agent's skills directory. Works in any agent that runs shell commands.
2. **MCP server — `gitflash mcp`.**
   - Uses stdio and the official `mcp` Ruby gem, loaded only when `gitflash mcp` runs.
   - Works only on the repository in its working directory; tools take no `repo_path`.
   - Read-only tools (`read_only_hint: true`): `list_branches`, `branch_report`, `list_worktrees`, `list_commits`, `list_pickable_commits`, `list_snapshots`.
   - Additive tools (`destructive_hint: false`): `add_worktree`, `cherry_pick_commits`, `cherry_pick_control`.
   - Destructive tools (`destructive_hint: true`): `delete_branches`, `reset_branch`, `remove_worktrees`, `move_worktree`, `undo`.
   - Confirmation that works in every client: a first call returns the plan and a short-lived token, a second call with the token runs it. When the client supports elicitation, the user is also asked through `create_form_elicitation`; the token flow still works when elicitation fails (the Cowork desktop app currently hangs on it, anthropics/claude-code#94806).
   - Every destructive call snapshots first, so `undo` is always available. Sampling and roots are not used (deprecated in the 2026-07-28 specification).
3. **Claude Code plugin.** `.claude-plugin/plugin.json`, an `.mcp.json` that starts `gitflash mcp`, the skill, and the hook from phase 2. Installed with `/plugin marketplace add Kleanthismits/git_flash`.

### Phase 5 — Distribution and codebase (alongside)

- **Trusted publishing:** a tag push releases the gem from GitHub Actions (`rubygems/release-gem`, `id-token: write`).
- **Dependabot** for Bundler and GitHub Actions.
- **CI:** add Ruby 3.5/head with failures allowed.
- **Code:** replace the Struct builder in `Configuration::Descriptions` with a frozen Hash or `Data`; add RBS signatures for `Repo`.
- **Shell completions** for zsh, bash and fish.

### Deferred

Human-only features that other tools already cover well:

- a stash picker
- a richer interactive checkout menu (recent-first sorting and remote branches are still useful in `branches --json`)
- a `wt switch` shell function
- a Homebrew formula

## Out of scope

- **Calling an LLM from inside gitflash** (for example, commit message generation): it needs API keys, duplicates what agents already do, and MCP sampling is deprecated.
- **Generic git access** (add, commit, diff, push): agents already have git itself and several MCP servers for it.
- **A rewrite in Go or Rust for speed:** measured overhead is under 150 ms.

## Sources

- [Official MCP Ruby SDK (GitHub)](https://github.com/modelcontextprotocol/ruby-sdk) and [documentation](https://ruby.sdk.modelcontextprotocol.io/)
- [MCP specification 2025-11-25: Tools](https://modelcontextprotocol.io/specification/2025-11-25/server/tools)
- [Tool annotations as risk vocabulary (MCP blog)](https://blog.modelcontextprotocol.io/posts/2026-03-16-tool-annotations/)
- [The 2026-07-28 specification (MCP blog)](https://blog.modelcontextprotocol.io/posts/2026-07-28/)
- [SEP-2577: Deprecate roots, sampling and logging](https://modelcontextprotocol.io/seps/2577-deprecate-roots-sampling-and-logging)
- [Official Git MCP server](https://github.com/modelcontextprotocol/servers/tree/main/src/git)
- [selfagency/git-mcp](https://github.com/selfagency/git-mcp)
- [agentjj](https://github.com/2389-research/agentjj)
- [GitButler AI integration](https://docs.gitbutler.com/features/ai-integration/ai-overview)
- [jj (Jujutsu)](https://github.com/jj-vcs/jj) and [jj for AI coding agents](https://www.panozzaj.com/blog/2025/11/22/avoid-losing-work-with-jujutsu-jj-for-ai-coding-agents/)
- [Claude Code checkpointing](https://code.claude.com/docs/en/checkpointing)
- [anthropics/claude-code#94806: Cowork elicitation hang](https://github.com/anthropics/claude-code/issues/94806)
- [Agent Skills overview (Claude docs)](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview)
- [Agent Skills open standard across agents](https://codex.danielvaughan.com/2026/05/05/agent-skills-open-standard-portable-skills-codex-cli-cross-agent/)
- [Claude Code plugins reference](https://code.claude.com/docs/en/plugins-reference)
- [Git worktrees for parallel AI coding agents](https://nimbalyst.com/blog/git-worktrees-for-ai-coding-agents-complete-guide/)
- [RubyGems trusted publishing](https://guides.rubygems.org/trusted-publishing/releasing-gems)
