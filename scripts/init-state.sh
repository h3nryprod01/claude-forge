#!/bin/bash
# Bootstrap a new Forge build's state directory.
# Usage: init-state.sh <task-id> "<task description>"
set -euo pipefail

ID="${1:?usage: init-state.sh <task-id> <task description>}"
TASK="${2:?usage: init-state.sh <task-id> <task description>}"

DIR=".forge/$ID"
mkdir -p "$DIR"

NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

cat > "$DIR/state.json" <<EOF
{
  "id": "$ID",
  "task": $(printf '%s' "$TASK" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'),
  "started": "$NOW",
  "phase": "plan",
  "phases": {
    "plan":   { "status": "in_progress", "model": "opus",   "agent": "forge-planner",  "started": "$NOW" },
    "code":   { "status": "pending",     "model": "sonnet", "agent": "forge-coder"    },
    "test":   { "status": "pending",     "model": "sonnet", "agent": "forge-tester"   },
    "review":   { "status": "pending",   "model": "opus",   "agent": "forge-reviewer" },
    "security": { "status": "pending",   "model": "sonnet", "agent": "forge-security" },
    "deploy":   { "status": "pending",   "model": "haiku",  "agent": "forge-deployer" }
  }
}
EOF

# Update "current" symlink so /forge status and /forge resume find this build.
mkdir -p .forge
rm -f .forge/current
ln -s "$ID" .forge/current

echo "Forge: initialized $DIR"
echo "State: $DIR/state.json"
