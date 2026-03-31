#!/bin/bash

# Ralph-X Setup Script
# Interactive AI development loop with mode selection
# No --mode flag — always shows selection menu

set -euo pipefail

# Parse arguments
PROMPT_PARTS=()
MAX_ITERATIONS=0
COMPLETION_PROMISE="null"

while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      cat << 'HELP_EOF'
Ralph-X — Interactive AI development loop with mode selection

USAGE:
  /ralph-x [PROMPT...] [OPTIONS]

ARGUMENTS:
  PROMPT...    Task description (can be multiple words without quotes)

OPTIONS:
  --max-iterations <n>           Max iterations before auto-stop (default: unlimited)
  --completion-promise '<text>'  Phrase that signals completion (USE QUOTES)
  -h, --help                     Show this help

MODES (selected interactively at launch):
  1. Quick      — Jump straight into coding.
  2. Standard   — Pre-process → Develop → Post-process.
  3. Thorough   — Interview → Design → Develop → Review → Test.
  4. Custom     — Build your own pipeline step by step.

EXAMPLES:
  /ralph-x Build a todo API
  /ralph-x Build a REST API --max-iterations 30
  /ralph-x --completion-promise 'DONE' Fix the auth bug

STOPPING:
  /cancel-ralph-x              Cancel the active loop
  --max-iterations              Auto-stop after N iterations
  --completion-promise          Stop when promise is genuinely true
HELP_EOF
      exit 0
      ;;
    --max-iterations)
      if [[ -z "${2:-}" ]] || ! [[ "$2" =~ ^[0-9]+$ ]]; then
        echo "❌ Error: --max-iterations requires a positive integer" >&2
        exit 1
      fi
      MAX_ITERATIONS="$2"
      shift 2
      ;;
    --completion-promise)
      if [[ -z "${2:-}" ]]; then
        echo "❌ Error: --completion-promise requires a text argument" >&2
        exit 1
      fi
      COMPLETION_PROMISE="$2"
      shift 2
      ;;
    *)
      PROMPT_PARTS+=("$1")
      shift
      ;;
  esac
done

PROMPT="${PROMPT_PARTS[*]:-}"

# If no prompt, set to "pending" — will ask user in the loop
if [[ -z "$PROMPT" ]]; then
  PROMPT="__AWAITING_PROMPT__"
fi

# Quote completion promise for YAML
if [[ -n "$COMPLETION_PROMISE" ]] && [[ "$COMPLETION_PROMISE" != "null" ]]; then
  COMPLETION_PROMISE_YAML="\"$COMPLETION_PROMISE\""
else
  COMPLETION_PROMISE_YAML="null"
fi

# Create state file — always starts with pipeline_name: pending
mkdir -p .claude

cat > .claude/ralph-x.local.md <<EOF
---
active: true
iteration: 1
pipeline_name: pending
current_stage_index: 0
builder_phase: null
session_id: ${CLAUDE_CODE_SESSION_ID:-}
max_iterations: $MAX_ITERATIONS
completion_promise: $COMPLETION_PROMISE_YAML
started_at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
---

$PROMPT
EOF

# Output setup message
if [[ "$PROMPT" == "__AWAITING_PROMPT__" ]]; then
  cat <<'EOF'
🔄 Ralph-X activated!

What task should I work on? Describe what you want to build or fix.
EOF
else
  cat <<EOF
🔄 Ralph-X activated!

Task: $PROMPT
Max iterations: $(if [[ $MAX_ITERATIONS -gt 0 ]]; then echo $MAX_ITERATIONS; else echo "unlimited"; fi)
Completion promise: $(if [[ "$COMPLETION_PROMISE" != "null" ]]; then echo "${COMPLETION_PROMISE//\"/}"; else echo "none"; fi)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 How do you want to proceed?
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

 1. 🚀 Quick
    Jump straight into coding. No planning.

 2. 📋 Standard
    Pre-process → Develop → Post-process.

 3. 🔬 Thorough
    Interview → Design → Develop → Review → Test.

 4. 🎯 Custom
    Build your own pipeline step by step.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 Reply with a number (1-4) to start.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
fi

if [[ "$COMPLETION_PROMISE" != "null" ]]; then
  cat <<EOF

═══════════════════════════════════════════════════════════
CRITICAL — Ralph-X Completion Promise
═══════════════════════════════════════════════════════════

To complete this loop, output: <promise>$COMPLETION_PROMISE</promise>

The statement MUST be completely and unequivocally TRUE.
Do NOT output false promises to exit the loop.
═══════════════════════════════════════════════════════════
EOF
fi
