# Effects: what to open before a change

Catalog, not a waterfall. Card and this file disagree: fix the card.
Verified at dde88fd on 2026-10-03.

## Inside the tree

| Changing | Open |
|---|---|
| a JSON field, status or error code | [[json-schema]], [[ui-output]], [[exit-codes]] |
| exit status | [[exit-codes]], [[command-runner]] |
| add a command | [[cli]], [[command-descriptions]], [[json-schema]] (enum plus per-command block), [[change-flow]], [[command-runner]] |
| confirmation or `--yes` | [[change-flow]], [[ui-output]], [[delete]], [[reset]], [[undo]] |
| what a command snapshots | [[change-flow]] (table), the command card, [[snapshot]] scope |
| snapshot format or fields | [[snapshot]], [[snapshot-store]], [[state-capture]], [[restore]], [[json-schema]] |
| where snapshots live | [[snapshot-store]] (`REF_PREFIX`; orphans existing snapshots) |
| undo behavior | [[undo]], [[restore]], [[snapshot]] |
| retention / gc | [[snapshot-commands]], [[snapshot-store]] |
| a git call or format string | [[repo]], [[bash-command]], [[branch]] or [[commit]] |
| branch fields | [[branch]], [[json-schema]], [[repo]] |
| protected branches | [[delete]] |
| which agent commands get snapshotted | [[hook-rules]], [[hook-claude]] |
| hook output or modes | [[hook-claude]], [[hook-install]] (command string and `PATTERN`) |
| where the hook is installed | [[hook-install]], [[repo]] (`toplevel`, `main_root`) |
| help text | [[command-descriptions]] |

## Outside the tree: things that point in

Nothing in `lib/` names these. They break silently.

| Consumer | Points at | Breaks if |
|---|---|---|
| `gitflash.gemspec:25-27` file list | `lib/**/*`, `bin/gitflash`, `command_descriptions.yml`, `schema/v1.json` | any is moved or renamed; gem ships without it |
| `gitflash.gemspec:22` | executable `gitflash` | binary renamed |
| `Configuration::Descriptions` (`lib/gitflash/configuration.rb:15`) | `command_descriptions.yml` one level above `lib/` | file moved |
| `Cli::SCHEMA_PATH` (`lib/gitflash/cli.rb:10`) | `schema/v1.json` | file moved |
| `schema/v1.json:3` `$id` | GitHub URL on `main` | repo or path renamed |
| README | link to `schema/v1.json` | file moved |
| `.claude/settings.local.json` (gitignored globally, one machine) | `gitflash hook claude` | command renamed or removed; hook then fails silently (exit 0). Works on this branch. |
| Claude Code hook protocol | `hookSpecificOutput`, `permissionDecision` fields | Claude changes the protocol; no error is shown |
| Claude Code settings layout | `.claude/settings*.json`, `hooks.PreToolUse` | [[hook-install]] writes the wrong shape |
| user repos | `refs/gitflash/snapshots/*` | `REF_PREFIX` changes: old snapshots unreachable by `undo` |
| agents and scripts reading `--json` | JSON v1, exit codes 0/1/2, `undo.command` | any v1 field or code changes meaning |

Unknown: scripts, aliases or hooks outside this repo. Owner to confirm.

## Re-verification notes (2026-10-03)

- Error codes raised in `lib/` all appear in the `error.code` enum.
- Hook parser misses wrapped commands: see [[hook-rules]].
