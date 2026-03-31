#!/bin/bash

# Ralph-X Stop Hook
# Mode-aware self-referential loop with pipeline stages

set -euo pipefail

HOOK_INPUT=$(cat)
RALPH_STATE_FILE=".claude/ralph-x.local.md"

if [[ ! -f "$RALPH_STATE_FILE" ]]; then
  exit 0
fi

# Parse frontmatter
FRONTMATTER=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$RALPH_STATE_FILE")
ITERATION=$(echo "$FRONTMATTER" | grep '^iteration:' | sed 's/iteration: *//')
MAX_ITERATIONS=$(echo "$FRONTMATTER" | grep '^max_iterations:' | sed 's/max_iterations: *//')
MODE=$(echo "$FRONTMATTER" | grep '^mode:' | sed 's/mode: *//')
STAGE=$(echo "$FRONTMATTER" | grep '^stage:' | sed 's/stage: *//')
COMPLETION_PROMISE=$(echo "$FRONTMATTER" | grep '^completion_promise:' | sed 's/completion_promise: *//' | sed 's/^"\(.*\)"$/\1/')

# Session isolation
STATE_SESSION=$(echo "$FRONTMATTER" | grep '^session_id:' | sed 's/session_id: *//' || true)
HOOK_SESSION=$(echo "$HOOK_INPUT" | jq -r '.session_id // ""')
if [[ -n "$STATE_SESSION" ]] && [[ "$STATE_SESSION" != "$HOOK_SESSION" ]]; then
  exit 0
fi

# Validate numeric fields
if [[ ! "$ITERATION" =~ ^[0-9]+$ ]] || [[ ! "$MAX_ITERATIONS" =~ ^[0-9]+$ ]]; then
  echo "⚠️  Ralph-X: State file corrupted. Stopping." >&2
  rm "$RALPH_STATE_FILE"
  exit 0
fi

# Check max iterations
if [[ $MAX_ITERATIONS -gt 0 ]] && [[ $ITERATION -ge $MAX_ITERATIONS ]]; then
  echo "🛑 Ralph-X: Max iterations ($MAX_ITERATIONS) reached."
  rm "$RALPH_STATE_FILE"
  exit 0
fi

# Read transcript
TRANSCRIPT_PATH=$(echo "$HOOK_INPUT" | jq -r '.transcript_path')

if [[ ! -f "$TRANSCRIPT_PATH" ]]; then
  echo "⚠️  Ralph-X: Transcript not found. Stopping." >&2
  rm "$RALPH_STATE_FILE"
  exit 0
fi

if ! grep -q '"role":"assistant"' "$TRANSCRIPT_PATH"; then
  echo "⚠️  Ralph-X: No assistant messages found. Stopping." >&2
  rm "$RALPH_STATE_FILE"
  exit 0
fi

# Extract last assistant output
LAST_LINES=$(grep '"role":"assistant"' "$TRANSCRIPT_PATH" | tail -n 100)
if [[ -z "$LAST_LINES" ]]; then
  echo "⚠️  Ralph-X: Failed to extract messages. Stopping." >&2
  rm "$RALPH_STATE_FILE"
  exit 0
fi

set +e
LAST_OUTPUT=$(echo "$LAST_LINES" | jq -rs '
  map(.message.content[]? | select(.type == "text") | .text) | last // ""
' 2>&1)
JQ_EXIT=$?
set -e

if [[ $JQ_EXIT -ne 0 ]]; then
  echo "⚠️  Ralph-X: Failed to parse transcript. Stopping." >&2
  rm "$RALPH_STATE_FILE"
  exit 0
fi

# Check completion promise
if [[ "$COMPLETION_PROMISE" != "null" ]] && [[ -n "$COMPLETION_PROMISE" ]]; then
  PROMISE_TEXT=$(echo "$LAST_OUTPUT" | perl -0777 -pe 's/.*?<promise>(.*?)<\/promise>.*/$1/s; s/^\s+|\s+$//g; s/\s+/ /g' 2>/dev/null || echo "")
  if [[ -n "$PROMISE_TEXT" ]] && [[ "$PROMISE_TEXT" = "$COMPLETION_PROMISE" ]]; then
    echo "✅ Ralph-X: Completion promise detected — <promise>$COMPLETION_PROMISE</promise>"
    rm "$RALPH_STATE_FILE"
    exit 0
  fi
fi

# Detect mode selection from user response (for interactive mode)
if [[ "$MODE" == "interactive" ]]; then
  # Check if user selected a mode in the last output or user message
  USER_LINES=$(grep '"role":"human"' "$TRANSCRIPT_PATH" | tail -n 5)
  set +e
  USER_TEXT=$(echo "$USER_LINES" | jq -rs '
    map(.message.content[]? | select(.type == "text") | .text) | last // ""
  ' 2>&1)
  set -e

  case "$USER_TEXT" in
    *1*|*quick*|*Quick*) MODE="quick" ;;
    *2*|*standard*|*Standard*) MODE="standard" ;;
    *3*|*thorough*|*Thorough*) MODE="thorough" ;;
    *4*|*custom*|*Custom*) MODE="custom" ;;
  esac

  # Update mode in state file
  if [[ "$MODE" != "interactive" ]]; then
    TEMP_FILE="${RALPH_STATE_FILE}.tmp.$$"
    sed "s/^mode: .*/mode: $MODE/" "$RALPH_STATE_FILE" > "$TEMP_FILE"
    mv "$TEMP_FILE" "$RALPH_STATE_FILE"
  fi
fi

# Continue loop
NEXT_ITERATION=$((ITERATION + 1))
PROMPT_TEXT=$(awk '/^---$/{i++; next} i>=2' "$RALPH_STATE_FILE")

if [[ -z "$PROMPT_TEXT" ]]; then
  echo "⚠️  Ralph-X: No prompt found. Stopping." >&2
  rm "$RALPH_STATE_FILE"
  exit 0
fi

# Update iteration
TEMP_FILE="${RALPH_STATE_FILE}.tmp.$$"
sed "s/^iteration: .*/iteration: $NEXT_ITERATION/" "$RALPH_STATE_FILE" > "$TEMP_FILE"
mv "$TEMP_FILE" "$RALPH_STATE_FILE"

# Build mode-aware system message
MODE_INFO=""
case "$MODE" in
  quick) MODE_INFO="Mode: Quick | Just code it" ;;
  standard) MODE_INFO="Mode: Standard | Pre → Dev → Post" ;;
  thorough) MODE_INFO="Mode: Thorough | Interview → Design → Dev → Review → Test" ;;
  custom) MODE_INFO="Mode: Custom | Follow user-defined stages" ;;
  interactive) MODE_INFO="Mode: Awaiting selection" ;;
esac

if [[ "$COMPLETION_PROMISE" != "null" ]] && [[ -n "$COMPLETION_PROMISE" ]]; then
  SYSTEM_MSG="🔄 Ralph-X iteration $NEXT_ITERATION | $MODE_INFO | To stop: <promise>$COMPLETION_PROMISE</promise> (ONLY when TRUE)"
else
  SYSTEM_MSG="🔄 Ralph-X iteration $NEXT_ITERATION | $MODE_INFO | No completion promise — runs infinitely"
fi

jq -n \
  --arg prompt "$PROMPT_TEXT" \
  --arg msg "$SYSTEM_MSG" \
  '{
    "decision": "block",
    "reason": $prompt,
    "systemMessage": $msg
  }'

exit 0
