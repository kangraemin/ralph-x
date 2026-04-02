---
name: ralph-x
description: "Build and run an AI development loop — collects pipeline, iterations, checklist, skills via conversation, then generates and executes a staged claude -p loop"
argument-hint: "[PROMPT]"
allowed-tools: [Read, Write, Bash, Glob, Grep]
---

# Ralph-X: AI Development Loop Generator

**Respond in the same language the user uses.** Korean → Korean. English → English.

## What You Do

You help the user build a multi-step `claude -p` loop. Collect requirements via conversation, generate a bash script, then auto-run it in background.

## Flow

### Step 1: Task (if not provided as argument)

Ask: "What task should I work on? / 어떤 작업을 할까요?"

### Step 2: Pipeline

Ask how to proceed:

```
어떻게 진행할까요? / How do you want to proceed?

1. 🚀 Quick — 바로 실행 (single step)
2. 📋 Standard — 분석 → 개발 → 검증
3. 🔬 Thorough — 분석 → 설계 → 개발 → 리뷰 → 테스트
4. 🎯 Custom — 직접 스텝 조합
```

If Custom: collect steps one by one ("Step 1?", "Step 2?", ... until "done"/"끝")
Each step becomes a SEPARATE `claude -p` call.
Ask if there's a skill to use per step (e.g., /browse, /review, /test, or skip)

### Step 3: Iterations

Ask: "최대 몇 회 반복? (기본 10) / Max iterations? (default 10)"

### Step 4: Completion Checklist

Ask: "완료 조건을 하나씩 알려주세요 (끝나면 '끝') / Add completion conditions one by one (say 'done' when finished)"

Collect items until done. This becomes a checklist in the prompt.

### Step 5: Confirm & Generate

Show summary:
```
Task: ...
Pipeline: Step1 → Step2 → Step3
Iterations: 20
Checklist:
 - [ ] condition 1
 - [ ] condition 2
Skills: /browse (Step1), /test (Step3)
```

Ask to confirm. Then generate the bash script.

### Step 6: Generate Script

Write prompts to temp files (one per step), then call `claude -p "$(cat file)"` for each.
Each step uses a UNIQUE heredoc delimiter (S1EOF, S2EOF, S3EOF, ...).

**CRITICAL: NEVER use `--max-turns`. Each step runs until it finishes on its own.**

Create `.claude/ralph-x-run.sh`:

```bash
#!/bin/bash
# Ralph-X Auto-generated Loop
# Task: <task>
# Pipeline: <step names>
# Max iterations: <N>

set -euo pipefail

LOG_FILE=".claude/ralph-x-log.md"
CHECKLIST_FILE=".claude/ralph-x-checklist.md"

# Initialize log (only if not exists)
if [ ! -f "$LOG_FILE" ]; then
  cat > "$LOG_FILE" << 'LOGEOF'
# Ralph-X Work Log
Task: <task>
Started: <timestamp>
LOGEOF
fi

# Initialize checklist (only if not exists)
if [ ! -f "$CHECKLIST_FILE" ]; then
  cat > "$CHECKLIST_FILE" << 'CHECKEOF'
# Completion Checklist
- [ ] condition 1
- [ ] condition 2
CHECKEOF
fi

MAX_ITER=<N>

# Write step prompts to temp files
PROMPT_DIR=$(mktemp -d)

cat > "$PROMPT_DIR/step1.txt" << 'S1EOF'
You are in a Ralph-X loop.
Task: <task>
Current step: <step 1 description>
<skill instruction if any, e.g. "Use /browse skill to crawl ...">

- Read .claude/ralph-x-log.md for previous work
- Work autonomously. Do NOT ask questions.
- Append your summary to .claude/ralph-x-log.md when done.
S1EOF

cat > "$PROMPT_DIR/step2.txt" << 'S2EOF'
You are in a Ralph-X loop.
Task: <task>
Current step: <step 2 description>

- Read .claude/ralph-x-log.md for previous work
- Work autonomously. Do NOT ask questions.
- Append your summary to .claude/ralph-x-log.md when done.
S2EOF

cat > "$PROMPT_DIR/step3.txt" << 'S3EOF'
You are in a Ralph-X loop.
Task: <task>
Current step: <step 3 description>

- Read .claude/ralph-x-log.md for previous work
- Work autonomously. Do NOT ask questions.
- Append your summary to .claude/ralph-x-log.md when done.
S3EOF

# Main loop
for i in $(seq 1 $MAX_ITER); do
  echo "━━━ Ralph-X iteration $i/$MAX_ITER ━━━"

  # Check if all checklist items are done
  if [ -f "$CHECKLIST_FILE" ] && ! grep -q '^\- \[ \]' "$CHECKLIST_FILE" 2>/dev/null; then
    echo "✅ All checklist items complete!"
    break
  fi

  # Step 1: <step 1 name>
  claude -p "$(cat "$PROMPT_DIR/step1.txt")"

  # Step 2: <step 2 name>
  claude -p "$(cat "$PROMPT_DIR/step2.txt")"

  # Step 3: <step 3 name>
  claude -p "$(cat "$PROMPT_DIR/step3.txt")"

  echo "━━━ Iteration $i complete ━━━"
done

# Cleanup
rm -rf "$PROMPT_DIR"

echo "🏁 Ralph-X finished after $i iterations"
```

For conditional steps (e.g., "every 3 iterations"), wrap in an `if`:
```bash
  # Step 4: submit every 3 iterations
  if [ $((i % 3)) -eq 0 ]; then
    claude -p "$(cat "$PROMPT_DIR/step4.txt")"
  fi
```

### Step 7: Execute

1. Auto-save preset to `.claude/ralph-x-presets.json` (no confirmation)
2. Auto-run in background: Use Bash tool with `run_in_background: true` to run `bash .claude/ralph-x-run.sh`
3. Report: "실행 시작했습니다. 스크립트: `.claude/ralph-x-run.sh`"

Do NOT ask "실행할까요?" — just run it.

## Preset System

After generating, ALWAYS auto-save to `.claude/ralph-x-presets.json`:

```json
{
  "preset-name": {
    "task_template": "...",
    "steps": [
      {"name": "...", "skill": "/browse or null"},
      {"name": "...", "skill": null},
      {"name": "...", "skill": null, "every_n": 3}
    ],
    "max_iterations": 20,
    "checklist": ["condition 1", "condition 2"]
  }
}
```

On next `/ralph-x` invocation, check for presets. If presets exist:
```
저장된 프리셋이 있습니다:
a. kaggle-churn (분석 → 개발 → 검증)

사용할 프리셋을 고르거나, 새로 만드세요.
```

## Rules

- Do NOT start working on the task. You ONLY build the script and run it.
- Each step = one `claude -p` call. NEVER combine multiple steps into one call.
- NEVER use `--max-turns` on any `claude -p` call.
- Use UNIQUE heredoc delimiters per step (S1EOF, S2EOF, S3EOF, ...). NEVER reuse delimiters.
- Write prompts to temp files first, then `claude -p "$(cat file)"`. Do NOT inline heredocs inside the for loop.
- Keep step prompts SHORT and SINGLE-PURPOSE.
- Always include log file read/write instructions in each step prompt.
- Auto-save preset after generation. Do NOT ask.
- Auto-run in background after generation. Do NOT ask.
