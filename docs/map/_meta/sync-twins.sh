#!/bin/sh
# Rebuild AGENTS.md and routing.md from CLAUDE.md. Never hand-edit the twins.
cd "$(dirname "$0")/.." || exit 1
cp CLAUDE.md AGENTS.md
cp CLAUDE.md routing.md
