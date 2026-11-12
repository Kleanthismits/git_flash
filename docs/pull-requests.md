# Pull requests

Rules for whoever opens a pull request here, person or agent. The reviewer's rules are in [`REVIEW.md`](../REVIEW.md).

Goal: the maintainer spends as little time per pull request as possible without more reverts or broken releases. Checks that a machine can run are run before the maintainer looks. The maintainer reads the evidence and the risky parts.

## Before you write it

Settle the direction first. For a new command, a changed default or a contract change, describe the idea in an issue and wait for the maintainer's answer. A pull request that goes the wrong way is closed, not repaired. Closing is cheap.

## Before you open it

1. Run what CI runs and keep the output:
   - `bundle exec rspec`. CI also fails below 85% suite coverage or 70% for one file.
   - `bundle exec rubocop`
   - `sh docs/map/_meta/sync-twins.sh`, then `ruby docs/map/_meta/check.rb`, after updating the cards listed in `docs/map/effects/CONTEXT.md`
2. If the change alters what a command does, run the command in a scratch repository and keep the real output. `--json` output is best. A claim that it works is not evidence.
3. For a medium or high tier change (see below), get a review from a reader with fresh context before the maintainer looks, and fix what it finds. Any one of these counts:
   - an agent that has not seen the work, given the diff and `REVIEW.md` (in Claude Code: `/code-review`, and `/security-review` for a high tier change)
   - the review bot on the pull request. It does not run by itself here; tick "Trigger review" in its comment.
4. Remove everything the task did not need: unrelated refactors, renamed variables, reformatted lines.

## Size

- One purpose per pull request. A fix and an unrelated cleanup are two pull requests.
- Aim for under 400 changed lines, specs not counted. The fix pull requests so far are between 12 and 356 lines, so this is the size the project already works at.
- Over 1,000 changed lines: split it, or say in the description why it cannot be split.
- A phase pull request is the exception. It is large because it collects a phase. Describe it commit by commit, and keep each commit to one reviewable step.

## Description

The template has five sections. All five are required. Write "none" when a section is empty.

| Section | Contents |
|---|---|
| Problem | What was wrong or missing, and for whom. `Closes #N` when an issue exists. Release and phase pull requests have none. |
| Change | What is different now, as a list. Name the map cards and the CHANGELOG entry. Say what you chose not to do. |
| Tests | The commands you ran and their results. The new specs, one line each, by the behavior they pin. Real command output for a behavior change. |
| Risk | The tier, and the worst thing that happens if this is wrong. |
| How to revert | Whether `git revert` is enough. If the change writes data that outlives it (snapshots, ownership marks, a settings file, an installed skill), say what an older version does with that data. |

An agent may draft the description. The person who asked for the change reads it and owns it.

## Risk tier

The tier comes from what the change touches, not from who wrote it. When a change touches two tiers, the higher one applies.

| Tier | The change touches | Before merge |
|---|---|---|
| Low | Only `README.md`, `CHANGELOG.md`, `demo/`, `docs/` outside `docs/map/_meta/`, or specs with no example removed or skipped | CI green, every review thread resolved. The maintainer does not have to read the diff. |
| Medium | Everything that is not low or high. This includes `lib/`, `bin/`, `command_descriptions.yml`, `skills/gitflash/SKILL.md`, a new optional field in `schema/v1.json`, `Gemfile`, `Rakefile`, `.rubocop.yml`, `docs/map/_meta/`, a removed spec example, and these rules. | Low, plus a fresh-context review, and the maintainer reads the description, the evidence and the diff. |
| High | Any path in the two lists below | Medium, plus the maintainer reads every changed line and the evidence named under the list. |

High tier, user data and the contract. A mistake here loses a user's work, disarms the safety net, or breaks every consumer at once:

- Commands that remove or rewrite: `delete`, `reset`, `clean`, `gc`, `undo`, `wt remove`, `wt prune`, `wt clean`, and `Cleanup`, `Protection`, `Restore`, `WorktreeRevival`.
- Snapshots: `Snapshot`, `Snapshots`, `SnapshotCheck`, `StateCapture`, and anything that changes `REF_PREFIX` or the snapshot format.
- The hook: `lib/gitflash/hook/`, which decides what an agent's command gets a snapshot for, and `HookInstall`, which writes the user's settings files.
- The contract: a changed meaning for an existing field, status, error code or exit code in `schema/v1.json`.
- MCP tool names and argument names in `lib/gitflash/mcp/`.

Evidence: a spec that runs the change against a real temporary git repository. "How to revert" covers data already written. The change goes out in a beta release before a final release.

High tier, supply chain and release. A mistake here ships to every user or weakens CI:

- `.github/workflows/`, `.github/dependabot.yml`, `gitflash.gemspec`, `Gemfile.lock`, `.claude-plugin/`, `lib/gitflash/version.rb`.

Evidence that fits the file: the CI run on the branch for a workflow change, the file list from `gem build` for the gemspec, `spec/plugin_spec.rb` for a version bump, the changelog of the new version for a dependency bump.

## Merge

- Do not merge with a red check. Branch protection on `main` lists no required status checks, so GitHub does not stop you.
- An approval from a bot or an agent is never the maintainer's approval.
- A commit pushed after the maintainer read the pull request needs a new look at that commit.
- Branch protection asks for one code owner approval, and the repository has no `CODEOWNERS` file. The maintainer's own pull request therefore merges with the administrator override. That override is the maintainer's review: use it only after the tier's reading is done.

## Review comments

- Answer every thread. Either fix it, or resolve it with one line that says why not (false positive, intended, out of scope).
- Fix the class of bug, not the one line that was flagged. Search for the same pattern elsewhere in the diff and fix it in the same commit.
- A bug that was there before this pull request gets an issue. Fix it here only when the fix is trivial and inside lines the pull request already changes.
- Three rounds of review and fix is the limit. If findings still arrive after the third round, stop patching and reconsider the approach, or split the pull request.
- If a reviewer flags the same kind of thing again in a later pull request, fix the source: a RuboCop rule, a spec, a map card, or a line in `REVIEW.md`.

## After merge

- Whoever merged it owns it. If `main` breaks, revert first and investigate after.
- If a bug reached a release, write down which layer should have caught it (spec, map check, reviewer, hook rule) and add the missing check in the fix.
