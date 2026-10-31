---
type: object
cluster: commands
universe: live
status: verified
entity: lib/gitflash/mcp/server.rb
verified_on: 2026-10-31
verified_at: 1471a5a plus the MCP server (phase 4)
---

# MCP server

`gitflash mcp`: an MCP server on stdio for the repository in its working directory. Code: `Mcp::Server`, `Mcp::Tools`, `Mcp::Runner`, `Mcp::Confirmation` (`lib/gitflash/mcp/`). Not the `MCP` constant, which is the `mcp` gem.

## Why this shape

Each tool runs the CLI with `--json` in a child process (`Runner`): stdout is the stdio transport, so a command printing there would break the connection, and the tools return exactly the [[json-schema]] envelope the CLI does. One contract, no second code path for commands.

## Shape

- `Cli#mcp` checks for a work tree (`Repo#ensure_work_tree!`, error to stderr, exit 1), then `Mcp::Server#start` opens `MCP::Server::Transports::StdioTransport`. `lib/gitflash/mcp/server.rb` requires `mcp`; Zeitwerk only loads it when `Gitflash::Mcp::Server` is first used, so other commands never load the gem.
- `Tools::ALL`: name, kind (`read`, `additive`, `destructive`), description, input schema properties, `argv` lambda (tool arguments to command words). Kinds map to `readOnlyHint` / `destructiveHint` / `idempotentHint`; `openWorldHint` false (`Server::ANNOTATIONS`). `additionalProperties: false`; names, SHAs and paths have pattern `^[^-]` (`Tools::NAME`), checked by the gem before the tool runs, so no argument can become an option.
- `Runner#call(argv)`: `Gem.ruby -I lib bin/gitflash ARGV --json`, in the server's directory, stdin empty (no terminal, so commands never prompt). No JSON on stdout gives a `failed` envelope with stderr.
- Read and additive tools run the command once. `cherry_pick_*` pass `--yes` themselves. `mark_branches` defaults to `--owner agent`.
- Destructive tools (`Server#destructive`): run with `--dry-run`. Status other than `planned` (noop, refusal, error) is returned as it is. Without a valid token: the preview becomes status `confirmation_required`, `ok` false, `error.code` `confirmation_required`, `error.confirm_token` = new MCP token. With one: run with `--yes`; if the command still asks for its own irreversible token ([[change-flow]], `wt remove` with ignored files) and its plan equals the confirmed plan, run again with `--confirm` that token.
- `Confirmation`: token `EXPIRES.HMAC-SHA256(secret, [tool, sorted arguments without confirm_token, plan, EXPIRES])`. Secret is 32 random bytes per server process. `TTL` 300 s. So a token is bound to the tool, its arguments, the plan the repository gives now, and this process.
- Tool response: text content = the envelope as JSON, `structuredContent` = the envelope, `isError` for status `error` / `failed` only.
- Tool blocks declare `server_context:`, so the gem does not put it into the arguments (it would change the token's arguments).

## Connected to

- **owned-by:** [[cli]] (`mcp` command)
- **joins:** every command card it wraps ([[branches]], [[delete]], [[clean]], [[reset]], [[undo]], [[worktree-commands]], [[pick]], [[mark]], [[snapshot-commands]]); [[json-schema]] (envelope, `error.confirm_token`); [[change-flow]] (`--dry-run`, `--yes`, `--confirm`)
- **looks-like-but-is-not:** the CLI's own `--confirm` token (`Ui.confirm_token`, a hash of the plan, for changes undo cannot revert). The MCP token is an HMAC and covers every destructive tool.

## If you change this

- **Hits:** a command's flags or positional arguments (its `argv` lambda); a command whose dry-run plan is not stable between two runs (the token never matches); envelope fields; `README.md` tool table, `skills/gitflash/SKILL.md` MCP note; `spec/lib/gitflash/mcp/server_spec.rb`.
- **Does not hit:** snapshots and git access directly; all of that happens in the child process.
- **Outside-in:** MCP clients read tool names, input schemas and annotations. Renaming a tool or argument breaks client configs and agent prompts silently.

## Surfaces

| Surface | Role |
|---|---|
| MCP clients (Claude Code, Claude Desktop) | start `gitflash mcp`, call tools |
| humans | approve plans the agent shows |

## See

- Source: `lib/gitflash/mcp/{server,tools,runner,confirmation}.rb`, `lib/gitflash/cli.rb` (`mcp`)
