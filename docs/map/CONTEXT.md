# Walking the map

Map lives apart from `lib/`. It never holds spec. It cites `path:line`.

## Read order

1. `CLAUDE.md`: collisions, universes.
2. `objects/_index.md`: one line per noun, with status.
3. One card. Follow its `See` link to source.

## Status

- `stub`: named, no body. Read source.
- `verified`: needs date, commit, citations.
- `stale`: source moved on. Re-verify before trusting.

Code and card disagree: code wins, fix card.

## Branch note

First map was verified on `main` at `a3b9a23`, then re-mapped on `phase2_snapshots_undo` at `dde88fd` (2026-10-03). When `main` receives phase 2, re-check line citations; claims should hold, line numbers will move.

## Rule

Every change under `lib/` or `schema/` updates the map in the same commit, then `ruby docs/map/_meta/check.rb` runs. CI runs the same check.

## Slices done

- [x] 1 Catalog
- [x] 2 Nouns (cards)
- [ ] 3 Verbs: skipped. [[change-flow]] covers the one repeating movement.
- [x] 4 `effects/CONTEXT.md` plus outside-in consumers (external scripts: owner unsure)
- [x] 5 Re-verify (2026-10-03 at dde88fd; notes at end of `effects/CONTEXT.md`)
