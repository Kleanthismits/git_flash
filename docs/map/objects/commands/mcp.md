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

`gitflash mcp`: an MCP server on stdio for the repository in its working directory. Code: `Mcp::Server`, `Mcp::Tools`, `Mcp::Runner`, `Mcp::Confirmation`, `Mcp::Elicitation`, `Mcp::PlanChange` (`lib/gitflash/mcp/`). Not the `MCP` constant, which is the `mcp` gem.

## Why this shape

Each tool runs the CLI with `--json` in a child process (`Runner`): stdout is the stdio transport, so a command printing there would break the connection, and the tools return exactly the [[json-schema]] envelope the CLI does. One contract, no second code path for commands.

## Shape

- `Cli#mcp` starts outside a repository too (a [[plugin]] server starts in every session); tools then answer with `not_a_repository` from the child process. `Mcp::Server#start` opens `MCP::Server::Transports::StdioTransport`. `lib/gitflash/mcp/server.rb` requires `mcp`; Zeitwerk only loads it when `Gitflash::Mcp::Server` is first used, so other commands never load the gem.
- `Tools::ALL` = `COMMANDS` plus `PLAN` (`plan_change`): name, kind (`read`, `additive`, `destructive`, `plan`), description, input schema properties, `argv` lambda (tool arguments to command words). Kinds map to `readOnlyHint` / `destructiveHint` / `idempotentHint`; `openWorldHint` false (`Server::ANNOTATIONS`). `additionalProperties: false`; names, SHAs and paths have pattern `^[^-]` (`Tools::NAME`), checked by the gem before the tool runs, so no argument can become an option.
- `Runner#call(argv)`: `Gem.ruby -I lib bin/gitflash ARGV --json`, in the server's directory, stdin empty (no terminal, so commands never prompt). No JSON on stdout gives a `failed` envelope with stderr.
- Read and additive tools run the command once. `cherry_pick_*` pass `--yes` themselves. `mark_branches` defaults to `--owner agent`.
- Destructive tools (`Server#destructive`): run with `--dry-run`. Status other than `planned` (noop, refusal, error) is returned as it is. A valid token runs the change. Without a token, `Elicitation#ask` (`Server#approve`): approved runs the change, declined returns the preview with status `cancelled` and no token. A token that does not fit is never followed by a question. When the user cannot be asked: the preview becomes status `confirmation_required`, `ok` false, `error.code` `confirmation_required`, `error.confirm_token` = new MCP token. With one: run with `--yes`; if the command still asks for its own irreversible token ([[change-flow]], `wt remove` with ignored files) and its plan equals the confirmed plan, run again with `--confirm` that token.
- `Confirmation`: token `EXPIRES.HMAC-SHA256(secret, [tool, sorted arguments without confirm_token, plan, EXPIRES])`. Secret is 32 random bytes per server process. `TTL` 300 s. So a token is bound to the tool, its arguments, the plan the repository gives now, and this process.
- `plan_change` (`PlanChange`): read-only annotations. Its `arguments` is only typed `object` for the client, so it validates them with `json_schemer` against `Tools.input_schema(target)` (no `confirm_token` allowed), else `invalid_options` exit 2 with `command` `gitflash`. Then dry run and `Confirmation#required`: the same envelope and token a first destructive call gives, valid for that tool with those arguments in any order (arguments are sorted before signing). Exists because Claude Code asks before every non-read-only tool call: the plan step then costs no prompt.
- `Confirmation#required` builds the `confirmation_required` envelope for both paths.
- Two ways to ask (`Elicitation#ask`, picked by `context.modern?`). Legacy (`initialize`): `direct` sends `elicitation/create` through the stdio transport. 2026-07-28 (per-request `_meta` envelope; Claude Code uses it): the transport refuses server requests (SEP-2575), so `form` returns `MCP::Server::InputRequiredResult` with input `confirm` (the form) and `request_state` = a `Confirmation` token signed for `form:TOOL` with the arguments and plan. The client retries the call with `inputResponses.confirm` and the state; `Server#elicited` checks the state against the current plan (`fits:`) and `Elicitation#answer` reads the answer. Signing for `form:TOOL` keeps the state from working as a `confirm_token`. A client whose capabilities lack form elicitation (`missing_client_capabilities`, e.g. url-only) gets the token instead, since the gem would refuse the result.
- `Elicitation`: only when the client declared `elicitation` and the server runs without `--no-elicitation` (`Cli#mcp`). One form, optional boolean `confirm` with default true (`SCHEMA`; a required box made Claude Code refuse Accept until it was ticked); Accept is a yes unless `confirm` is false; decline, cancel and a cleared box are a no; an error, an unknown answer or no answer in `TIMEOUT` (120 s, `Timeout.timeout` around the stdio transport's blocking read; legacy only) is nil, so the token flow follows; each nil with a context writes the reason to stderr (`LOG`, injectable) as `gitflash mcp: TOOL: not asking the user, REASON; using the confirm_token`. No context (calls from Ruby) asks nothing and logs nothing. The message shows the plan as one line of JSON (Claude Code folds further lines) through `TerminalText.safe`, cut at 4000 characters.
- Tool response: text content = the envelope as JSON, `structuredContent` = the envelope, `isError` for status `error` / `failed` only.
- Tool blocks declare `server_context:` and pass it to `Server#call` as `context`: the gem then keeps it out of the arguments (it would change the token's arguments), and elicitation goes through it. The block returns an `InputRequiredResult` as it is, an envelope wrapped in a `Response`.

## Connected to

- **owned-by:** [[cli]] (`mcp` command)
- **joins:** every command card it wraps ([[branches]], [[delete]], [[clean]], [[reset]], [[undo]], [[worktree-commands]], [[pick]], [[mark]], [[snapshot-commands]]); [[json-schema]] (envelope, `error.confirm_token`); [[change-flow]] (`--dry-run`, `--yes`, `--confirm`)
- **looks-like-but-is-not:** the CLI's own `--confirm` token (`Ui.confirm_token`, a hash of the plan, for changes undo cannot revert). The MCP token is an HMAC and covers every destructive tool.

## If you change this

- **Hits:** a command's flags or positional arguments (its `argv` lambda); a command whose dry-run plan is not stable between two runs (the token never matches); envelope fields; `README.md` tool table, `skills/gitflash/SKILL.md` MCP note; `spec/lib/gitflash/mcp/{server,elicitation}_spec.rb`.
- **Does not hit:** snapshots and git access directly; all of that happens in the child process.
- **Outside-in:** MCP clients read tool names, input schemas and annotations. Renaming a tool or argument breaks client configs and agent prompts silently.

## Surfaces

| Surface | Role |
|---|---|
| MCP clients (Claude Code, Claude Desktop) | start `gitflash mcp`, call tools |
| humans | approve plans the agent shows |

## See

- Source: `lib/gitflash/mcp/{server,tools,runner,confirmation,elicitation,plan_change}.rb`, `lib/gitflash/cli.rb` (`mcp`)
