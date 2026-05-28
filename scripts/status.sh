#!/bin/bash
# Print the current Forge build's state in a readable format.
set -euo pipefail

if [ ! -L .forge/current ] && [ ! -d .forge/current ]; then
  echo "No active Forge build in this project."
  echo "Start one with: /forge \"<task description>\""
  exit 0
fi

STATE=".forge/current/state.json"
if [ ! -f "$STATE" ]; then
  echo "Forge: current symlink exists but state.json is missing — corrupted state."
  exit 1
fi

python3 - <<PY
import json, datetime, sys

with open(".forge/current/state.json") as f:
    s = json.load(f)

print(f"Forge build: {s['id']}")
print(f"Task:        {s['task']}")
print(f"Started:     {s['started']}")
print(f"Phase:       {s['phase']}")
print()
print("Phase progress:")
icons = {"done": "✓", "in_progress": "▶", "pending": "·", "aborted": "✗", "blocked": "!"}
for name in ["plan", "code", "test", "review", "deploy"]:
    p = s["phases"].get(name, {})
    icon = icons.get(p.get("status", "pending"), "?")
    model = p.get("model", "—")
    print(f"  {icon}  {name:<8}  [{model:<6}]  {p.get('status','pending')}")
PY

DIR=".forge/current"
echo ""
echo "Artifacts in $DIR:"
ls -1 "$DIR" | grep -v '^state.json$' | sed 's/^/  /' || true
