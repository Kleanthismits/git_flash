#!/usr/bin/env bash
# Demo: an agent wipes uncommitted work with plain git, and gitflash brings it back.
#
# Runs in a throwaway repository under a temporary directory; your own repositories are
# not touched. It feeds the gitflash hook the same JSON Claude Code sends before a Bash
# command, so no Claude Code session is needed.
#
#   demo/agent-undo.sh                 # uses this checkout's bin/gitflash
#   GITFLASH=gitflash demo/agent-undo.sh   # uses the installed gem
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
gitflash="${GITFLASH:-ruby -I$root/lib $root/bin/gitflash}"
pause="${DEMO_PAUSE:-1}"

gitflash() {
  # `command` skips this function, so GITFLASH=gitflash runs the installed gem
  command $gitflash "$@"
}

step() {
  printf '\n\033[1;36m== %s\033[0m\n' "$1"
  sleep "$pause"
}

run() {
  printf '\033[2m$ %s\033[0m\n' "$*"
  eval "$@"
}

repo="$(mktemp -d)/demo-repo"
trap 'rm -rf "$(dirname "$repo")"' EXIT
mkdir -p "$repo"
cd "$repo"

step "A repository with uncommitted work"
git init -q -b main
git config user.name demo
git config user.email demo@example.com
echo 'puts "hello"' > app.rb
git add app.rb
git commit -q -m 'Initial commit'
echo 'puts "hello, world"' > app.rb
echo 'API_URL=http://localhost:3000' > notes.txt
run git status --short

step "The agent is about to run: git reset --hard && git clean -fd"
command='git reset --hard && git clean -fd'
input=$(printf '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_use_id":"demo","cwd":"%s","tool_input":{"command":"%s"}}' "$repo" "$command")
printf '\033[2m$ <Claude Code hook input> | gitflash hook claude\033[0m\n'
echo "$input" | gitflash hook claude | ruby -rjson -e 'puts JSON.pretty_generate(JSON.parse($stdin.read))'

step "The command runs. Git alone cannot get this work back"
run "$command"
run git status --short
run cat app.rb

step "gitflash undo restores the snapshot the hook saved"
run gitflash undo --yes
run git status --short
run cat app.rb notes.txt

printf '\n\033[1;32mUncommitted edit and untracked file are back.\033[0m\n'
