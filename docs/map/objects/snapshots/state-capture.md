---
type: object
cluster: snapshots
universe: live
status: verified
entity: lib/gitflash/state_capture.rb
verified_on: 2026-10-05
verified_at: 0b7b8d9 plus review fixes
---

# State capture

Reads repository state and writes the git objects a snapshot needs. Code: `StateCapture`. Never changes branches, index or files (`lib/gitflash/state_capture.rb:7-8`).

## Why this shape

Work tree is captured through a temporary copy of the index, so the real index is untouched (`state_capture.rb:93-106`). Content commits use a fixed date, so equal content gives an equal sha and unchanged state is detectable (`state_capture.rb:16-19`).

## Shape

- `call(scope, branch_names)` returns the state hash (`state_capture.rb:26-37`).
- Dirty tree: `index` and `worktree` commits, parented on HEAD (`state_capture.rb:35`, `74-83`). Unresolved merge: `index` nil (`state_capture.rb:76`).
- Untracked, non-ignored files included; files over 50 MB are skipped and listed in `skipped_files` (`state_capture.rb:10`, `104-113`).
- Branch names come from full refs with `refs/heads/` removed (`state_capture.rb:64-72`, `Branch.parse_tips`); short names change when a tag has the same name.
- A file that disappears between `ls-files` and the size check is left out instead of crashing (`file_sizes`, `state_capture.rb:108-115`).
- Author/committer `gitflash@localhost` (`state_capture.rb:12-15`).

- Runs in any directory when given `Git::InDirectory` as its git runner; gitdir and index paths are asked as absolute paths so this works (see [[worktree-revival]]).

## Connected to

- **owned-by:** [[snapshot-store]]
- **joins:** [[snapshot]], [[bash-command]] (`env:` for `GIT_INDEX_FILE`)
- **looks-like-but-is-not:** [[restore]], the reverse operation

## If you change this

- **Hits:** [[snapshot]] fields and sha determinism; [[snapshot-store]] duplicate detection; size of the object store.
- **Does not hit:** [[repo]], [[json-schema]] (unless a field changes).
- Ignored files are never saved: undo cannot bring them back.

## Surfaces

| Surface | Role |
|---|---|
| [[snapshot-store]] | calls |

## See

- Source: `lib/gitflash/state_capture.rb`
