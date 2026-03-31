#!/bin/bash

# Ralph-X Setup Script
# Interactive AI development loop with mode selection

set -euo pipefail

# Parse arguments
PROMPT_PARTS=()
MAX_ITERATIONS=0
COMPLETION_PROMISE="null"
MODE=""

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
  --mode <mode>                  Pipeline mode: quick, standard, thorough, custom
  --max-iterations <n>           Max iterations before auto-stop (default: unlimited)
  --completion-promise '<text>'  Phrase that signals completion (USE QUOTES)
  -h, --help                     Show this help

MODES:
  quick      Jump straight into coding. No planning.
  standard   Pre-process → Develop → Post-process. (default)
  thorough   Interview → Design → Develop → Review → Test.
  custom     Pick and combine stages yourself.

EXAMPLES:
  /ralph-x Build a todo API
  /ralph-x Build a todo API --mode quick --max-iterations 20
  /ralph-x --mode thorough --completion-promise 'DONE' Build a REST API
  /ralph-x --mode custom Build a CLI tool

STOPPING:
  /cancel-ralph-x   Cancel the active loop
  --max-iterations   Auto-stop after N iterations
  --completion-promise   Stop when promise is genuinely true
HELP_EOF
      exit 0
      ;;
    --mode)
      if [[ -z "${2:-}" ]]; then
        echo "❌ Error: --mode requires an argument: quick, standard, thorough, custom" >&2
        exit 1
      fi
      case "$2" in
        quick|standard|thorough|custom) MODE="$2" ;;
        *)
          echo "❌ Error: Unknown mode '$2'" >&2
          echo "   Available modes: quick, standard, thorough, custom" >&2
          exit 1
          ;;
      esac
      shift 2
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

if [[ -z "$PROMPT" ]]; then
  echo "❌ Error: No prompt provided" >&2
  echo "   Example: /ralph-x Build a REST API for todos" >&2
  echo "   For help: /ralph-x --help" >&2
  exit 1
fi

# If no mode specified, prompt for interactive selection
if [[ -z "$MODE" ]]; then
  MODE="interactive"
fi

# Quote completion promise for YAML
if [[ -n "$COMPLETION_PROMISE" ]] && [[ "$COMPLETION_PROMISE" != "null" ]]; then
  COMPLETION_PROMISE_YAML="\"$COMPLETION_PROMISE\""
else
  COMPLETION_PROMISE_YAML="null"
fi

# Create state file
mkdir -p .claude

cat > .claude/ralph-x.local.md <<EOF
---
active: true
iteration: 1
mode: $MODE
stage: init
session_id: ${CLAUDE_CODE_SESSION_ID:-}
max_iterations: $MAX_ITERATIONS
completion_promise: $COMPLETION_PROMISE_YAML
started_at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
---

$PROMPT
EOF

# Output setup message
cat <<EOF
🔄 Ralph-X activated!

Mode: $(if [[ "$MODE" == "interactive" ]]; then echo "⏳ Waiting for selection..."; else echo "$MODE"; fi)
Iteration: 1
Max iterations: $(if [[ $MAX_ITERATIONS -gt 0 ]]; then echo $MAX_ITERATIONS; else echo "unlimited"; fi)
Completion promise: $(if [[ "$COMPLETION_PROMISE" != "null" ]]; then echo "${COMPLETION_PROMISE//\"/}"; else echo "none"; fi)
EOF

# If interactive mode, show selection menu
if [[ "$MODE" == "interactive" ]]; then
  cat <<'EOF'

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 How do you want to proceed?
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

 1. 🚀 Quick
    Jump straight into coding. No planning, just do it.

 2. 📋 Standard
    Pre-process → Develop → Post-process.

 3. 🔬 Thorough
    Interview → Design → Develop → Review → Test.

 4. 🎯 Custom
    Pick and combine stages yourself.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 Reply with a number (1-4) to start.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
else
  echo ""
  echo "Pipeline: $(cat "${CLAUDE_PLUGIN_ROOT}/modes/${MODE}.md" 2>/dev/null || echo "$MODE")"
fi

echo ""
echo "$PROMPT"

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
