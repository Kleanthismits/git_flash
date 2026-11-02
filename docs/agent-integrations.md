# Agent integrations

gitflash reaches AI coding agents in four ways. The MCP server and the skill use the same [JSON contract](json-contract.md) as the CLI; the hook speaks Claude Code's own hook protocol.

| Integration | What it does |
| --- | --- |
| [Hook](#hook) | Snapshots the repository before Claude Code runs a destructive plain git command, and marks branches the agent creates |
| [Claude Code plugin](#claude-code-plugin) | Installs the hook, the MCP server and the skill in one step |
| [Agent Skill](#agent-skill) | Tells an agent when to use gitflash instead of plain git, and how to read its output |
| [MCP server](#mcp-server) | Serves gitflash as MCP tools, with approval for destructive changes |

## Hook

Agents often run git directly. Claude Code's own checkpoints do not cover changes made by shell commands, so a `git reset --hard` or `git clean -fd` run by an agent cannot be rewound there. Install the gitflash hook once per repository:

```bash
gitflash hook install
```

Before Claude Code runs a command that can discard work git cannot restore (`reset`, `checkout -- .`, `restore`, `clean -f`, `branch -D`, `stash drop`, `rebase`, `worktree remove --force`, ...), the hook saves a snapshot and tells the agent how to undo it. Other commands pass through; the hook adds about 0.1 s to commands that do not mention git. `--mode ask` also asks you to approve such commands, `--mode deny` blocks them. If the hook itself fails, `ask` mode still asks and `deny` mode blocks the command.

The same install adds a second hook that runs after a command: when the agent creates a branch with plain git (`git checkout -b`, `git switch -c`, `git branch NAME`, `git worktree add`), gitflash marks it as agent work, so `gitflash clean --agent` can find it. Only new, unmarked branches are marked, and `gitflash mark BRANCH --owner human` changes it. If you installed the hook with an earlier version, run `gitflash hook install` again to add it (the installed `--mode` is kept; a weaker mode needs `--downgrade`); `gitflash hook status` says whether branch marking is on.

Where the hook goes, following Claude Code's own rules:

| Scope | File | Applies to |
| --- | --- | --- |
| `local` (default) | `.claude/settings.local.json` at the repository root (the main checkout's root inside a worktree) | Sessions anywhere in the repository and its worktrees |
| `project` | `.claude/settings.json` at the repository top level, to share with your team | Sessions started in that directory |
| `user` | `~/.claude/settings.json` | Every session |

Claude Code reloads settings files, so running sessions pick the hook up without a restart. Run `gitflash hook status` in the directory where you start Claude Code to check which files apply and whether the `gitflash` executable is found.

## Claude Code plugin

The plugin brings the hook, the MCP server and the skill to Claude Code in one install. It runs the `gitflash` command, so install the gem first (`gem install gitflash --pre` for 0.8.0.beta1; version 0.8.0 or newer once it is released), then in Claude Code:

```
/plugin marketplace add Kleanthismits/git_flash
/plugin install gitflash@gitflash
```

On Claude Code 2.1.275 or later one line does both: `/plugin install gitflash --marketplace Kleanthismits/git_flash`.

The plugin's hook runs in `snapshot` mode for every session. Do not also run `gitflash hook install`, or the hook runs twice; if you want `ask` or `deny` mode, use `gitflash hook install --mode ask` instead of the plugin, or disable the plugin's hooks. `gitflash hook status` only reads settings files, so it does not report the plugin's hook.

## Agent Skill

gitflash ships an [Agent Skill](../skills/gitflash/SKILL.md): one `SKILL.md` that tells an agent when to use gitflash instead of plain git, how to read the `--json` envelope, the plan then `--yes` flow, `--confirm` tokens and how to recover work with `gitflash undo`. Install it once:

```bash
gitflash skill install
```

| Option | File | Read by |
| --- | --- | --- |
| `--scope user` (default) | `~/.claude/skills/gitflash/SKILL.md` | Every Claude Code session |
| `--scope project` | `.claude/skills/gitflash/SKILL.md` at the repository top level, to commit for your team | Claude Code sessions in the repository |
| `--path DIR` | `DIR/gitflash/SKILL.md` | Any agent that reads skills from `DIR` |

Run it again after upgrading gitflash. When the installed file differs from the shipped one (for example because you edited it), replacing it needs `--confirm TOKEN` instead of `--yes`, since `gitflash undo` cannot bring your edits back. `gitflash skill show` prints the shipped file.

## MCP server

`gitflash mcp` serves gitflash to MCP clients (Claude Code, Claude Desktop, other agents) over stdio, for the repository in the directory it starts in. Register it in Claude Code from inside the repository:

```bash
claude mcp add gitflash -- gitflash mcp
```

Every tool answers with the same JSON envelope as `--json`, as structured content.

| Kind | Tools |
| --- | --- |
| Read-only | `list_branches`, `list_worktrees`, `list_pickable_commits`, `list_snapshots`, `plan_change` |
| Lose nothing | `add_worktree`, `cherry_pick_commits`, `cherry_pick_control`, `mark_branches`, `save_snapshot` |
| Destructive | `delete_branches`, `clean_branches`, `reset_branch`, `remove_worktrees`, `move_worktree`, `undo` |

### Approval with elicitation

When the client supports MCP elicitation, a destructive tool first shows you its plan in the client and asks you to approve it. On a 2026-07-28 connection, as Claude Code makes, the form comes back as an `input_required` result and the client calls the tool again with your answer. The change runs when you press Accept (clearing the "Make this change" box first turns Accept into a no), and the tool answers `cancelled` when you decline.

If the client cannot ask, gives no answer within 2 minutes, or the server runs with `gitflash mcp --no-elicitation` (for clients that never answer), the token flow below is used, and the server writes the reason to stderr, which Claude Code keeps in its MCP logs.

### Approval with a token

Without that approval, a destructive tool changes nothing on its first call: it returns the plan with status `confirmation_required` and `error.confirm_token`. Calling it again with the same arguments and `confirm_token` makes exactly that change, after a snapshot.

`plan_change` gives the same plan and token from a read-only tool, so a client that asks before every destructive call (Claude Code outside auto mode) asks only once, for the change itself. The token is valid for 5 minutes, only for that plan (if the repository changed so the plan differs, a new plan and token come back) and only for the running server.

The tools are marked with MCP's `readOnlyHint` and `destructiveHint`, so clients can also ask you before a call. Names and paths that start with a dash are refused.
