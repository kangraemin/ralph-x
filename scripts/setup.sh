#!/bin/bash

# Ralph-X Setup Script
# Interactive AI development loop with mode selection

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

EXAMPLES:
  /ralph-x Build a todo API
  /ralph-x TODO API 만들어줘
  /ralph-x Build a REST API --max-iterations 30
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

# If no prompt, show welcome — don't create state file
if [[ -z "$PROMPT" ]]; then
  cat <<'EOF'
🔄 Ralph-X

What would you like to work on?
어떤 작업을 할까요?
EOF
  exit 0
fi

# Quote completion promise for YAML
if [[ -n "$COMPLETION_PROMISE" ]] && [[ "$COMPLETION_PROMISE" != "null" ]]; then
  COMPLETION_PROMISE_YAML="\"$COMPLETION_PROMISE\""
else
  COMPLETION_PROMISE_YAML="null"
fi

# Create state file
# setup_phase: mode_select → iterations → checklist → running
mkdir -p .claude

cat > .claude/ralph-x.local.md <<EOF
---
active: true
iteration: 1
pipeline_name: pending
current_stage_index: 0
setup_phase: mode_select
builder_phase: null
session_id: ${CLAUDE_CODE_SESSION_ID:-}
max_iterations: $MAX_ITERATIONS
completion_promise: $COMPLETION_PROMISE_YAML
started_at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
---

$PROMPT
EOF

# Initialize empty checklist
echo '[]' > .claude/ralph-x-checklist.json

# Output setup message + selection menu
cat <<EOF
🔄 Ralph-X activated!

Task: $PROMPT

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 How do you want to proceed? / 어떻게 진행할까요?
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

 1. 🚀 Quick — 바로 코딩 / Just code it
 2. 📋 Standard — 사전처리 → 개발 → 후처리
 3. 🔬 Thorough — 인터뷰 → 설계 → 개발 → 리뷰 → 테스트
 4. 🎯 Custom — 직접 파이프라인 조합 / Build your own

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 Pick a number (1-4)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
