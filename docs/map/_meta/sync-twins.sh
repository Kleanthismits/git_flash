#!/bin/sh
# Rebuild the twins from their sources. Never hand-edit a twin.
#   docs/map/AGENTS.md, docs/map/routing.md  <- docs/map/CLAUDE.md
#   AGENTS.md                                <- CLAUDE.md (repository root)
set -e
cd "$(dirname "$0")/../../.."

# Files in a checkout are other people's input: refuse links (cp would follow them to a device or
# another file) and anything that is not a small regular file
for path in docs/map/CLAUDE.md docs/map/AGENTS.md docs/map/routing.md CLAUDE.md AGENTS.md; do
  if [ -L "$path" ] || { [ -e "$path" ] && [ ! -f "$path" ]; }; then
    echo "sync-twins: $path must be a regular file, not a link" >&2
    exit 1
  fi
done
for source in docs/map/CLAUDE.md CLAUDE.md; do
  if [ ! -f "$source" ] || [ "$(wc -c < "$source")" -gt 1000000 ]; then
    echo "sync-twins: $source must exist and be smaller than 1 MB" >&2
    exit 1
  fi
done

cp docs/map/CLAUDE.md docs/map/AGENTS.md
cp docs/map/CLAUDE.md docs/map/routing.md
cp CLAUDE.md AGENTS.md
