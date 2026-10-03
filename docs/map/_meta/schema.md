# Schema

Closed set of note types.

| `type:` | Lives at | Carries |
|---|---|---|
| object | `objects/<cluster>/<slug>.md` | one noun: shape, connections, Hits / Does not hit |

Clusters: `contract`, `core`, `commands`, `snapshots`, `hooks`.

Frontmatter: `type`, `cluster`, `universe` (live / leftover / ghost), `status` (stub / verified / stale), `entity` (owning file). Verified cards add `verified_on` and `verified_at` (commit).

Naming: kebab-case slugs. `objects/_index.md` is hand-kept, one line per card.
