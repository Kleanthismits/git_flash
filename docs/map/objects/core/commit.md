---
type: object
cluster: core
universe: live
status: verified
entity: lib/gitflash/commit.rb
verified_on: 2026-10-03
verified_at: dde88fd
---

# Commit

Value record of one commit. Code: `Commit = Data.define(:sha, :subject, :author, :committed_at)`.

## Why this shape

Same pattern as [[branch]]. Used for the `reset` menu.

## Shape

- Fields at `lib/gitflash/commit.rb:7`; parse at `commit.rb:9-12`, bound to `Repo::COMMIT_FORMAT`.
- `label` = menu text (`commit.rb:14-16`). `to_h` ISO time (`commit.rb:18-20`).

## Connected to

- **owned-by:** [[repo]] (`commits`)
- **joins:** `reset` command only. Not in [[json-schema]]: reset JSON carries plain SHAs.
- **looks-like-but-is-not:** git's commit object; also not a [[snapshot]], which is stored as a git commit.

## If you change this

- **Hits:** [[repo]] `COMMIT_FORMAT`; `reset` menu (`lib/gitflash/commands/reset.rb:19`).
- **Does not hit:** [[json-schema]], [[branch]].

## Surfaces

| Surface | Role |
|---|---|
| terminal user | sees labels in menu |

## See

- Source: `lib/gitflash/commit.rb`
