# Effects: what to open before a change

Catalog, not a waterfall. Card and this file disagree: fix the card.
Verified at dde88fd on 2026-10-03.

## Inside the tree

| Changing | Open |
|---|---|
| a JSON field, status or error code | [[json-schema]], [[ui-output]], [[exit-codes]] |
| exit status | [[exit-codes]], [[command-runner]] |
| add a command | [[cli]], [[command-descriptions]], [[json-schema]] (enum plus per-command block), [[change-flow]], [[command-runner]], [[skill]] (command table in `SKILL.md`) |
| confirmation or `--yes` | [[change-flow]], [[ui-output]], [[delete]], [[reset]], [[undo]] |
| what a command snapshots | [[change-flow]] (table), the command card, [[snapshot]] scope |
| snapshot format or fields | [[snapshot]], [[snapshot-store]], [[state-capture]], [[restore]], [[json-schema]] |
| where snapshots live | [[snapshot-store]] (`REF_PREFIX`; orphans existing snapshots) |
| undo behavior | [[undo]], [[restore]], [[snapshot]] |
| retention / gc | [[snapshot-commands]], [[snapshot-store]] |
| how branch names are read from git | [[branch]] (`parse_tips`, `fields`), [[repo]], [[state-capture]], [[restore]], [[hook-claude]]: all use full refs, never `refname:short` / `--short` |
| a git call or format string | [[repo]], [[bash-command]], [[branch]] or [[commit]] |
| who created a branch (agent or human) | [[ownership]], [[mark]], [[branch]], [[worktrees]], [[json-schema]] |
| branch fields | [[branch]], [[json-schema]], [[repo]] |
| pick, its list, conflicts or control flags | [[pick]], [[cherry-pick]], [[json-schema]], [[exit-codes]], [[change-flow]] |
| what clean selects or never touches | [[cleanup]], [[clean]], [[worktree-commands]], [[config]], [[ownership]] |
| protected branches | [[delete]], [[config]] (`protected` patterns) |
| a settings key or file | [[config]], [[exit-codes]] |
| which agent commands get snapshotted | [[hook-rules]], [[hook-claude]] |
| which commands mark a branch, or what the PostToolUse hook does | [[hook-marking]], [[hook-claude]], [[hook-install]], [[ownership]] |
| hook output or modes | [[hook-claude]], [[hook-install]] (command string and `PATTERN`), [[plugin]] (same entries) |
| where the hook is installed | [[hook-install]], [[repo]] (`toplevel`, `main_root`) |
| worktree fields or `wt` commands | [[worktrees]], [[worktree-commands]], [[json-schema]] |
| what `wt remove` saves or how undo brings a worktree back | [[worktree-commands]], [[worktree-revival]], [[restore]], [[undo]], [[state-capture]] |
| a command's flags or arguments, or its dry-run plan | the command card, [[mcp]] (`Tools::ALL` argv; the token needs a stable dry-run plan) |
| MCP tools, their schema or the token flow | [[mcp]], [[json-schema]] |
| what agents are told to run | [[skill]] (`skills/gitflash/SKILL.md`), and every card it names |
| help text | [[command-descriptions]] |

## Outside the tree: things that point in

Nothing in `lib/` names these. They break silently.

| Consumer | Points at | Breaks if |
|---|---|---|
| `gitflash.gemspec:26-29` file list | `lib/**/*`, `bin/gitflash`, `command_descriptions.yml`, `schema/v1.json`, `skills/gitflash/SKILL.md` | any is moved or renamed; gem ships without it |
| `gitflash.gemspec:23` | executable `gitflash` | binary renamed |
| `.claude-plugin/plugin.json` | `gitflash hook claude`, `gitflash mcp`, `skills/`, `Gitflash::VERSION` | any is renamed or moved, or the version is bumped without it (`spec/plugin_spec.rb` fails); see [[plugin]] |
| `Mcp::Runner::BIN`, `LIB` (`lib/gitflash/mcp/runner.rb`) | `bin/gitflash`, `lib/` | either moved; every tool returns a `failed` envelope |
| `Configuration::Descriptions` (`lib/gitflash/configuration.rb:15`) | `command_descriptions.yml` one level above `lib/` | file moved |
| `Cli::SCHEMA_PATH` (`lib/gitflash/cli.rb:10`) | `schema/v1.json` | file moved |
| `schema/v1.json:3` `$id` | GitHub URL on `main` | repo or path renamed |
| README | link to `schema/v1.json` | file moved |
| `.claude/settings.local.json` (gitignored globally, one machine) | `gitflash hook claude` | command renamed or removed; hook then fails silently (exit 0). Works on this branch. |
| Claude Code hook protocol | `hookSpecificOutput`, `permissionDecision` fields | Claude changes the protocol; no error is shown |
| Claude Code settings layout | `.claude/settings*.json`, `hooks.PreToolUse` | [[hook-install]] writes the wrong shape |
| installed skill copies (`~/.claude/skills/gitflash`, `.claude/skills/gitflash`, `--path` dirs) | commands, flags and fields named in `SKILL.md` | a named command or field changes; installed copies stay old until `skill install` runs again |
| MCP clients (`claude mcp add gitflash -- gitflash mcp`, desktop configs) | `gitflash mcp`, tool names and argument names | command, tool or argument renamed; the client lists a tool that fails or none |
| user repos | `refs/gitflash/snapshots/*` | `REF_PREFIX` changes: old snapshots unreachable by `undo` |
| agents and scripts reading `--json` | JSON v1, exit codes 0/1/2, `undo.command` | any v1 field or code changes meaning |

Unknown: scripts, aliases or hooks outside this repo. Owner to confirm.

## Re-verification notes (2026-10-03)

- Error codes raised in `lib/` all appear in the `error.code` enum.
- Hook parser misses wrapped commands: see [[hook-rules]].
