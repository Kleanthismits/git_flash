# Configuration

gitflash works without any settings. Two optional files change its defaults:

- `.gitflash.yml` in the repository
- `~/.config/gitflash.yml` for your own defaults

The repository file wins, except for `worktree_dir`, where your own file wins. A repository's `worktree_dir` must be a relative path that stays next to the repository.

```yaml
protected: ["release/*", "hotfix/{a,b}"]   # branch patterns clean and delete never touch; both files add up
stale_days: 30             # used by --stale without a number
worktree_dir: "../%<repo>s.worktrees/%<branch>s"   # only these two placeholders, up to 512 characters
snapshot_exclude: ["*.pem", ".env*", "secrets"]   # untracked files snapshots never copy (a directory covers all below it); both files add up
```

## Protected branches

`gitflash delete` and `gitflash clean` never touch these branches:

- the current branch and the default branch
- `main`, `master`, `develop`, `development`, `trunk` and `release/*`
- patterns listed under `protected`
- branches checked out in a worktree (`clean` only)

## Snapshots and secrets

> [!WARNING]
> Snapshots copy every untracked file that is not ignored (up to 50 MB) into git objects under `refs/gitflash/snapshots/`. A stray secret that is not in `.gitignore` is copied too, and a `git push --mirror` or a `refs/*` refspec would publish it.

Ignore such files, or list them in `snapshot_exclude`. Files left out this way cannot be restored by `gitflash undo`.

Snapshots older than 30 days are deleted by `gitflash gc` (`--older-than DAYS`, at least 1).
