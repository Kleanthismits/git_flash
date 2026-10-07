---
type: object
cluster: core
universe: live
status: verified
entity: lib/gitflash/cherry_pick.rb
verified_on: 2026-10-05
verified_at: 39cf49c
---

# CherryPick

All git access for `pick`. Code: `CherryPick`, `CherryPick::Candidate`, `CherryPick::Progress`.

## Why this shape

One module owns the `git log --cherry-mark` parsing, the apply call and the sequencer state, so [[pick]] never sees git text. Candidate and progress records go out; commands decide what to report.

## Shape

- `source_ref(name)`: full ref of a local or remote-tracking branch, nil otherwise or when the name starts with `-`.
- `candidates(ref)`: `git log --left-right --cherry-mark --right-only --no-merges --reverse --shortstat HEAD...ref`; marker `=` means the same patch is already on HEAD (`lib/gitflash/cherry_pick.rb`).
- `apply(shas, record_origin:, commit:)`, `continue`, `skip`, `abort`: return `Result`, with `GIT_EDITOR=true`.
- `in_progress?` is `CHERRY_PICK_HEAD` or `sequencer/todo` present. `progress` gives conflicted files (`git diff --diff-filter=U`), the commit that stopped, and the commits still waiting (from `sequencer/todo`, resolved to full shas).

## Connected to

- **joins:** [[repo]] (ref prefixes), [[bash-command]]
- **owned-by:** [[pick]]
- **looks-like-but-is-not:** [[restore]] (undo), `git cherry` (older, unmarked)

## If you change this

- **Hits:** [[pick]], `pick_candidate` in [[json-schema]]; the `%x1e` / `%x1f` log format is parsed in the same file.
- **Does not hit:** [[snapshot-store]].

## Surfaces

| Surface | Role |
|---|---|
| agents, humans | read and write (through [[pick]]) |

## See

- Source: `lib/gitflash/cherry_pick.rb`
