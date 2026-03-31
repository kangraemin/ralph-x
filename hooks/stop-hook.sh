#!/bin/bash

# Ralph-X Stop Hook
# Pipeline-aware self-referential loop with:
# - Interactive mode selection → iterations → checklist → autonomous run
# - Custom pipeline builder with skill binding
# - Stage tracking + checklist-based completion

set -euo pipefail

HOOK_INPUT=$(cat)
RALPH_STATE_FILE=".claude/ralph-x.local.md"
RALPH_STAGES_FILE=".claude/ralph-x-stages.json"
RALPH_PRESETS_FILE=".claude/ralph-x-presets.json"
RALPH_CHECKLIST_FILE=".claude/ralph-x-checklist.json"
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(dirname "$(dirname "$0")")}"
BUILTIN_PRESETS_FILE="${PLUGIN_ROOT}/modes/builtin-presets.json"

if [[ ! -f "$RALPH_STATE_FILE" ]]; then
  exit 0
fi

# ─── Parse frontmatter ────────────────────────────────────────────
FRONTMATTER=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$RALPH_STATE_FILE")

get_field() {
  echo "$FRONTMATTER" | grep "^$1:" | sed "s/$1: *//" | sed 's/^"\(.*\)"$/\1/'
}

ITERATION=$(get_field iteration)
MAX_ITERATIONS=$(get_field max_iterations)
PIPELINE_NAME=$(get_field pipeline_name)
CURRENT_STAGE_INDEX=$(get_field current_stage_index)
SETUP_PHASE=$(get_field setup_phase)
BUILDER_PHASE=$(get_field builder_phase)
COMPLETION_PROMISE=$(get_field completion_promise)

# Session isolation
STATE_SESSION=$(get_field session_id)
HOOK_SESSION=$(echo "$HOOK_INPUT" | jq -r '.session_id // ""')
if [[ -z "$STATE_SESSION" ]]; then
  rm -f "$RALPH_STATE_FILE" "$RALPH_STAGES_FILE" "$RALPH_CHECKLIST_FILE"
  exit 0
fi
if [[ "$STATE_SESSION" != "$HOOK_SESSION" ]]; then
  exit 0
fi

# Validate numeric fields
if [[ ! "$ITERATION" =~ ^[0-9]+$ ]] || [[ ! "$MAX_ITERATIONS" =~ ^[0-9]+$ ]]; then
  echo "⚠️  Ralph-X: State file corrupted. Stopping." >&2
  rm -f "$RALPH_STATE_FILE" "$RALPH_STAGES_FILE" "$RALPH_CHECKLIST_FILE"
  exit 0
fi

# Check max iterations
if [[ $MAX_ITERATIONS -gt 0 ]] && [[ $ITERATION -ge $MAX_ITERATIONS ]]; then
  echo "🛑 Ralph-X: Max iterations ($MAX_ITERATIONS) reached."
  rm -f "$RALPH_STATE_FILE" "$RALPH_STAGES_FILE"
  exit 0
fi

# ─── Read transcript ──────────────────────────────────────────────
TRANSCRIPT_PATH=$(echo "$HOOK_INPUT" | jq -r '.transcript_path')

if [[ ! -f "$TRANSCRIPT_PATH" ]]; then
  echo "⚠️  Ralph-X: Transcript not found. Stopping." >&2
  rm -f "$RALPH_STATE_FILE" "$RALPH_STAGES_FILE"
  exit 0
fi

# Extract last assistant output
LAST_ASSISTANT=""
if grep -q '"role":"assistant"' "$TRANSCRIPT_PATH"; then
  LAST_LINES=$(grep '"role":"assistant"' "$TRANSCRIPT_PATH" | tail -n 100)
  set +e
  LAST_ASSISTANT=$(echo "$LAST_LINES" | jq -rs '
    map(.message.content[]? | select(.type == "text") | .text) | last // ""
  ' 2>&1)
  JQ_EXIT=$?
  set -e
  if [[ $JQ_EXIT -ne 0 ]]; then
    LAST_ASSISTANT=""
  fi
fi

# Extract last user message
LAST_USER=""
if grep -q '"role":"human"' "$TRANSCRIPT_PATH"; then
  USER_LINES=$(grep '"role":"human"' "$TRANSCRIPT_PATH" | tail -n 5)
  set +e
  LAST_USER=$(echo "$USER_LINES" | jq -rs '
    map(.message.content[]? | select(.type == "text") | .text) | last // ""
  ' 2>&1)
  set -e
fi

# ─── Helper: update state field ───────────────────────────────────
update_field() {
  local field="$1" value="$2"
  local temp="${RALPH_STATE_FILE}.tmp.$$"
  sed "s/^${field}: .*/${field}: ${value}/" "$RALPH_STATE_FILE" > "$temp"
  mv "$temp" "$RALPH_STATE_FILE"
}

# ─── Helper: output block JSON and exit ───────────────────────────
block_and_exit() {
  local prompt="$1" msg="$2"
  jq -n --arg prompt "$prompt" --arg msg "$msg" \
    '{"decision": "block", "reason": $prompt, "systemMessage": $msg}'
  exit 0
}

# ─── Check for checklist completion ───────────────────────────────
# Claude marks items with <ralph-check id="N"/> tag
if [[ -f "$RALPH_CHECKLIST_FILE" ]]; then
  # Parse all check tags from assistant output
  CHECK_IDS=$(echo "$LAST_ASSISTANT" | grep -oE '<ralph-check id="[0-9]+"' | grep -oE '[0-9]+' || true)
  if [[ -n "$CHECK_IDS" ]]; then
    for cid in $CHECK_IDS; do
      jq ".[${cid}].done = true" "$RALPH_CHECKLIST_FILE" > "${RALPH_CHECKLIST_FILE}.tmp" 2>/dev/null
      if [[ -f "${RALPH_CHECKLIST_FILE}.tmp" ]]; then
        mv "${RALPH_CHECKLIST_FILE}.tmp" "$RALPH_CHECKLIST_FILE"
      fi
    done
  fi

  # Check if all items are done
  TOTAL_ITEMS=$(jq 'length' "$RALPH_CHECKLIST_FILE" 2>/dev/null || echo 0)
  DONE_ITEMS=$(jq '[.[] | select(.done == true)] | length' "$RALPH_CHECKLIST_FILE" 2>/dev/null || echo 0)
  if [[ $TOTAL_ITEMS -gt 0 ]] && [[ $TOTAL_ITEMS -eq $DONE_ITEMS ]]; then
    echo "✅ Ralph-X: All checklist items complete! ($DONE_ITEMS/$TOTAL_ITEMS)"
    rm -f "$RALPH_STATE_FILE" "$RALPH_STAGES_FILE"
    exit 0
  fi
fi

# ─── Check completion promise ─────────────────────────────────────
if [[ "$COMPLETION_PROMISE" != "null" ]] && [[ -n "$COMPLETION_PROMISE" ]]; then
  PROMISE_TEXT=$(echo "$LAST_ASSISTANT" | perl -0777 -pe 's/.*?<promise>(.*?)<\/promise>.*/$1/s; s/^\s+|\s+$//g; s/\s+/ /g' 2>/dev/null || echo "")
  if [[ -n "$PROMISE_TEXT" ]] && [[ "$PROMISE_TEXT" = "$COMPLETION_PROMISE" ]]; then
    echo "✅ Ralph-X: Completion promise detected — <promise>$COMPLETION_PROMISE</promise>"
    rm -f "$RALPH_STATE_FILE" "$RALPH_STAGES_FILE"
    exit 0
  fi
fi

# ─── Check for stage advance tag ──────────────────────────────────
if echo "$LAST_ASSISTANT" | grep -q '<ralph-advance-stage/>'; then
  if [[ -f "$RALPH_STAGES_FILE" ]]; then
    TOTAL_STAGES=$(jq 'length' "$RALPH_STAGES_FILE")
    NEXT_STAGE=$((CURRENT_STAGE_INDEX + 1))
    if [[ $NEXT_STAGE -ge $TOTAL_STAGES ]]; then
      update_field current_stage_index 0
      CURRENT_STAGE_INDEX=0
    else
      update_field current_stage_index "$NEXT_STAGE"
      CURRENT_STAGE_INDEX=$NEXT_STAGE
    fi
  fi
fi

# ─── SETUP PHASE: mode_select ────────────────────────────────────
if [[ "$SETUP_PHASE" == "mode_select" ]]; then
  CHOICE=""
  case "$LAST_USER" in
    *1*|*[Qq]uick*) CHOICE="quick" ;;
    *2*|*[Ss]tandard*) CHOICE="standard" ;;
    *3*|*[Tt]horough*) CHOICE="thorough" ;;
    *4*|*[Cc]ustom*) CHOICE="custom" ;;
  esac

  if [[ -n "$CHOICE" ]] && [[ "$CHOICE" != "custom" ]]; then
    if [[ -f "$BUILTIN_PRESETS_FILE" ]]; then
      jq ".[\"$CHOICE\"].stages" "$BUILTIN_PRESETS_FILE" > "$RALPH_STAGES_FILE"
      update_field pipeline_name "$CHOICE"
      update_field current_stage_index 0
      update_field setup_phase "iterations"
      PIPELINE_NAME="$CHOICE"
      SETUP_PHASE="iterations"
    fi
  elif [[ "$CHOICE" == "custom" ]]; then
    if [[ -f "$RALPH_PRESETS_FILE" ]] && [[ $(jq '.presets | length' "$RALPH_PRESETS_FILE" 2>/dev/null) -gt 0 ]]; then
      update_field pipeline_name "custom"
      update_field builder_phase "awaiting_presets"
      PIPELINE_NAME="custom"
      BUILDER_PHASE="awaiting_presets"
    else
      update_field pipeline_name "custom"
      update_field builder_phase "awaiting_step"
      echo '[]' > "$RALPH_STAGES_FILE"
      PIPELINE_NAME="custom"
      BUILDER_PHASE="awaiting_step"
    fi
  fi

  # Still in mode_select — show menu
  if [[ "$SETUP_PHASE" == "mode_select" ]] && [[ -z "$CHOICE" ]]; then
    NEXT_ITERATION=$((ITERATION + 1))
    update_field iteration "$NEXT_ITERATION"
    block_and_exit \
      "Show the mode menu and wait for user choice (1-4):

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 How do you want to proceed? / 어떻게 진행할까요?
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 1. 🚀 Quick — 바로 코딩 / Just code it
 2. 📋 Standard — 사전처리 → 개발 → 후처리
 3. 🔬 Thorough — 인터뷰 → 설계 → 개발 → 리뷰 → 테스트
 4. 🎯 Custom — 직접 파이프라인 조합 / Build your own
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Task: $(awk '/^---$/{i++; next} i>=2' "$RALPH_STATE_FILE")" \
      "🔄 Ralph-X iteration $NEXT_ITERATION | Respond in the user's language. Show mode menu, wait for choice. Do NOT start working."
  fi
fi

# ─── SETUP PHASE: iterations ─────────────────────────────────────
if [[ "$SETUP_PHASE" == "iterations" ]]; then
  # Try to parse a number from user message
  ITER_NUM=$(echo "$LAST_USER" | grep -oE '[0-9]+' | head -1)
  if [[ -n "$ITER_NUM" ]] && [[ $ITER_NUM -gt 0 ]]; then
    update_field max_iterations "$ITER_NUM"
    MAX_ITERATIONS="$ITER_NUM"
    update_field setup_phase "checklist"
    SETUP_PHASE="checklist"
  elif echo "$LAST_USER" | grep -qiE '무제한|unlimited|없|0'; then
    update_field max_iterations 0
    update_field setup_phase "checklist"
    SETUP_PHASE="checklist"
  fi

  if [[ "$SETUP_PHASE" == "iterations" ]]; then
    NEXT_ITERATION=$((ITERATION + 1))
    update_field iteration "$NEXT_ITERATION"
    block_and_exit \
      "Ask the user: How many iterations max? (safety limit) / 최대 몇 회 반복? (안전장치)
Default: 10. Or 'unlimited'.
Example: 10, 20, 50, unlimited" \
      "🔄 Ralph-X iteration $NEXT_ITERATION | Respond in user's language. Ask for max iterations. Do NOT start working."
  fi
fi

# ─── SETUP PHASE: checklist ──────────────────────────────────────
if [[ "$SETUP_PHASE" == "checklist" ]]; then
  # Check if user is done adding items
  if echo "$LAST_USER" | grep -qiE '끝|done|완료|finish|없|that.s (all|it)|시작|start|go|ㄱㄱ'; then
    TOTAL_ITEMS=$(jq 'length' "$RALPH_CHECKLIST_FILE" 2>/dev/null || echo 0)
    if [[ $TOTAL_ITEMS -gt 0 ]]; then
      update_field setup_phase "running"
      SETUP_PHASE="running"
    else
      # No items — skip checklist
      update_field setup_phase "running"
      SETUP_PHASE="running"
    fi
  else
    # Add item to checklist
    ITEM_TEXT=$(echo "$LAST_USER" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    if [[ -n "$ITEM_TEXT" ]] && [[ "$ITEM_TEXT" != "null" ]]; then
      ITEM_COUNT=$(jq 'length' "$RALPH_CHECKLIST_FILE" 2>/dev/null || echo 0)
      jq --arg text "$ITEM_TEXT" --argjson id "$ITEM_COUNT" \
        '. += [{"id": $id, "text": $text, "done": false}]' \
        "$RALPH_CHECKLIST_FILE" > "${RALPH_CHECKLIST_FILE}.tmp"
      mv "${RALPH_CHECKLIST_FILE}.tmp" "$RALPH_CHECKLIST_FILE"
    fi
  fi

  if [[ "$SETUP_PHASE" == "checklist" ]]; then
    TOTAL_ITEMS=$(jq 'length' "$RALPH_CHECKLIST_FILE" 2>/dev/null || echo 0)
    NEXT_ITERATION=$((ITERATION + 1))
    update_field iteration "$NEXT_ITERATION"

    if [[ $TOTAL_ITEMS -eq 0 ]]; then
      CHECKLIST_PROMPT="Ask the user for completion conditions (one at a time).
완료 조건을 하나씩 알려주세요.

When done, say 'done' / '끝' / '시작' to start the loop.
Or say 'skip' / '없음' to run without a checklist."
    else
      CURRENT_LIST=$(jq -r '.[] | "[ ] \(.text)"' "$RALPH_CHECKLIST_FILE")
      CHECKLIST_PROMPT="Current checklist:
$CURRENT_LIST

Add another condition, or say 'done' / '끝' / '시작' to start."
    fi

    block_and_exit "$CHECKLIST_PROMPT" \
      "🔄 Ralph-X iteration $NEXT_ITERATION | Respond in user's language. Collecting checklist items. Do NOT start working."
  fi
fi

# ─── Custom builder state machine ─────────────────────────────────
if [[ "$PIPELINE_NAME" == "custom" ]] && [[ "$BUILDER_PHASE" != "null" ]] && [[ -n "$BUILDER_PHASE" ]]; then
  BUILDER_PROMPT=""
  case "$BUILDER_PHASE" in
    awaiting_presets)
      if echo "$LAST_USER" | grep -qi 'new\|새로\|새 '; then
        update_field builder_phase "awaiting_step"
        echo '[]' > "$RALPH_STAGES_FILE"
        BUILDER_PHASE="awaiting_step"
      else
        if [[ -f "$RALPH_PRESETS_FILE" ]]; then
          PRESET_NAMES=$(jq -r '.presets | keys[]' "$RALPH_PRESETS_FILE" 2>/dev/null)
          MATCHED=""
          while IFS= read -r pname; do
            if echo "$LAST_USER" | grep -qi "$pname"; then
              MATCHED="$pname"
              break
            fi
          done <<< "$PRESET_NAMES"

          if [[ -z "$MATCHED" ]]; then
            INDEX=-1
            case "$LAST_USER" in
              *[aA1]*) INDEX=0 ;;
              *[bB2]*) INDEX=1 ;;
              *[cC3]*) INDEX=2 ;;
              *[dD4]*) INDEX=3 ;;
            esac
            if [[ $INDEX -ge 0 ]]; then
              MATCHED=$(jq -r ".presets | keys[$INDEX] // empty" "$RALPH_PRESETS_FILE" 2>/dev/null)
            fi
          fi

          if [[ -n "$MATCHED" ]]; then
            jq ".presets[\"$MATCHED\"].stages" "$RALPH_PRESETS_FILE" > "$RALPH_STAGES_FILE"
            update_field pipeline_name "$MATCHED"
            update_field builder_phase "null"
            update_field current_stage_index 0
            update_field setup_phase "iterations"
            PIPELINE_NAME="$MATCHED"
            BUILDER_PHASE="null"
            SETUP_PHASE="iterations"
          fi
        fi
      fi

      if [[ "$BUILDER_PHASE" == "awaiting_presets" ]]; then
        PRESET_LIST=$(jq -r '.presets | to_entries[] | "\(.key): \(.value.label)"' "$RALPH_PRESETS_FILE" 2>/dev/null | head -10)
        BUILDER_PROMPT="Saved pipelines:
$PRESET_LIST

Pick one by name, or 'new' to create."
      fi
      ;;

    awaiting_step)
      if echo "$LAST_USER" | grep -qiE '끝|done|완료|finish|that.s (all|it)'; then
        update_field builder_phase "confirm"
        BUILDER_PHASE="confirm"
      else
        STEP_NAME=$(echo "$LAST_USER" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [[ -n "$STEP_NAME" ]]; then
          jq --arg name "$STEP_NAME" '. += [{"name": $name, "skill": null, "_pending_skill": true}]' "$RALPH_STAGES_FILE" > "${RALPH_STAGES_FILE}.tmp"
          mv "${RALPH_STAGES_FILE}.tmp" "$RALPH_STAGES_FILE"
          update_field builder_phase "awaiting_skill"
          BUILDER_PHASE="awaiting_skill"
        fi
      fi

      if [[ "$BUILDER_PHASE" == "awaiting_step" ]]; then
        STEP_COUNT=$(jq 'length' "$RALPH_STAGES_FILE" 2>/dev/null || echo 0)
        NEXT_STEP=$((STEP_COUNT + 1))
        if [[ $STEP_COUNT -gt 0 ]]; then
          CURRENT_PIPELINE=$(jq -r '[.[].name] | join(" → ")' "$RALPH_STAGES_FILE")
          BUILDER_PROMPT="Pipeline: $CURRENT_PIPELINE
Step $NEXT_STEP: Then? ('done'/'끝' to finish)"
        else
          BUILDER_PROMPT="Let's build your pipeline.
Step 1: What should I do first?"
        fi
      fi
      ;;

    awaiting_skill)
      SKILL="null"
      if echo "$LAST_USER" | grep -qiE 'skip|스킵|없|패스|pass'; then
        SKILL="null"
      elif echo "$LAST_USER" | grep -qoE '/[a-zA-Z_-]+'; then
        SKILL=$(echo "$LAST_USER" | grep -oE '/[a-zA-Z_-]+' | head -1)
      fi

      if [[ "$SKILL" == "null" ]]; then
        jq 'last._pending_skill = false | last.skill = null' "$RALPH_STAGES_FILE" > "${RALPH_STAGES_FILE}.tmp"
      else
        jq --arg skill "$SKILL" 'last._pending_skill = false | last.skill = $skill' "$RALPH_STAGES_FILE" > "${RALPH_STAGES_FILE}.tmp"
      fi
      mv "${RALPH_STAGES_FILE}.tmp" "$RALPH_STAGES_FILE"
      update_field builder_phase "awaiting_step"
      BUILDER_PHASE="awaiting_step"

      STEP_COUNT=$(jq 'length' "$RALPH_STAGES_FILE" 2>/dev/null || echo 0)
      NEXT_STEP=$((STEP_COUNT + 1))
      CURRENT_PIPELINE=$(jq -r '[.[].name] | join(" → ")' "$RALPH_STAGES_FILE")
      BUILDER_PROMPT="Pipeline: $CURRENT_PIPELINE
Step $NEXT_STEP: Then? ('done'/'끝' to finish)"
      ;;

    confirm)
      if echo "$LAST_USER" | grep -qiE 'yes|y|ㅇ|네|확인|ok|good|좋|맞|ㅇㅇ'; then
        update_field builder_phase "save"
        BUILDER_PHASE="save"
      elif echo "$LAST_USER" | grep -qiE 'no|n|ㄴ|아니|다시|reset'; then
        echo '[]' > "$RALPH_STAGES_FILE"
        update_field builder_phase "awaiting_step"
        BUILDER_PHASE="awaiting_step"
      fi

      if [[ "$BUILDER_PHASE" == "confirm" ]]; then
        PIPELINE_SUMMARY=$(jq -r '[.[] | if .skill then "\(.name) (\(.skill))" else .name end] | join(" → ")' "$RALPH_STAGES_FILE")
        BUILDER_PROMPT="Pipeline: $PIPELINE_SUMMARY
OK? (yes/no)"
      fi
      ;;

    save)
      if echo "$LAST_USER" | grep -qiE 'skip|스킵|패스|pass|no|안'; then
        jq 'map(del(._pending_skill))' "$RALPH_STAGES_FILE" > "${RALPH_STAGES_FILE}.tmp"
        mv "${RALPH_STAGES_FILE}.tmp" "$RALPH_STAGES_FILE"
        update_field builder_phase "null"
        update_field current_stage_index 0
        update_field setup_phase "iterations"
        BUILDER_PHASE="null"
        SETUP_PHASE="iterations"
      else
        PRESET_NAME=$(echo "$LAST_USER" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [[ -n "$PRESET_NAME" ]]; then
          jq 'map(del(._pending_skill))' "$RALPH_STAGES_FILE" > "${RALPH_STAGES_FILE}.tmp"
          mv "${RALPH_STAGES_FILE}.tmp" "$RALPH_STAGES_FILE"
          LABEL=$(jq -r '[.[].name] | join(" → ")' "$RALPH_STAGES_FILE")
          STAGES=$(cat "$RALPH_STAGES_FILE")
          NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
          if [[ ! -f "$RALPH_PRESETS_FILE" ]]; then
            jq -n --arg name "$PRESET_NAME" --arg label "$LABEL" --arg now "$NOW" --argjson stages "$STAGES" \
              '{version: 1, presets: {($name): {label: $label, created_at: $now, stages: $stages}}}' > "$RALPH_PRESETS_FILE"
          else
            jq --arg name "$PRESET_NAME" --arg label "$LABEL" --arg now "$NOW" --argjson stages "$STAGES" \
              '.presets[$name] = {label: $label, created_at: $now, stages: $stages}' "$RALPH_PRESETS_FILE" > "${RALPH_PRESETS_FILE}.tmp"
            mv "${RALPH_PRESETS_FILE}.tmp" "$RALPH_PRESETS_FILE"
          fi
          update_field pipeline_name "$PRESET_NAME"
          update_field builder_phase "null"
          update_field current_stage_index 0
          update_field setup_phase "iterations"
          PIPELINE_NAME="$PRESET_NAME"
          BUILDER_PHASE="null"
          SETUP_PHASE="iterations"
        fi
      fi

      if [[ "$BUILDER_PHASE" == "save" ]]; then
        BUILDER_PROMPT="Save as preset? Name it, or 'skip'."
      fi
      ;;
  esac

  # Output builder prompt if still in builder
  if [[ -n "${BUILDER_PROMPT:-}" ]]; then
    NEXT_ITERATION=$((ITERATION + 1))
    update_field iteration "$NEXT_ITERATION"
    block_and_exit "$BUILDER_PROMPT" \
      "🔄 Ralph-X iteration $NEXT_ITERATION | Respond in user's language. Custom builder active."
  fi
fi

# ─── RUNNING: autonomous loop ─────────────────────────────────────
NEXT_ITERATION=$((ITERATION + 1))
PROMPT_TEXT=$(awk '/^---$/{i++; next} i>=2' "$RALPH_STATE_FILE")

if [[ -z "$PROMPT_TEXT" ]]; then
  echo "⚠️  Ralph-X: No prompt found. Stopping." >&2
  rm -f "$RALPH_STATE_FILE" "$RALPH_STAGES_FILE" "$RALPH_CHECKLIST_FILE"
  exit 0
fi

update_field iteration "$NEXT_ITERATION"

# Build system message for autonomous mode
SYSTEM_MSG="🔄 Ralph-X iteration $NEXT_ITERATION"
SYSTEM_MSG="$SYSTEM_MSG | AUTONOMOUS MODE: Work independently. Do NOT ask the user questions. Make your own decisions. If unsure, pick the best option and proceed. Only stop to show final results."
SYSTEM_MSG="$SYSTEM_MSG | Respond in the user's language."

# Stage info
if [[ -f "$RALPH_STAGES_FILE" ]]; then
  TOTAL_STAGES=$(jq 'length' "$RALPH_STAGES_FILE")
  if [[ $TOTAL_STAGES -gt 0 ]]; then
    STAGE_NAME=$(jq -r ".[$CURRENT_STAGE_INDEX].name // \"unknown\"" "$RALPH_STAGES_FILE")
    STAGE_SKILL=$(jq -r ".[$CURRENT_STAGE_INDEX].skill // empty" "$RALPH_STAGES_FILE")
    STAGE_NUM=$((CURRENT_STAGE_INDEX + 1))
    SYSTEM_MSG="$SYSTEM_MSG | Pipeline: $PIPELINE_NAME | Stage $STAGE_NUM/$TOTAL_STAGES: $STAGE_NAME"
    if [[ -n "$STAGE_SKILL" ]] && [[ "$STAGE_SKILL" != "null" ]]; then
      SYSTEM_MSG="$SYSTEM_MSG | Skill: $STAGE_SKILL — invoke this skill"
    fi
    SYSTEM_MSG="$SYSTEM_MSG | Output <ralph-advance-stage/> when stage complete"
  fi
fi

# Checklist info
if [[ -f "$RALPH_CHECKLIST_FILE" ]]; then
  TOTAL_ITEMS=$(jq 'length' "$RALPH_CHECKLIST_FILE" 2>/dev/null || echo 0)
  if [[ $TOTAL_ITEMS -gt 0 ]]; then
    CHECKLIST_STATUS=$(jq -r '.[] | (if .done then "[x]" else "[ ]" end) + " " + .text' "$RALPH_CHECKLIST_FILE")
    DONE_ITEMS=$(jq '[.[] | select(.done == true)] | length' "$RALPH_CHECKLIST_FILE" 2>/dev/null || echo 0)
    SYSTEM_MSG="$SYSTEM_MSG | Checklist ($DONE_ITEMS/$TOTAL_ITEMS): $CHECKLIST_STATUS"
    SYSTEM_MSG="$SYSTEM_MSG | When a condition is met, output <ralph-check id=\"N\"/> (N = item index starting from 0)"
  fi
fi

# Max iterations info
if [[ $MAX_ITERATIONS -gt 0 ]]; then
  SYSTEM_MSG="$SYSTEM_MSG | Iteration $NEXT_ITERATION/$MAX_ITERATIONS"
fi

# Completion promise
if [[ "$COMPLETION_PROMISE" != "null" ]] && [[ -n "$COMPLETION_PROMISE" ]]; then
  SYSTEM_MSG="$SYSTEM_MSG | Promise: <promise>$COMPLETION_PROMISE</promise> (ONLY when TRUE)"
fi

block_and_exit "$PROMPT_TEXT" "$SYSTEM_MSG"
