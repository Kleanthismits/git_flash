# Review instructions

For anyone reviewing a pull request in this repository: an AI reviewer, a review agent, or a person. The author's rules, the description sections and the risk tiers are in [`docs/pull-requests.md`](docs/pull-requests.md). This file does not repeat them.

gitflash is a safety net for git repositories that AI agents work in. Review against that purpose.

## First question

Does the change belong in gitflash? Check it against `docs/ROADMAP.md`. If it does not belong, say so in the summary and stop. A line-by-line review of a change that should not merge wastes both sides' time.

## What a failure looks like here

Look for these first, in this order:

1. **Lost work.** A path where a branch, commit, worktree or untracked file is removed with no snapshot taken first, or where the snapshot cannot restore it.
2. **A silent safety net.** The hook lets a destructive command through with no snapshot. `hook claude` exits 0 even when it fails. In `snapshot` mode the command then runs with no snapshot and the user sees nothing. In `ask` and `deny` mode a failure must still write an ask or deny decision, or exit 2 when no decision can be written. A change that breaks either lets the command run unprotected. See `docs/map/objects/hooks/hook-claude.md`.
3. **A broken contract.** A field, status, error code or exit code in `schema/v1.json` changes meaning, or the output of a command no longer matches the schema. Exit codes are defined in `docs/map/objects/contract/exit-codes.md`.
4. **A skipped confirmation.** A destructive command runs without `--yes` or a prompt, or a dry run changes something.
5. **Untrusted input trusted.** Branch names, paths, settings files and shell text come from the repository or from an agent. Look for short ref names where full refs are required, followed symlinks, unescaped terminal text, and patterns that can backtrack.
6. **A stale map.** A change under `lib/` or `schema/` with no update to the cards listed in `docs/map/effects/CONTEXT.md`.
7. **A stale consumer.** A renamed command, flag or field that something in the "Outside the tree" table of `docs/map/effects/CONTEXT.md` still names.
8. **A weaker check.** A spec example removed or skipped, a coverage threshold lowered, a RuboCop rule disabled, or a CI step dropped.

For a bug fix, check that the fix reaches the root cause and that the same bug does not exist in a sibling command.

## What to check in the description

- Every section of the template is filled.
- The risk tier matches the paths the diff touches.
- The evidence is real: commands with their results, and command output for a behavior change. If you cannot say what the checks would miss, say so and ask for more.
- A high tier change carries the evidence its tier asks for.

## What to leave out

- Style that RuboCop accepts.
- Refactors, renames and "consider" suggestions that fix no defect.
- The twin files `AGENTS.md`, `docs/map/AGENTS.md` and `docs/map/routing.md`. They are copies; review the source file.
- A finding you already posted in an earlier round.

At most three nits per review. If there are more, post the three that matter most.

## How to report

- Start the summary with a count: "2 important, 1 nit, 1 pre-existing". If there is nothing to fix, say "Nothing to fix" and stop.
- Tag every finding **Important**, **Nit** or **Pre-existing**. Pre-existing means the defect was there before this pull request. Do not ask the author to fix it here.
- Give every finding a file and line, the input or state that triggers it, and the wrong result.
- When one finding is an instance of a pattern, name the pattern and list the other places, so the author fixes all of them in one round.
- After the first round, review only the new commits. When the round limit is reached and findings still arrive, tell the author to reconsider the approach instead of listing more.
