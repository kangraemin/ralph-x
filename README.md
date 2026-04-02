<p align="center">
  <h1 align="center">Ralph-X</h1>
  <p align="center">
    <strong>AI development loop generator for Claude Code</strong>
  </p>
  <p align="center">
    Build multi-stage <code>claude -p</code> loops through conversation.
  </p>
  <p align="center">
    <a href="#quick-start">Getting Started</a> · <a href="README.ko.md">한국어</a> · <a href="https://github.com/kangraemin/ralph-x/issues">Issues</a>
  </p>
  <p align="center">
    <a href="https://github.com/kangraemin/ralph-x/blob/main/LICENSE"><img src="https://img.shields.io/github/license/kangraemin/ralph-x?style=for-the-badge" alt="License"></a>
    <a href="https://github.com/kangraemin/ralph-x/releases"><img src="https://img.shields.io/github/v/release/kangraemin/ralph-x?style=for-the-badge&label=version" alt="Version"></a>
    <a href="https://github.com/kangraemin/ralph-x/stargazers"><img src="https://img.shields.io/github/stars/kangraemin/ralph-x?style=for-the-badge" alt="Stars"></a>
  </p>
</p>

---

Most Ralph loop tools run a single `claude -p` with one long prompt. As context grows, the agent forgets early instructions and loses focus.

Ralph-X splits work into **focused stages** — each stage runs as a separate `claude -p` call with a short, specific prompt. A log file bridges context between stages.

You build the loop through conversation: pick a pipeline, set iterations, add completion conditions, bind skills — Ralph-X generates and runs the bash script.

## Quick Start

```bash
# Install
claude plugin marketplace add kangraemin/ralph-x
claude plugin install ralph-x@ralph-x

# Run
/ralph-x
```

## Example

```
/ralph-x

What task?           →  "Improve Kaggle churn score"
Pipeline?            →  Custom: Analyze → Develop → Verify
Skills?              →  /browse (Analyze), /kaggle-trial (Verify)
Max iterations?      →  20
Completion conditions?
  1. LB score improved
  2. Trial documented
  → done

✅ Script generated → .claude/ralph-x-run.sh
Run now? → yes
```

## What It Generates

```bash
#!/bin/bash
for i in $(seq 1 20); do
  # Exit if all conditions met
  if ! grep -q '^\- \[ \]' .claude/ralph-x-checklist.md; then
    echo "✅ All done!"; break
  fi

  # Stage 1: Analyze (uses /browse)
  claude -p "Read .claude/ralph-x-log.md for context.
  Analyze current state. Use /browse to check discussions.
  Append summary to .claude/ralph-x-log.md.
  Update .claude/ralph-x-checklist.md if conditions met." \
  --max-turns 50

  # Stage 2: Develop
  claude -p "Read .claude/ralph-x-log.md for context.
  Implement the best strategy from analysis.
  Append summary to .claude/ralph-x-log.md." \
  --max-turns 50

  # Stage 3: Verify (uses /kaggle-trial)
  claude -p "Read .claude/ralph-x-log.md for context.
  Verify results. Use /kaggle-trial to document trial.
  Append summary to .claude/ralph-x-log.md.
  Update .claude/ralph-x-checklist.md if conditions met." \
  --max-turns 50
done
```

Each `claude -p` call:
- Gets a **short, focused prompt** (no context bloat)
- Has full access to **skills and MCP servers**
- Reads/writes a **shared log file** for continuity
- Checks/updates a **completion checklist**

## Features

| Feature | Description |
|---------|-------------|
| **Multi-stage** | Each stage = separate `claude -p` with clean context |
| **Skills & MCP** | Bind `/browse`, `/review`, `/test` etc. to any stage |
| **Checklist** | Loop stops when all conditions are met |
| **Log bridge** | `.claude/ralph-x-log.md` carries context across stages |
| **Presets** | Save and reuse pipeline configurations |
| **Conversational** | Build the loop through dialogue, not flags |

## Why Split Stages?

| Single `claude -p` | Multi-stage (Ralph-X) |
|--------------------|-----------------------|
| One long prompt | Short prompt per stage |
| Forgets early instructions | Fresh context each stage |
| Everything in one context | Log file bridges context |
| Hard to bind different skills | Different skill per stage |

## Files

| File | Purpose |
|------|---------|
| `.claude/ralph-x-run.sh` | Generated loop script |
| `.claude/ralph-x-log.md` | Work log (context bridge) |
| `.claude/ralph-x-checklist.md` | Completion tracking |
| `.claude/ralph-x-presets.json` | Saved presets |

## Cancel

```bash
# Stop the running script
Ctrl+C

# Clean up
rm -f .claude/ralph-x-run.sh .claude/ralph-x-log.md .claude/ralph-x-checklist.md
```

## License

MIT
