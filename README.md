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

## License

MIT
