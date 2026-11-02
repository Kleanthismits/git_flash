# JSON contract

Every gitflash command can be run by a person in a terminal or by a script or agent. Scripts and agents get one stable contract: the same JSON envelope and the same exit codes for the CLI and the MCP server, and the Agent Skill teaches agents to read it.

## Options for every command

| Option | Effect |
| --- | --- |
| `--json` | Print JSON instead of text. Never shows lists or prompts |
| `--yes`, `-y` | Skip confirmation prompts |
| `--dry-run` | Show what would happen without changing anything |

Without an argument, a command shows an interactive list. With arguments it runs directly. Run `gitflash help <command>` for details on a command.

## Without a terminal

In a script, CI or an AI coding agent, gitflash never waits for input:

- A command that needs a list selection fails with exit code 2 and says which argument to pass.
- A destructive action (`delete`, `reset --hard`) fails with exit code 2 and returns the plan unless you pass `--yes`.
- A change `gitflash undo` cannot revert (`gc`, which deletes snapshots, and `wt remove` or `wt clean` of a worktree with ignored files) is not covered by `--yes`: it fails with exit code 2 and names a token (with `--json`, the plan and `error.confirm_token`; `--dry-run` shows the plan as text). Re-run with `--confirm TOKEN` to make that exact change; in a terminal you type the token instead.

## The envelope

With `--json`, every command prints one object in the same envelope, defined in [schema/v1.json](../schema/v1.json) (also printed by `gitflash schema`):

```json
{
  "schema": 1,
  "command": "delete",
  "ok": true,
  "status": "done",
  "dry_run": false,
  "plan": { "branches": ["old-feature"], "force": false },
  "result": { "deleted": [{ "branch": "old-feature", "sha": "3551cba" }], "failed": [] }
}
```

- `status`: `done`, `planned` (`--dry-run`), `noop`, `cancelled`, `failed`, `confirmation_required` or `error`. `ok` is true for the first four.
- `result` includes what you need to revert: the SHA of each deleted branch (`git branch NAME SHA`), the previous branch after `checkout`, the previous commit after `reset`.
- `undo` names the snapshot saved before the change and the command that restores it (`gitflash undo ID`). When nothing had changed since an earlier snapshot, that one is handed back instead of saving the same state again, with `"reused": true`: its id is older than the change, and undo with it is still correct.
- `error.code` is a stable identifier such as `unknown_branch`, `protected_branch` or `confirmation_required`.

```bash
gitflash branches --merged --json
```

```bash
gitflash delete old-feature another-branch --yes --json
```

## Exit codes

| Code | Meaning |
| --- | --- |
| `0` | Success |
| `1` | A git command failed (for example a branch was not fully merged) |
| `2` | Invalid usage or confirmation required |
