# gitflash roadmap (0.5 → 1.0)

This roadmap comes from a discovery done after the 0.4.0 release. The goals: make gitflash more useful, keep it fast, modernize it, and make it usable by today's LLM coding agents. Each finding below was measured on the code or checked against a source. Sources are listed at the end.

## Where gitflash stands today

gitflash 0.4.0 is a Thor + tty-prompt CLI with three interactive commands: `checkout`, `delete` and `reset`.

### Agents cannot use it

Every command needs a TTY menu. Commands take no arguments, have no `--yes` flag, and produce no machine-readable output. An agent that runs shell commands cannot pick a branch or answer a confirmation prompt. This is the main blocker. It also blocks an MCP server, because MCP tools need the same non-interactive core.

### Performance is fine

Measured with Ruby 3.3.2 and the installed gem:

| Measurement | Time |
| --- | --- |
| `gitflash help` | ~0.35 s |
| `ruby -e 1` (Ruby startup alone) | ~0.29 s |
| `require 'tty-prompt'` | ~136 ms |
| `require 'thor'` | ~33 ms |
| `require 'zeitwerk'` | ~27 ms |

- tty-prompt is loaded even for `help` and `version`. Loading it only when a menu is shown removes the biggest part of gitflash's own overhead.
- `checkout` starts 4 git processes (`rev-parse`, `for-each-ref` twice, `branch --show-current`). One `for-each-ref` call using `%(HEAD)` can replace three of them.
- A rewrite in another language, or YJIT, would not make a noticeable difference for a short-lived CLI.

### Gaps in usefulness

- `delete` always force-deletes (`git branch -D`). It shows nothing that helps decide what is safe to delete: no merged status, no "upstream gone", no last-commit date, no ahead/behind counts.
- Protected branches are hard-coded as `main` and `master`. The repository's real default branch (`origin/HEAD`) is not detected.
- `checkout` lists local branches alphabetically. It does not sort by recent use, does not include remote-only branches, and shows no preview.
- `reset` has no `--soft` option and no undo. Recovering from a mistaken `reset --hard` needs manual `git reflog` work.
- There are no commands for worktrees, cherry-picking, stashes or undo.

## Ecosystem research

- **Official MCP Ruby SDK** ([`mcp` gem](https://github.com/modelcontextprotocol/ruby-sdk), v1.6.0):
  - Stable 1.x API, Ruby >= 2.7, and a single runtime dependency (`json_schemer`).
  - Supports stdio transport, tool annotations (`read_only_hint`, `destructive_hint`, `idempotent_hint`, `open_world_hint`), `output_schema` for structured results, form elicitation (`server_context.create_form_elicitation`), prompts and resources.
- **MCP specification 2026-07-28**:
  - The protocol core is now stateless and adds multi round-trip requests.
  - Sampling and roots are deprecated (SEP-2577), so gitflash should not depend on them. Elicitation remains supported.
- **Elicitation in Claude Code**:
  - Supported since Claude Code 2.1.76.
  - The Cowork desktop app has an open bug where elicitation confirmations hang (anthropics/claude-code#94806). Elicitation cannot be the only way to confirm an action.
- **Tool annotations are hints only.** Clients must treat them as untrusted, so real safety has to be enforced inside the server.
- **Official `mcp-server-git`**:
  - The Python reference server offers generic tools: status, diff, add, commit, reset, log, branch and checkout.
  - Every tool takes a `repo_path`, and the server has no guardrails.
  - gitflash should not copy it. Its niche is safe, opinionated branch and worktree hygiene, with previews and undo.
- **Agent Skills** (`SKILL.md`) became an open standard in December 2025 (agentskills.io).
  - More than 30 agents read it, including Claude Code, Codex, Cursor, Gemini CLI and GitHub Copilot.
  - It is the cheapest way to teach any agent to use a CLI.
- **Claude Code plugins** bundle skills and an `.mcp.json` into one installable unit. They are distributed through a git-repository marketplace.
- **Parallel agents rely on git worktrees.**
  - Claude Code (`--worktree`), Cursor 2026.1 and JetBrains 2026.1 all create worktrees.
  - Stale worktrees and branches pile up. This is a growing problem that fits gitflash's purpose.
- **RubyGems trusted publishing** (GitHub OIDC with the `rubygems/release-gem` action) releases from CI. It removes the local `rake release` step, stored API keys and SSH problems.

## Roadmap

### Phase 1 — Non-interactive core and `--json` (0.5.0)

Everything else depends on this phase.

- **Service layer.** Extract a `Gitflash::Repo` layer from `Git::Wrapper`. It is plain Ruby and returns data objects built with `Data.define`. The CLI, JSON output, the Agent Skill and the MCP server all use it.
- **Rich branch records** from a single `for-each-ref` call:
  - name, current or not, upstream, whether the upstream is gone
  - ahead/behind counts, last commit date, subject and author
  - whether the branch is merged into the default branch
- **Default branch detection.** Use `git symbolic-ref refs/remotes/origin/HEAD`, falling back to `main` or `master`.
- **Arguments on every command**, so menus can be skipped:
  - `gitflash checkout feat-x`
  - `gitflash delete a b --yes`
  - `gitflash reset <sha> [--soft|--hard] --yes`
- **New read-only command:** `gitflash branches [--merged|--stale DAYS|--gone] [--json]`.
- **Global flags `--json`, `--dry-run` and `--yes`.**
  - `--json` output has a stable, versioned schema (`schema: 1`).
  - Menus appear only when stdin is a TTY.
  - Without a TTY and without `--yes`, destructive commands print what they would do and exit with code 2.
- **Safer delete.** `delete` uses `git branch -d` by default. `--force` switches to `-D`.
- **Faster startup.** Load tty-prompt only when a menu is shown.

### Phase 2 — Safety net: snapshots and undo (0.6.0)

This is what sets gitflash apart from other tools.

- **Snapshots.** Before any destructive operation, gitflash writes a backup ref (for example `refs/gitflash/backup/<timestamp>/<branch>`). It also appends a record to `.git/gitflash/journal.jsonl`.
- **Undo.** `gitflash undo [--list] [--json]` restores the last operation: it recreates deleted branches and moves HEAD back after a reset. It also reads `git reflog` to cover actions done outside gitflash.
- **Cleanup of backups.** `gitflash gc --older-than 30d` removes old backup refs.
- **Why it matters.** Agents make mistakes. A single undo command makes it acceptable to let an agent delete branches or reset.

### Phase 3 — Features people need (0.7.0)

#### Branch cleanup

`gitflash clean` shows one screen with merged, upstream-gone and stale branches preselected. The chosen branches are deleted, with snapshots taken first.

#### Worktree management — `gitflash worktree` (alias `wt`)

This supports parallel-agent workflows directly.

- `wt list [--json]` shows each worktree's path, branch, HEAD commit, dirty/clean state, ahead/behind counts, merged status, lock state, and whether its directory is missing.
- `wt add [branch]` creates a worktree from an existing branch, a remote branch or a new branch name. The location is configurable, with `../<repo>.worktrees/<branch>` as the default.
- `wt switch` lets you pick another worktree and go to it. A program cannot change its parent shell's directory, so there are three modes:
  1. `gitflash wt path <name>` prints the path, for use as `cd "$(gitflash wt path <name>)"`.
  2. `gitflash shell-init zsh|bash|fish` installs a small `gf` shell function. It runs the picker and then changes directory, the same way zoxide works.
  3. `--open` opens a new terminal tab or `$EDITOR` in the chosen worktree.
- `wt move <worktree> <new-path>` moves a worktree's directory (`git worktree move`).
- `wt remove` removes several worktrees at once. It refuses to remove a worktree with uncommitted changes unless `--force` is given, and it takes snapshots first.
- `wt clean` preselects merged, orphaned and missing worktrees.
- `wt prune`, `wt lock` and `wt unlock` wrap the matching git commands.

#### Cherry-pick picker — `gitflash pick`

1. Select a source branch. Branches are sorted by recent use; local and remote branches are both included.
2. gitflash lists the commits on the source branch that are not on the current branch (`git log --cherry-mark --right-only HEAD...<source>`). A commit whose change already exists on the current branch is marked "already applied" and is not selected.
3. Select one or more commits. Each row shows the short SHA, subject, author, date and a diff summary. The list can be filtered by typing.
4. Review the selection and confirm. gitflash takes a snapshot (Phase 2).
5. The commits are applied oldest first with `git cherry-pick`. `-x` records the original commit in the message. `--no-commit` combines the changes into one uncommitted change.
6. On a conflict, gitflash stops and lists the conflicted files.
   - `gitflash pick --continue`, `--abort` and `--skip` wrap git's own cherry-pick commands.
   - `gitflash undo` returns to the state before the pick.

For scripts and agents: `gitflash pick <source> <sha>... [--yes] [--json]`, and `gitflash pick <source> --list --json` to list the commits that can be picked.

#### Other improvements

- `checkout` sorts branches by recent use (`--sort=-committerdate`). It includes remote-only branches and creates a tracking branch for them. Each row shows the last commit and ahead/behind counts.
- `gitflash stash` lets you pick a stash to apply, pop or drop, with a diff summary preview.
- Configuration files: `.gitflash.yml` in the repository and `~/.config/gitflash.yml` for the user. They hold protected-branch patterns, the stale threshold and default flags.

### Phase 4 — LLM integration (0.8.0)

#### 1. Agent Skill

This is the lowest-cost option, and it works in any agent that can run shell commands.

- The gem ships `skills/gitflash/SKILL.md`. It explains:
  - when to use gitflash
  - the `--json` schemas
  - the dry-run, then `--yes` flow
  - how to use `undo`
- `gitflash skill install [--claude|--path DIR]` copies the skill to `~/.claude/skills/` or to another agent's skills directory.

#### 2. MCP server — `gitflash mcp`

- **Setup.** The server uses stdio and the official `mcp` gem. The gem is a runtime dependency but is loaded only when `gitflash mcp` runs.
- **Scope.** The server works only on the repository in its working directory. Tools take no `repo_path` argument, which is safer than `mcp-server-git`.
- **Read-only tools** (`read_only_hint: true`). Each defines an `output_schema` and returns structured results.
  - `list_branches`
  - `branch_report` (merged, stale, gone)
  - `list_worktrees`
  - `list_commits`
  - `list_pickable_commits` (commits on a source branch that are not yet on HEAD, with "already applied" marks)
  - `list_backups`
- **Additive tools** (`destructive_hint: false`):
  - `add_worktree`
  - `cherry_pick_commits`. Conflicts come back as a structured status, and the agent then calls `cherry_pick_control` with continue or abort.
- **Destructive tools** (`destructive_hint: true`):
  - `delete_branches`, `reset_branch`, `remove_worktrees`, `move_worktree`, `undo`
- **No `wt switch` tool.** Agents have no shell directory to change. `list_worktrees` returns absolute paths, which agents use directly.
- **Two-step confirmation that works in every client:**
  1. A call without a `confirm_token` returns a dry-run plan and a short-lived token.
  2. A second call with that token runs the operation.
  - If the client supports elicitation, the server also asks the user through `create_form_elicitation`.
  - If elicitation fails or is not supported, the token flow still works. This avoids the Cowork hang.
- **Undo is always possible.** Every destructive call takes a snapshot (Phase 2).
- **Guided workflows** as MCP prompts: `cleanup_branches` and `recover_lost_work`.
- **Not used:** sampling and roots, because both are deprecated.

#### 3. Claude Code plugin and marketplace

The repository gets a `.claude-plugin/plugin.json`, an `.mcp.json` that starts `gitflash mcp`, and the `skills/` folder. Users install everything with `/plugin marketplace add Kleanthismits/git_flash`.

### Phase 5 — Modern distribution and codebase

This phase can run alongside the others.

- **Trusted publishing.** Pushing a tag triggers a GitHub Actions workflow that runs `rubygems/release-gem` with `id-token: write`. This replaces the local `rake release`.
- **Dependabot** for Bundler and GitHub Actions updates.
- **CI:** add Ruby 3.5/head, with failures allowed.
- **Code cleanup:**
  - Replace the Struct builder in `Configuration::Descriptions` with a frozen Hash or `Data`.
  - Add RBS type signatures for the `Repo` layer.
- **Shell completions** for zsh, bash and fish, generated from the Thor commands (`gitflash completion zsh`). They ship together with `shell-init`, so one line in `.zshrc` enables both.
- **Homebrew** tap formula for users who do not have Ruby set up.
- **Integration tests** against real temporary repositories (`Dir.mktmpdir` + `git init`), alongside the existing stubbed unit specs.

## Out of scope

- **Calling an LLM from inside gitflash** (for example, to generate commit messages). It would need API keys, it duplicates what agents already do, and MCP sampling is deprecated.
- **Copying the generic tools of `mcp-server-git`** (add, commit, diff). Agents already have them.
- **Rewriting in Go or Rust for speed.** The measured overhead is under 150 ms.

## Files affected in later phases

- `lib/gitflash/git/wrapper.rb`: becomes, or feeds, `lib/gitflash/repo.rb` and its data records.
- `lib/gitflash/cli.rb`: arguments, `--json`/`--yes`/`--dry-run`, new commands.
- New subcommands: `lib/gitflash/cli/worktree.rb` (`wt`), `lib/gitflash/cli/pick.rb`.
- New shell-init scripts: `lib/gitflash/shell_init/{zsh,bash,fish}`.
- `lib/gitflash/prompt.rb`: loaded only when a menu is needed.
- MCP server: `lib/gitflash/mcp/server.rb` and `lib/gitflash/mcp/tools/*.rb`.
- Agent integration files: `skills/gitflash/SKILL.md`, `.claude-plugin/plugin.json`, `.mcp.json`.

## Sources

- [Official MCP Ruby SDK (GitHub)](https://github.com/modelcontextprotocol/ruby-sdk) and [documentation](https://ruby.sdk.modelcontextprotocol.io/)
- [The official Ruby SDK for MCP reaches 1.0](https://blog.modelcontextprotocol.io/posts/ruby-sdk-1-0/)
- [MCP specification 2025-11-25: Tools](https://modelcontextprotocol.io/specification/2025-11-25/server/tools)
- [Tool annotations as risk vocabulary (MCP blog)](https://blog.modelcontextprotocol.io/posts/2026-03-16-tool-annotations/)
- [The 2026-07-28 specification (MCP blog)](https://blog.modelcontextprotocol.io/posts/2026-07-28/)
- [SEP-2577: Deprecate roots, sampling and logging](https://modelcontextprotocol.io/seps/2577-deprecate-roots-sampling-and-logging)
- [Official Git MCP server](https://github.com/modelcontextprotocol/servers/tree/main/src/git)
- [Claude Code changelog](https://code.claude.com/docs/en/changelog)
- [anthropics/claude-code#94806: Cowork elicitation hang](https://github.com/anthropics/claude-code/issues/94806)
- [Agent Skills overview (Claude docs)](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview)
- [Agent Skills open standard across agents](https://codex.danielvaughan.com/2026/05/05/agent-skills-open-standard-portable-skills-codex-cli-cross-agent/)
- [Claude Code plugins reference](https://code.claude.com/docs/en/plugins-reference)
- [Git worktrees for parallel AI coding agents](https://nimbalyst.com/blog/git-worktrees-for-ai-coding-agents-complete-guide/)
- [RubyGems trusted publishing](https://guides.rubygems.org/trusted-publishing/releasing-gems)
