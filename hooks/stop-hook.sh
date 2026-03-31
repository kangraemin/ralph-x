#!/bin/bash

# Ralph-X Stop Hook
# Pipeline-aware self-referential loop with:
# - Interactive mode selection
# - Custom pipeline builder
# - Stage tracking with skill hints
# - Preset save/load

set -euo pipefail

HOOK_INPUT=$(cat)
RALPH_STATE_FILE=".claude/ralph-x.local.md"
RALPH_STAGES_FILE=".claude/ralph-x-stages.json"
RALPH_PRESETS_FILE=".claude/ralph-x-presets.json"
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
BUILDER_PHASE=$(get_field builder_phase)
COMPLETION_PROMISE=$(get_field completion_promise)

# Session isolation — if state has no session_id, it's stale; clean up
STATE_SESSION=$(get_field session_id)
HOOK_SESSION=$(echo "$HOOK_INPUT" | jq -r '.session_id // ""')
if [[ -z "$STATE_SESSION" ]]; then
  rm -f "$RALPH_STATE_FILE" "$RALPH_STAGES_FILE"
  exit 0
fi
if [[ "$STATE_SESSION" != "$HOOK_SESSION" ]]; then
  exit 0
fi

# Validate numeric fields
if [[ ! "$ITERATION" =~ ^[0-9]+$ ]] || [[ ! "$MAX_ITERATIONS" =~ ^[0-9]+$ ]]; then
  echo "⚠️  Ralph-X: State file corrupted. Stopping." >&2
  rm -f "$RALPH_STATE_FILE" "$RALPH_STAGES_FILE"
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

# ─── Check completion promise ─────────────────────────────────────
if [[ "$COMPLETION_PROMISE" != "null" ]] && [[ -n "$COMPLETION_PROMISE" ]]; then
  PROMISE_TEXT=$(echo "$LAST_ASSISTANT" | perl -0777 -pe 's/.*?<promise>(.*?)<\/promise>.*/$1/s; s/^\s+|\s+$//g; s/\s+/ /g' 2>/dev/null || echo "")
  if [[ -n "$PROMISE_TEXT" ]] && [[ "$PROMISE_TEXT" = "$COMPLETION_PROMISE" ]]; then
    echo "✅ Ralph-X: Completion promise detected — <promise>$COMPLETION_PROMISE</promise>"
    rm -f "$RALPH_STATE_FILE" "$RALPH_STAGES_FILE"
    exit 0
  fi
fi

# ─── Helper: update state field ───────────────────────────────────
update_field() {
  local field="$1" value="$2"
  local temp="${RALPH_STATE_FILE}.tmp.$$"
  sed "s/^${field}: .*/${field}: ${value}/" "$RALPH_STATE_FILE" > "$temp"
  mv "$temp" "$RALPH_STATE_FILE"
}

# ─── Check for stage advance tag ──────────────────────────────────
if echo "$LAST_ASSISTANT" | grep -q '<ralph-advance-stage/>'; then
  if [[ -f "$RALPH_STAGES_FILE" ]]; then
    TOTAL_STAGES=$(jq 'length' "$RALPH_STAGES_FILE")
    NEXT_STAGE=$((CURRENT_STAGE_INDEX + 1))
    if [[ $NEXT_STAGE -ge $TOTAL_STAGES ]]; then
      # All stages done — restart from stage 0 for next iteration
      update_field current_stage_index 0
      CURRENT_STAGE_INDEX=0
    else
      update_field current_stage_index "$NEXT_STAGE"
      CURRENT_STAGE_INDEX=$NEXT_STAGE
    fi
  fi
fi

# ─── Pipeline selection (pending state) ───────────────────────────
if [[ "$PIPELINE_NAME" == "pending" ]]; then
  # Detect user choice from last user message
  CHOICE=""
  case "$LAST_USER" in
    *1*|*[Qq]uick*) CHOICE="quick" ;;
    *2*|*[Ss]tandard*) CHOICE="standard" ;;
    *3*|*[Tt]horough*) CHOICE="thorough" ;;
    *4*|*[Cc]ustom*) CHOICE="custom" ;;
  esac

  if [[ -n "$CHOICE" ]] && [[ "$CHOICE" != "custom" ]]; then
    # Load builtin preset
    if [[ -f "$BUILTIN_PRESETS_FILE" ]]; then
      jq ".[\"$CHOICE\"].stages" "$BUILTIN_PRESETS_FILE" > "$RALPH_STAGES_FILE"
      LABEL=$(jq -r ".[\"$CHOICE\"].label" "$BUILTIN_PRESETS_FILE")
      update_field pipeline_name "$CHOICE"
      update_field current_stage_index 0
      PIPELINE_NAME="$CHOICE"
    fi
  elif [[ "$CHOICE" == "custom" ]]; then
    # Check for existing presets
    if [[ -f "$RALPH_PRESETS_FILE" ]] && [[ $(jq '.presets | length' "$RALPH_PRESETS_FILE" 2>/dev/null) -gt 0 ]]; then
      update_field pipeline_name "custom"
      update_field builder_phase "awaiting_presets"
      PIPELINE_NAME="custom"
      BUILDER_PHASE="awaiting_presets"
    else
      update_field pipeline_name "custom"
      update_field builder_phase "awaiting_step"
      # Initialize empty stages
      echo '[]' > "$RALPH_STAGES_FILE"
      PIPELINE_NAME="custom"
      BUILDER_PHASE="awaiting_step"
    fi
  fi
fi

# ─── Custom builder state machine ─────────────────────────────────
if [[ "$PIPELINE_NAME" == "custom" ]] && [[ "$BUILDER_PHASE" != "null" ]] && [[ -n "$BUILDER_PHASE" ]]; then
  case "$BUILDER_PHASE" in
    awaiting_presets)
      # User picks a preset or says "new"
      if echo "$LAST_USER" | grep -qi 'new\|새로\|새 '; then
        update_field builder_phase "awaiting_step"
        echo '[]' > "$RALPH_STAGES_FILE"
        BUILDER_PHASE="awaiting_step"
      else
        # Try to match preset name from user input
        if [[ -f "$RALPH_PRESETS_FILE" ]]; then
          # Get all preset names
          PRESET_NAMES=$(jq -r '.presets | keys[]' "$RALPH_PRESETS_FILE" 2>/dev/null)
          MATCHED=""
          while IFS= read -r pname; do
            if echo "$LAST_USER" | grep -qi "$pname"; then
              MATCHED="$pname"
              break
            fi
          done <<< "$PRESET_NAMES"

          # Also check for letter/number selection (a, b, c...)
          if [[ -z "$MATCHED" ]]; then
            INDEX=-1
            case "$LAST_USER" in
              *[aA1]*) INDEX=0 ;;
              *[bB2]*) INDEX=1 ;;
              *[cC3]*) INDEX=2 ;;
              *[dD4]*) INDEX=3 ;;
              *[eE5]*) INDEX=4 ;;
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
            PIPELINE_NAME="$MATCHED"
            BUILDER_PHASE="null"
          fi
        fi
      fi
      ;;

    awaiting_step)
      # User provides step name or says done
      if echo "$LAST_USER" | grep -qiE '끝|done|완료|finish|that.s (all|it)'; then
        update_field builder_phase "confirm"
        BUILDER_PHASE="confirm"
      else
        # Add step to stages (name only, skill next)
        STEP_NAME=$(echo "$LAST_USER" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [[ -n "$STEP_NAME" ]]; then
          jq --arg name "$STEP_NAME" '. += [{"name": $name, "skill": null, "_pending_skill": true}]' "$RALPH_STAGES_FILE" > "${RALPH_STAGES_FILE}.tmp"
          mv "${RALPH_STAGES_FILE}.tmp" "$RALPH_STAGES_FILE"
          update_field builder_phase "awaiting_skill"
          BUILDER_PHASE="awaiting_skill"
        fi
      fi
      ;;

    awaiting_skill)
      # User provides skill or says skip
      SKILL="null"
      if echo "$LAST_USER" | grep -qiE 'skip|스킵|없|패스|pass'; then
        SKILL="null"
      elif echo "$LAST_USER" | grep -qoE '/[a-zA-Z_-]+'; then
        SKILL=$(echo "$LAST_USER" | grep -oE '/[a-zA-Z_-]+' | head -1)
      fi

      # Update last stage's skill and remove _pending_skill flag
      if [[ "$SKILL" == "null" ]]; then
        jq 'last._pending_skill = false | last.skill = null' "$RALPH_STAGES_FILE" > "${RALPH_STAGES_FILE}.tmp"
      else
        jq --arg skill "$SKILL" 'last._pending_skill = false | last.skill = $skill' "$RALPH_STAGES_FILE" > "${RALPH_STAGES_FILE}.tmp"
      fi
      mv "${RALPH_STAGES_FILE}.tmp" "$RALPH_STAGES_FILE"

      update_field builder_phase "awaiting_step"
      BUILDER_PHASE="awaiting_step"
      ;;

    confirm)
      # User confirms the pipeline
      if echo "$LAST_USER" | grep -qiE 'yes|y|ㅇ|네|확인|ok|good|좋|맞|ㅇㅇ'; then
        update_field builder_phase "save"
        BUILDER_PHASE="save"
      elif echo "$LAST_USER" | grep -qiE 'no|n|ㄴ|아니|다시|reset'; then
        echo '[]' > "$RALPH_STAGES_FILE"
        update_field builder_phase "awaiting_step"
        BUILDER_PHASE="awaiting_step"
      fi
      ;;

    save)
      # User provides preset name or skips
      if echo "$LAST_USER" | grep -qiE 'skip|스킵|패스|pass|no|안'; then
        # Clean up _pending_skill flags and start
        jq 'map(del(._pending_skill))' "$RALPH_STAGES_FILE" > "${RALPH_STAGES_FILE}.tmp"
        mv "${RALPH_STAGES_FILE}.tmp" "$RALPH_STAGES_FILE"
        update_field builder_phase "null"
        update_field current_stage_index 0
        BUILDER_PHASE="null"
      else
        PRESET_NAME=$(echo "$LAST_USER" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [[ -n "$PRESET_NAME" ]]; then
          # Clean stages
          jq 'map(del(._pending_skill))' "$RALPH_STAGES_FILE" > "${RALPH_STAGES_FILE}.tmp"
          mv "${RALPH_STAGES_FILE}.tmp" "$RALPH_STAGES_FILE"

          # Build label from stage names
          LABEL=$(jq -r '[.[].name] | join(" → ")' "$RALPH_STAGES_FILE")
          STAGES=$(cat "$RALPH_STAGES_FILE")
          NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

          # Create or update presets file
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
          PIPELINE_NAME="$PRESET_NAME"
          BUILDER_PHASE="null"
        fi
      fi
      ;;
  esac
fi

# ─── Continue loop ────────────────────────────────────────────────
NEXT_ITERATION=$((ITERATION + 1))
PROMPT_TEXT=$(awk '/^---$/{i++; next} i>=2' "$RALPH_STATE_FILE")

if [[ -z "$PROMPT_TEXT" ]]; then
  echo "⚠️  Ralph-X: No prompt found. Stopping." >&2
  rm -f "$RALPH_STATE_FILE" "$RALPH_STAGES_FILE"
  exit 0
fi

update_field iteration "$NEXT_ITERATION"

# ─── Build system message ─────────────────────────────────────────
SYSTEM_MSG="🔄 Ralph-X iteration $NEXT_ITERATION"

# Pipeline info
if [[ "$PIPELINE_NAME" == "pending" ]]; then
  SYSTEM_MSG="$SYSTEM_MSG | IMPORTANT: The user has NOT selected a mode yet. You MUST show the selection menu and wait for their choice. Do NOT start working on the task yet."
  MENU_PROMPT="Show this menu to the user and ask them to pick a number (1-4):

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 How do you want to proceed?
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

 1. 🚀 Quick — Jump straight into coding. No planning.
 2. 📋 Standard — Pre-process → Develop → Post-process.
 3. 🔬 Thorough — Interview → Design → Develop → Review → Test.
 4. 🎯 Custom — Build your own pipeline step by step.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 Reply with a number (1-4) to start.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Task: $(awk '/^---$/{i++; next} i>=2' "$RALPH_STATE_FILE")"

  jq -n \
    --arg prompt "$MENU_PROMPT" \
    --arg msg "$SYSTEM_MSG" \
    '{
      "decision": "block",
      "reason": $prompt,
      "systemMessage": $msg
    }'
  exit 0
elif [[ "$PIPELINE_NAME" == "custom" ]] && [[ "$BUILDER_PHASE" != "null" ]] && [[ -n "$BUILDER_PHASE" ]]; then
  # Builder is active — build prompt for each phase
  BUILDER_PROMPT=""
  case "$BUILDER_PHASE" in
    awaiting_presets)
      PRESET_LIST=""
      if [[ -f "$RALPH_PRESETS_FILE" ]]; then
        PRESET_LIST=$(jq -r '.presets | to_entries[] | "\(.key): \(.value.label)"' "$RALPH_PRESETS_FILE" 2>/dev/null | head -10)
      fi
      SYSTEM_MSG="$SYSTEM_MSG | Custom builder: awaiting preset selection"
      BUILDER_PROMPT="You have saved pipelines:

$PRESET_LIST

Pick one by name, or say 'new' to create a new pipeline."
      ;;
    awaiting_step)
      STEP_COUNT=$(jq 'length' "$RALPH_STAGES_FILE" 2>/dev/null || echo 0)
      NEXT_STEP=$((STEP_COUNT + 1))
      if [[ $STEP_COUNT -gt 0 ]]; then
        CURRENT_PIPELINE=$(jq -r '[.[].name] | join(" → ")' "$RALPH_STAGES_FILE")
        SYSTEM_MSG="$SYSTEM_MSG | Custom builder: pipeline so far: $CURRENT_PIPELINE"
        BUILDER_PROMPT="Current pipeline: $CURRENT_PIPELINE

Step $NEXT_STEP: Then? (or say 'done' / '끝' to finish)"
      else
        SYSTEM_MSG="$SYSTEM_MSG | Custom builder: awaiting first step"
        BUILDER_PROMPT="Let's build your pipeline.

Step 1: What should I do first?"
      fi
      ;;
    awaiting_skill)
      LAST_STAGE_NAME=$(jq -r 'last.name' "$RALPH_STAGES_FILE")
      SYSTEM_MSG="$SYSTEM_MSG | Custom builder: awaiting skill for '$LAST_STAGE_NAME'"
      BUILDER_PROMPT="Any skill to use for '$LAST_STAGE_NAME'? (e.g., /review, /test, or skip)"
      ;;
    confirm)
      PIPELINE_SUMMARY=$(jq -r '[.[] | if .skill then "\(.name) (\(.skill))" else .name end] | join(" → ")' "$RALPH_STAGES_FILE")
      SYSTEM_MSG="$SYSTEM_MSG | Custom builder: awaiting confirmation"
      BUILDER_PROMPT="Your pipeline: $PIPELINE_SUMMARY

Looks good? (yes/no)"
      ;;
    save)
      SYSTEM_MSG="$SYSTEM_MSG | Custom builder: awaiting preset name"
      BUILDER_PROMPT="Save this as a preset? Give it a name, or say 'skip' to start without saving."
      ;;
  esac

  # Output builder prompt and exit early
  if [[ -n "$BUILDER_PROMPT" ]]; then
    update_field iteration "$NEXT_ITERATION"
    jq -n \
      --arg prompt "$BUILDER_PROMPT" \
      --arg msg "$SYSTEM_MSG" \
      '{
        "decision": "block",
        "reason": $prompt,
        "systemMessage": $msg
      }'
    exit 0
  fi
else
  # Normal pipeline execution
  if [[ -f "$RALPH_STAGES_FILE" ]]; then
    TOTAL_STAGES=$(jq 'length' "$RALPH_STAGES_FILE")
    STAGE_NAME=$(jq -r ".[$CURRENT_STAGE_INDEX].name // \"unknown\"" "$RALPH_STAGES_FILE")
    STAGE_SKILL=$(jq -r ".[$CURRENT_STAGE_INDEX].skill // empty" "$RALPH_STAGES_FILE")
    STAGE_NUM=$((CURRENT_STAGE_INDEX + 1))

    SYSTEM_MSG="$SYSTEM_MSG | Pipeline: $PIPELINE_NAME | Stage $STAGE_NUM/$TOTAL_STAGES: $STAGE_NAME"

    if [[ -n "$STAGE_SKILL" ]] && [[ "$STAGE_SKILL" != "null" ]]; then
      SYSTEM_MSG="$SYSTEM_MSG | Skill: $STAGE_SKILL — invoke this skill as part of this stage"
    fi

    SYSTEM_MSG="$SYSTEM_MSG | Output <ralph-advance-stage/> when this stage is complete"
  fi

  # Completion promise
  if [[ "$COMPLETION_PROMISE" != "null" ]] && [[ -n "$COMPLETION_PROMISE" ]]; then
    SYSTEM_MSG="$SYSTEM_MSG | To finish: <promise>$COMPLETION_PROMISE</promise> (ONLY when TRUE)"
  fi
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
