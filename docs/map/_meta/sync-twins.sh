#!/bin/sh
# Rebuild the twins from their sources. Never hand-edit a twin.
#   docs/map/AGENTS.md, docs/map/routing.md  <- docs/map/CLAUDE.md
#   AGENTS.md                                <- CLAUDE.md (repository root)
set -e
cd "$(dirname "$0")/../../.."

cp docs/map/CLAUDE.md docs/map/AGENTS.md
cp docs/map/CLAUDE.md docs/map/routing.md
cp CLAUDE.md AGENTS.md
