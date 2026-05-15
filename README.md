<div align="center">

# Ralph-X

**Turn a conversation into a self-running `claude -p` loop.**

[![License](https://img.shields.io/github/license/kangraemin/ralph-x?style=for-the-badge)](https://github.com/kangraemin/ralph-x/blob/main/LICENSE)
[![Version](https://img.shields.io/github/v/release/kangraemin/ralph-x?style=for-the-badge&label=version)](https://github.com/kangraemin/ralph-x/releases)
[![Stars](https://img.shields.io/github/stars/kangraemin/ralph-x?style=for-the-badge)](https://github.com/kangraemin/ralph-x/stargazers)

[Getting Started](#install) · [한국어](README.ko.md) · [Issues](https://github.com/kangraemin/ralph-x/issues)

</div>

---

A single `claude -p` with a long prompt loses focus as context grows. One heavy step — like web crawling — can eat all the turns and block everything else.

Ralph-X fixes this by giving **each step its own `claude -p` process**. Every step runs to completion independently. All steps finishing = one iteration.

```
/ralph-x → describe steps → set iterations → auto-run in background
```

## Install

```bash
claude plugin marketplace add kangraemin/ralph-x
claude plugin install ralph-x@ralph-x
```

## Usage

```
/ralph-x

Task?        →  "Improve Kaggle score"
Steps?       →  Analyze (/browse) → Develop → Verify
Iterations?  →  15

✅ Generated + running in background
```

## Generated Script

Ralph-X writes each prompt to a temp file, then calls `claude -p` per step:

```bash
cat > "$PROMPT_DIR/step1.txt" << 'S1EOF'
Current step: Analyze — use /browse to check discussions.
Read ralph-x-runs/<RUN_ID>/log.md for previous work.
S1EOF

cat > "$PROMPT_DIR/step2.txt" << 'S2EOF'
Current step: Develop — implement the best strategy.
Read ralph-x-runs/<RUN_ID>/log.md for previous work.
S2EOF

for i in $(seq 1 15); do
  claude -p "$(cat "$PROMPT_DIR/step1.txt")"
  claude -p "$(cat "$PROMPT_DIR/step2.txt")"
done
```

- **One step, one process** — no turn hogging
- **Unique heredoc delimiters** — no parser collisions
- **Shared log file** — bridges context between steps
- **No `--max-turns`** — each step runs until done

## Why Per-Step?

| Single `claude -p` | Ralph-X |
|---|---|
| One step blocks all others | Each step runs independently |
| Long prompt, lost focus | Short prompt per step |
| Same skill for everything | Different skill per step |

## Files

| File | Purpose |
|---|---|
| `ralph-x-runs/<RUN_ID>/run.sh` | Generated loop script |
| `ralph-x-runs/<RUN_ID>/log.md` | Context bridge between steps |
| `ralph-x-runs/<RUN_ID>/checklist.md` | Completion tracking |
| `ralph-x-runs/presets.json` | Auto-saved presets |

## Stop Hook 충돌 처리

ralph-x in-session 루프 사용 시, 본인의 다른 stop hook(예: 커밋 요구, 세션 리뷰, worklog 자동 생성)과 충돌하면 ralph-x의 "루프를 계속 진행하세요" 차단 메시지가 다른 메시지에 묻혀서 LLM이 루프를 멈추는 문제가 발생할 수 있다.

**해결**: 본인의 다른 stop hook 최상단(jq 체크 + STOP_HOOK_ACTIVE 체크 직후)에 아래 skip 로직 추가:

```bash
# ralph-x 루프 active이면 다른 stop 요구 skip (루프 진행 우선)
CWD=$(echo "$INPUT" | jq -r '.cwd // ""')
if [ -n "$CWD" ]; then
  for sf in "$CWD"/ralph-x-runs/*/session-state.json; do
    [ -f "$sf" ] || continue
    if [ "$(jq -r '.active // false' "$sf")" = "true" ]; then
      exit 0
    fi
  done
fi
```

이 로직이 있으면 ralph-x 루프 active 동안 다른 stop hook이 자체적으로 skip해서 `ralph-x-gate.sh`의 "계속 진행" 메시지만 LLM에 도달한다.

## License

MIT
