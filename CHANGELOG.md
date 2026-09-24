## [Unreleased]

- Add `branches` command with last commit, upstream (ahead, behind, gone) and merge status, filters `--merged`, `--gone`, `--stale DAYS`
- Commands accept arguments: `checkout BRANCH`, `delete BRANCH...`, `reset COMMIT`
- Add `--json`, `--yes` and `--dry-run` options to every command
- Never wait for input without a terminal: exit with code 2 and explain what to pass
- `delete` keeps unmerged branches unless `--force` is given (breaking: it used to always force-delete) and also protects the default branch
- Detect the default branch from `origin/HEAD`, falling back to `main` or `master`
- Add `reset --soft`
- Internal: new `Repo` service layer with `Branch` and `Commit` records; integration specs run against real temporary git repositories

## [0.1.0.alpha] - 2023-06-17

- Initial release

## [0.1.1.alpha] - 2023-10-28

- Fix delete method
- Added and updated test
- bug fixes

## [0.1.2.alpha] - 2023-11-4

- Refactors and code improvements
- Zeitwerk warning suppress
- Update README
- Bug fixes

## [0.2.0.alpha] - 2023-12-9

- Add reset command
- Code improvements

## [0.3.0] - 2025-10-10

- Fix reset method
- Update to Ruby version 3.3.2
- Bug fixes

## [0.4.0] - 2026-09-24

- Run git commands without a shell and raise on failure
- List branches with `git for-each-ref`; detached HEAD no longer shows as a branch
- List the latest 100 commits for `reset`, unaffected by `log.decorate`
- Exit with an error when a git command fails or outside a git repository
- `delete` does nothing when no branches are available or selected
- `reset --hard` prints `Exited` when declined; fix single-commit message
- Correct `reset` help text
- Portable `bin/gitflash` shebang
- Require thor >= 1.4 (CVE-2025-54314) and Ruby >= 3.3
- Add `version` command (`--version`, `-v`)
- CI: pin third-party action to a commit SHA, restrict token permissions, test Ruby 3.3–3.4
