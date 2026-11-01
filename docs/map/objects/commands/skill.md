---
type: object
cluster: commands
universe: live
status: verified
entity: lib/gitflash/commands/skill_install.rb
verified_on: 2026-10-31
verified_at: 99b6cb1 plus the skill commands (phase 4)
---

# Agent Skill

The `SKILL.md` that teaches agents to use gitflash, and the commands that print and install it. Code: `SkillCli` (`gitflash skill`), `Commands::SkillInstall`; the skill itself is `skills/gitflash/SKILL.md`.

## Why this shape

One Markdown file works in every agent that runs shell commands and reads skills, with nothing to start. It ships in the gem so `skill install` copies the version that matches the installed CLI.

## Shape

- `skills/gitflash/SKILL.md`: frontmatter `name: gitflash` and `description` (when an agent should load it), then rules, the envelope, confirmation, a command table, protected branches, parallel work and recovery. Its claims must match [[json-schema]], [[exit-codes]] and the commands.
- `skill show` prints the file outside the envelope, like `schema` (`lib/gitflash/skill_cli.rb`).
- `skill install` targets: `--scope user` (default) `~/.claude/skills/gitflash/SKILL.md`, `--scope project` `<toplevel>/.claude/skills/gitflash/SKILL.md`, `--path DIR` `DIR/gitflash/SKILL.md` (`SkillInstall#target`). `--path` with `--scope` and a `--path` that is not a directory are `invalid_options`. Only the project scope needs a repository.
- Same content: `noop`. No file: written. A different file (older version or the user's edits): irreversible, `Ui#confirm?(irreversible: true)`, so `--yes` is not enough and `--confirm TOKEN` is needed. The plan holds `previous_sha256`, so a token never confirms other file contents (`SkillInstall#replace`).
- Project scope refuses a symbolic link at `.claude`, `.claude/skills`, `.claude/skills/gitflash` or the file (`refuse_symlinks!`), as [[hook-install]] does. The user scope and `--path` follow links.
- Writes with `Gitflash::AtomicFile`. Read and write failures are `failed` (exit 1).
- Plan and result: [[json-schema]] `skill_install` (`scope` user/project/path, `directory`, `file`, `version`, `previous_sha256`).

## Connected to

- **owned-by:** [[cli]] (`skill` subcommand)
- **joins:** [[change-flow]] (dry run, irreversible confirm), [[ui-output]], [[json-schema]], [[command-runner]] (`repo_required:` only for project)
- **looks-like-but-is-not:** [[hook-install]]. The hook changes what Claude Code runs; the skill only tells an agent what to run.

## If you change this

- **Hits:** `gitflash.gemspec` file list (`skills/gitflash/SKILL.md`), `SkillInstall::SOURCE`; any command, flag, field or error code named in `SKILL.md`; `spec/lib/gitflash/cli_skill_spec.rb`.
- **Does not hit:** snapshots, [[repo]] beyond `toplevel`.
- **Outside-in:** agents load the installed copy, not the gem's. A changed `SKILL.md` reaches them only after `skill install` runs again.

## Surfaces

| Surface | Role |
|---|---|
| agents | read the installed `SKILL.md` |
| humans, agents | run `skill install`, `skill show` |

## See

- Source: `lib/gitflash/skill_cli.rb`, `lib/gitflash/commands/skill_install.rb`, `skills/gitflash/SKILL.md`
