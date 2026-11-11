# Review instructions

For anyone reviewing a pull request in this repository: an AI reviewer, a review agent, or a person. The author's rules are in [`docs/pull-requests.md`](docs/pull-requests.md).

gitflash is a safety net for git repositories that AI agents work in. Review against that purpose.

## What a failure looks like here

Look for these first, in this order:

1. **Lost work.** A path where a branch, commit, worktree, stash or untracked file is removed with no snapshot taken first, or where the snapshot cannot restore it.
2. **A silent safety net.** The hook lets a destructive command through with no snapshot, or fails in a way the user never sees. `hook claude` always exits 0, so a crash there is invisible.
3. **A broken contract.** A field, status, error code or exit code in `schema/v1.json` changes meaning, or the output of a command no longer matches the schema. Exit codes are 0 ok, 1 error, 2 usage or confirmation required.
4. **A skipped confirmation.** A destructive command runs without `--yes` or a prompt, or a dry run changes something.
5. **Untrusted input trusted.** Branch names, paths, settings files and shell text come from the repository or from an agent. Look for short ref names where full refs are required, followed symlinks, unescaped terminal text, and patterns that can backtrack.
6. **A stale map.** A change under `lib/` or `schema/` with no update to the cards listed in `docs/map/effects/CONTEXT.md`.
7. **A stale consumer.** A renamed command, flag or field that `skills/gitflash/SKILL.md`, `.claude-plugin/`, `Mcp::Tools` or the README still names.

For a bug fix, check that the fix reaches the root cause and that the same bug does not exist in a sibling command.

## What to check in the description

- All five sections are filled: Problem, Change, Tests, Risk, How to revert.
- The risk tier matches the paths the diff touches. See the tier table in `docs/pull-requests.md`.
- The evidence is real: commands with their results, and command output for a behavior change. If you cannot say what the checks would miss, say so and ask for more.
- A high tier change has a spec that runs against a real temporary git repository.

## What to leave out

- Style that RuboCop accepts.
- Refactors, renames and "consider" suggestions that fix no defect.
- Findings in `coverage/`, `pkg/`, `Gemfile.lock` version bumps from Dependabot, and the twin files `AGENTS.md`, `docs/map/AGENTS.md` and `docs/map/routing.md`. The twins are copies; review the source file.
- A finding you already posted in an earlier round.

At most three nits per review. If there are more, post the three that matter most.

## How to report

- Start the summary with a count: "2 important, 1 nit, 1 pre-existing". If there is nothing to fix, say "Nothing to fix" and stop.
- Tag every finding **Important**, **Nit** or **Pre-existing**. Pre-existing means the defect was there before this pull request. Do not ask the author to fix it here.
- Give every finding a file and line, the input or state that triggers it, and the wrong result.
- When one finding is an instance of a pattern, name the pattern and list the other places, so the author fixes all of them in one round.
- After the first round, review only the new commits. At the third round, if findings still arrive, tell the author to reconsider the approach instead of listing more.
