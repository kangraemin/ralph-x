#!/bin/bash

# Ralph-X PreToolUse Hook
# Blocks ALL tools during setup phase — only conversation allowed

set -euo pipefail

HOOK_INPUT=$(cat)
RALPH_STATE_FILE=".claude/ralph-x.local.md"

# No state file — not in ralph-x, allow everything
if [[ ! -f "$RALPH_STATE_FILE" ]]; then
  exit 0
fi

# Parse setup_phase from frontmatter
SETUP_PHASE=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$RALPH_STATE_FILE" | grep '^setup_phase:' | sed 's/setup_phase: *//')

# If running — allow everything
if [[ "$SETUP_PHASE" == "running" ]]; then
  exit 0
fi

# During setup (mode_select, iterations, checklist, or builder) — block all tools
# Only the setup.sh script itself is allowed
TOOL_NAME=$(echo "$HOOK_INPUT" | jq -r '.tool_name // ""')

# Allow setup.sh execution
if [[ "$TOOL_NAME" == "Bash" ]]; then
  TOOL_INPUT=$(echo "$HOOK_INPUT" | jq -r '.tool_input.command // ""')
  if echo "$TOOL_INPUT" | grep -q 'setup.sh'; then
    exit 0
  fi
fi

# Block everything else during setup
jq -n '{
  "decision": "block",
  "reason": "Ralph-X is in setup phase. Define your pipeline first — no tools allowed until setup is complete."
}'
