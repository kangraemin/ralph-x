---
name: ralph-x
description: "Build and run an AI development loop — collects pipeline, iterations, checklist, skills via conversation, then generates and executes a staged claude -p loop"
argument-hint: "[PROMPT]"
allowed-tools: [Read, Write, Bash, Glob, Grep]
---

# Ralph-X: AI Development Loop Generator

**Respond in the same language the user uses.** Korean → Korean. English → English.

## 세션 시작 시 자동 마이그레이션

**스킬이 호출되면 가장 먼저** 아래 코드를 실행한다 (사용자 확인 없이 자동):

```bash
python3 -c "
import os, shutil
old = '.claude/ralph-x-runs'
new = 'ralph-x-runs'
if os.path.isdir(old):
    os.makedirs(new, exist_ok=True)
    for item in os.listdir(old):
        src = os.path.join(old, item)
        dst = os.path.join(new, item)
        if not os.path.exists(dst):
            shutil.move(src, dst)
    if not os.listdir(old):
        os.rmdir(old)
    print('migrated')
"
```

출력이 `migrated`이면: "`.claude/ralph-x-runs/`을 `ralph-x-runs/`로 자동 이동했습니다." 한 줄 안내.
파일이 없으면 조용히 넘어간다.

## What You Do

You help the user build a multi-step `claude -p` loop. Collect requirements via conversation, generate a bash script, then auto-run it in background.

## Flow

### Step 1: Task (if not provided as argument)

Ask: "What task should I work on? / 어떤 작업을 할까요?"

### Step 2: Pipeline

First, check if `ralph-x-runs/presets.json` exists and has entries.

Show the pipeline menu. If presets exist, append them after a separator:

```
어떻게 진행할까요? / How do you want to proceed?

1. 🚀 Quick — 바로 실행 (single step)
2. 📋 Standard — 분석 → 개발 → 검증
3. 🔬 Thorough — 분석 → 설계 → 개발 → 리뷰 → 테스트
4. 🎯 Custom — 직접 스텝 조합
─────────────────────────
5. kaggle-churn
   ① 분석 — "경쟁 솔루션 상위 10개 분석" (/browse)
   ② 개발 — "LightGBM baseline 구현"
   ③ 검증 — "CV 점수 확인 후 submission 생성" (/test)
6. web-scraper
   ① 분석 — "타겟 사이트 구조 파악"
   ② 개발 — "셀레니움으로 크롤러 구현" (/browse)
```

**Preset display format**: For each preset, show steps numbered with circled digits (①②③...).
Each step line: `① {step name} — "{task_template or step description, truncated ~30 chars}" (/skill-name)`
- Only show `(/skill-name)` if the step has a non-null skill
- Truncate prompt/description to ~30 chars with `…` if longer

**If user selects a preset** (5, 6, ...): load preset config, skip to Step 2-B with preset's model as default, then Step 3 with preset's max_iterations as default, then Step 4 with preset's checklist pre-filled. Confirm and run.

If no presets exist, show only options 1-4.

If Custom: collect steps one by one ("Step 1?", "Step 2?", ... until "done"/"끝")
Each step becomes a SEPARATE `claude -p` call.
Ask if there's a skill to use per step (e.g., /browse, /review, /test, or skip)

### Step 2-B: Model

Ask: "어떤 모델로 돌릴까요? (기본: sonnet) / Which model? (default: sonnet)"

Options:
- `sonnet` (default)
- `opus`
- `haiku`
- or full model name (e.g., `claude-sonnet-4-6`)

### Step 3: Iterations

Ask: "최대 몇 회 반복? (기본 10) / Max iterations? (default 10)"

### Step 4: Completion Checklist

Ask: "완료 조건을 하나씩 알려주세요 (끝나면 '끝') / Add completion conditions one by one (say 'done' when finished)"

Collect items until done. This becomes a checklist in the prompt.

### Step 5: Confirm & Generate

Ask: "실행 방식 / Execution mode: 현재 세션에서 직접 실행 (in-session) / claude-p 루프 (기존 백그라운드, 기본값)?"

Show summary:
```
Task: ...
Model: sonnet
Pipeline: Step1 → Step2 → Step3
Iterations: 20
실행 방식: 현재 세션  (또는 claude-p 루프)
Checklist:
 - [ ] condition 1
 - [ ] condition 2
Skills: /browse (Step1), /test (Step3)
```

Ask to confirm. Then proceed to Step 5-B.

### Step 5-B: Run Directory Setup

After user confirms, before generating the script:

1. **Generate RUN_ID** from task name:
   - Slugify: lowercase, spaces/special chars → hyphens, max 20 chars
   - If using a preset, use the preset name as RUN_ID
   - Examples: "유튜브 아이디어 검증" → `youtube-idea-verify`, "Kaggle trial" → `kaggle-trial`

2. **Set RUN_DIR**: `ralph-x-runs/{RUN_ID}`

3. **Check for collision**: If RUN_DIR already exists, append suffix: `-2`, `-3`, etc.
   ```bash
   RUN_ID="<slug>"
   RUN_DIR="ralph-x-runs/$RUN_ID"
   if [ -d "$RUN_DIR" ]; then
     i=2
     while [ -d "ralph-x-runs/${RUN_ID}-${i}" ]; do i=$((i+1)); done
     RUN_ID="${RUN_ID}-${i}"
     RUN_DIR="ralph-x-runs/$RUN_ID"
   fi
   ```

4. **Check for running processes** in this project:
   ```bash
   ps aux | grep "ralph-x-runs" | grep "$(pwd)" | grep -v grep
   ```
   If found, warn the user:
   ```
   ⚠️ 이 프로젝트에서 이미 Ralph-X 루프가 실행 중입니다.
   1. 기존 루프 중단하고 새로 시작
   2. 기존 루프 유지하고 새 런 추가 (병렬)
   3. 취소
   ```

5. **`.gitignore`에 `ralph-x-runs/` 자동 추가** (없으면 생성):
   ```bash
   if ! grep -qxF 'ralph-x-runs/' .gitignore 2>/dev/null; then
     echo 'ralph-x-runs/' >> .gitignore
   fi
   ```

6. Create the directory: `mkdir -p "$RUN_DIR"`

### Step 6: Generate Script

Write prompts to temp files (one per step), then call `claude -p "$(cat file)"` for each.
Each step uses a UNIQUE heredoc delimiter (S1EOF, S2EOF, S3EOF, ...).

**CRITICAL: NEVER use `--max-turns`. Each step runs until it finishes on its own.**

Create `{RUN_DIR}/run.sh` (NOT `.claude/ralph-x-run.sh`):

```bash
#!/bin/bash
# Ralph-X Auto-generated Loop
# Task: <task>
# Pipeline: <step names>
# Max iterations: <N>
# RUN_ID: <run_id>

set -euo pipefail

RUN_DIR="ralph-x-runs/<run_id>"
MODEL="<model>"
LOG_FILE="$RUN_DIR/log.md"
CHECKLIST_FILE="$RUN_DIR/checklist.md"

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

# Write step prompts to RUN_DIR (not /tmp — OS cleans /tmp on long runs)
PROMPT_DIR="$RUN_DIR/prompts"
mkdir -p "$PROMPT_DIR"

cat > "$PROMPT_DIR/step1.txt" << 'S1EOF'
You are in a Ralph-X loop.
Task: <task>
Current step: <step 1 description>
<skill instruction if any, e.g. "Use /browse skill to crawl ...">

- Read {RUN_DIR}/log.md for previous work
- Work autonomously. Do NOT ask questions.
- Append your summary to {RUN_DIR}/log.md when done.
S1EOF

cat > "$PROMPT_DIR/step2.txt" << 'S2EOF'
You are in a Ralph-X loop.
Task: <task>
Current step: <step 2 description>

- Read {RUN_DIR}/log.md for previous work
- Work autonomously. Do NOT ask questions.
- Append your summary to {RUN_DIR}/log.md when done.
S2EOF

cat > "$PROMPT_DIR/step3.txt" << 'S3EOF'
You are in a Ralph-X loop.
Task: <task>
Current step: <step 3 description>

- Read {RUN_DIR}/log.md for previous work
- Read {RUN_DIR}/checklist.md for remaining conditions
- Work autonomously. Do NOT ask questions.
- Append your summary to {RUN_DIR}/log.md when done.
- If a checklist item is done, mark it [x] in {RUN_DIR}/checklist.md
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
  claude -p --model "$MODEL" "$(cat "$PROMPT_DIR/step1.txt")"

  # Step 2: <step 2 name>
  claude -p --model "$MODEL" "$(cat "$PROMPT_DIR/step2.txt")"

  # Step 3: <step 3 name>
  claude -p --model "$MODEL" "$(cat "$PROMPT_DIR/step3.txt")"

  echo "━━━ Iteration $i complete ━━━"
done

# Cleanup (prompts are inside RUN_DIR, keep for debugging; remove if not needed)
# rm -rf "$PROMPT_DIR"

echo "🏁 Ralph-X finished after $i iterations"
```

For conditional steps (e.g., "every 3 iterations"), wrap in an `if`:
```bash
  # Step 4: submit every 3 iterations
  if [ $((i % 3)) -eq 0 ]; then
    claude -p --model "$MODEL" "$(cat "$PROMPT_DIR/step4.txt")"
  fi
```

### Step 7: Execute

**Branch on execution mode chosen in Step 5.**

#### Step 7-A: claude-p 루프 (기본)

1. Auto-save preset to `ralph-x-runs/presets.json` (no confirmation)
2. Auto-run in background: Use Bash tool with `run_in_background: true` to run `bash {RUN_DIR}/run.sh`
3. Report: "실행 시작했습니다. 스크립트: `{RUN_DIR}/run.sh`"

Do NOT ask "실행할까요?" — just run it.

#### Step 7-B: 현재 세션 실행 (in-session)

1. **session_id 즉시 캡처** (Bash):
   ```bash
   SESSION_ID=$(ls -lt ~/.claude/worklogs/.collecting/*.jsonl 2>/dev/null \
     | awk 'NR==1{print $NF}' | xargs basename | sed 's/\.jsonl//')
   [ -z "$SESSION_ID" ] && SESSION_ID=$(ls -t ~/.claude/session-env/ 2>/dev/null | head -1)
   echo "$SESSION_ID"
   ```

2. `mkdir -p {RUN_DIR}`

3. Write tool로 `{RUN_DIR}/session-state.json` 생성:
   ```json
   {
     "active": true,
     "session_id": "<SESSION_ID>",
     "run_id": "<RUN_ID>",
     "run_dir": "ralph-x-runs/<RUN_ID>",
     "checklist_file": "ralph-x-runs/<RUN_ID>/checklist.md",
     "current_iteration": 0,
     "max_iterations": <N>
   }
   ```

4. Write tool로 `{RUN_DIR}/checklist.md` 생성 (수집한 완료 조건들):
   ```
   - [ ] condition 1
   - [ ] condition 2
   ```

5. Write tool로 `{RUN_DIR}/log.md` 생성 (초기화):
   ```
   # Ralph-X Work Log
   Task: <task>
   Mode: in-session
   ```

6. **루프 실행** (current_iteration < max_iterations AND checklist 미완인 동안):
   - `"━━━ Iteration {i}/{MAX} ━━━"` 출력
   - pipeline 각 step 내용을 **현재 대화에서 직접 수행** (claude -p 호출 금지)
     - `{RUN_DIR}/log.md` 읽어 이전 컨텍스트 파악
     - 작업 수행 후 결과를 `{RUN_DIR}/log.md`에 append
   - `{RUN_DIR}/checklist.md` 갱신 (완료 항목 `[ ]` → `[x]`)
   - Bash로 `session-state.json` current_iteration 업데이트:
     ```bash
     python3 -c "
     import json; s=json.load(open('{RUN_DIR}/session-state.json'))
     s['current_iteration']={i}
     json.dump(s,open('{RUN_DIR}/session-state.json','w'))
     "
     ```
   - checklist 전부 `[x]` 시 break

7. **완료 처리**:
   - Bash로 `session-state.json` active=false 업데이트:
     ```bash
     python3 -c "
     import json; s=json.load(open('{RUN_DIR}/session-state.json'))
     s['active']=False
     json.dump(s,open('{RUN_DIR}/session-state.json','w'))
     "
     ```
   - `"✅ Ralph 루프 완료 ({N}회 반복)"` 출력

**중요**: in-session 모드에서는 stop hook(`ralph-x-gate.sh`)이 `session-state.json`을 감시한다.
checklist 미완 + iter < max 상태에서 대화 종료 시도 시 자동으로 차단된다.

## Preset System

After generating, ALWAYS auto-save to `ralph-x-runs/presets.json`:

```json
{
  "preset-name": {
    "model": "sonnet",
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

On next `/ralph-x` invocation, check for presets. If presets exist, append them to the Step 2 pipeline menu after a separator line (`─────`). Number them continuously (5, 6, 7, ...). Each preset shows its steps with detail:

```
5. preset-name
   ① step-name — "prompt excerpt ~30chars" (/skill-name)
   ② step-name — "prompt excerpt ~30chars"
```

- Show skill in parentheses after prompt excerpt, only if skill is not null
- Truncate `task_template` to ~30 chars for the prompt excerpt. If step has a dedicated description in `steps[].name`, use that as the step name.
- If user selects a preset number, skip to Step 2-B (model) with preset's model as default, then Step 3 with preset's max_iterations as default, then Step 4 with preset's checklist pre-filled. Confirm and run.

## Rules

### claude-p 모드 (Step 7-A)
- Do NOT start working on the task. You ONLY build the script and run it.
- Each step = one `claude -p` call. NEVER combine multiple steps into one call.
- NEVER use `--max-turns` on any `claude -p` call.
- Use UNIQUE heredoc delimiters per step (S1EOF, S2EOF, S3EOF, ...). NEVER reuse delimiters.
- Write prompts to temp files first, then `claude -p "$(cat file)"`. Do NOT inline heredocs inside the for loop.
- Keep step prompts SHORT and SINGLE-PURPOSE.
- Always include log file read/write instructions in each step prompt (use `{RUN_DIR}/log.md`).
- Always include checklist check in each step prompt (use `{RUN_DIR}/checklist.md`).
- Step output files go in RUN_DIR: `{RUN_DIR}/stage1.md`, `{RUN_DIR}/stage2.md`, etc.
- Auto-save preset after generation. Do NOT ask.
- Auto-run in background after generation. Do NOT ask.

### in-session 모드 (Step 7-B)
- session_id를 캡처한 즉시 session-state.json에 기록한다. 나중으로 미루지 않는다.
- 루프 중 claude -p 호출 금지. 현재 대화 컨텍스트에서 직접 수행한다.
- 매 iteration 후 반드시 session-state.json의 current_iteration을 업데이트한다. (stop hook이 이 값으로 차단 여부 판단)
- checklist 항목 완료 시 즉시 `[ ]` → `[x]` 로 갱신한다.
- 루프 완료 후 반드시 active=false 처리한다. (미처리 시 stop hook이 계속 차단)
