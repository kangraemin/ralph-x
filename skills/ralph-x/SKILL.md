---
name: ralph-x
description: "Build and run an AI development loop — collects pipeline, iterations, checklist, skills via conversation, then generates and executes a staged claude -p loop"
argument-hint: "[PROMPT]"
allowed-tools: [Read, Write, Bash, Glob, Grep]
---

# Ralph-X: AI Development Loop Generator

**Respond in the same language the user uses.** Korean → Korean. English → English.

## What You Do

You help the user build a multi-stage `claude -p` loop. Collect requirements via conversation, generate a bash script, then run it.

## Flow

### Step 1: Task (if not provided as argument)

Ask: "What task should I work on? / 어떤 작업을 할까요?"

### Step 2: Pipeline

Ask how to proceed:

```
어떻게 진행할까요? / How do you want to proceed?

1. 🚀 Quick — 바로 실행 (single stage)
2. 📋 Standard — 분석 → 개발 → 검증
3. 🔬 Thorough — 분석 → 설계 → 개발 → 리뷰 → 테스트
4. 🎯 Custom — 직접 스테이지 조합
```

If Custom: collect stages one by one ("Step 1?", "Step 2?", ... until "done"/"끝")
For each stage, ask if there's a skill to use (e.g., /browse, /review, /test, or skip)

### Step 3: Iterations

Ask: "최대 몇 회 반복? (기본 10) / Max iterations? (default 10)"

### Step 4: Completion Checklist

Ask: "완료 조건을 하나씩 알려주세요 (끝나면 '끝') / Add completion conditions one by one (say 'done' when finished)"

Collect items until done. This becomes a checklist in the prompt.

### Step 5: Confirm & Generate

Show summary:
```
Task: ...
Pipeline: Stage1 → Stage2 → Stage3
Iterations: 20
Checklist:
 - [ ] condition 1
 - [ ] condition 2
Skills: /browse (Stage1), /test (Stage3)
```

Ask to confirm. Then generate the bash script.

### Step 6: Generate Script

Create `.claude/ralph-x-run.sh`:

```bash
#!/bin/bash
# Ralph-X Auto-generated Loop
# Task: <task>
# Pipeline: <stages>
# Max iterations: <N>

set -euo pipefail

LOG_FILE=".claude/ralph-x-log.md"
CHECKLIST_FILE=".claude/ralph-x-checklist.md"

# Initialize log
cat > "$LOG_FILE" << 'LOGEOF'
# Ralph-X Work Log
Task: <task>
Started: <timestamp>
LOGEOF

# Initialize checklist
cat > "$CHECKLIST_FILE" << 'CHECKEOF'
# Completion Checklist
- [ ] condition 1
- [ ] condition 2
CHECKEOF

MAX_ITER=<N>

for i in $(seq 1 $MAX_ITER); do
  echo "━━━ Ralph-X iteration $i/$MAX_ITER ━━━"

  # Check if all checklist items are done
  if ! grep -q '^\- \[ \]' "$CHECKLIST_FILE" 2>/dev/null; then
    echo "✅ All checklist items complete!"
    break
  fi

  # Stage 1: <stage name>
  claude -p "$(cat << 'PROMPTEOF'
You are in a Ralph-X loop. Iteration $i/$MAX_ITER.

Task: <task>
Current stage: <stage 1 name>
<skill instruction if any>

IMPORTANT:
- Read .claude/ralph-x-log.md for previous work
- Read .claude/ralph-x-checklist.md for remaining conditions
- Work autonomously. Do NOT ask questions.
- At the end, append your summary to .claude/ralph-x-log.md
- If a checklist item is done, mark it [x] in .claude/ralph-x-checklist.md
PROMPTEOF
)" --max-turns 50

  # Stage 2: <stage name>
  claude -p "..." --max-turns 50

  # ... more stages

  echo "━━━ Iteration $i complete ━━━"
done

echo "🏁 Ralph-X finished after $i iterations"
```

Key principles for script generation:
- Each stage is a SEPARATE `claude -p` call with a focused prompt
- Log file (`.claude/ralph-x-log.md`) bridges context between stages
- Checklist file (`.claude/ralph-x-checklist.md`) tracks completion
- `grep -q '^\- \[ \]'` checks if unchecked items remain
- Stage prompts are SHORT and specific
- Include skill invocation instructions in the stage prompt (e.g., "Use /browse to crawl the page")
- `--max-turns 50` per stage (adjustable)

### Step 7: Execute

Ask: "바로 실행할까요? / Run now?"

If yes: `bash .claude/ralph-x-run.sh`
If no: "스크립트가 .claude/ralph-x-run.sh에 저장되었습니다. `bash .claude/ralph-x-run.sh`로 실행하세요."

## Preset System

After generating, ask: "프리셋으로 저장할까요? / Save as preset?"

If yes, save to `.claude/ralph-x-presets.json`:
```json
{
  "preset-name": {
    "task_template": "...",
    "stages": [...],
    "max_iterations": 20,
    "checklist": [...]
  }
}
```

On next `/ralph-x` invocation, check for presets:
```
저장된 프리셋이 있습니다:
a. kaggle-churn (분석 → 개발 → 검증)

사용할 프리셋을 고르거나, 새로 만드세요.
```

## Rules

- Do NOT start working on the task. You ONLY build the script.
- Keep stage prompts SHORT (under 500 chars each)
- Always include log file read/write instructions in each stage prompt
- Always include checklist check in each stage prompt
- Use `--max-turns 50` as default, adjustable per stage
