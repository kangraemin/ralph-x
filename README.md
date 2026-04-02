<p align="center">
  <h1 align="center">Ralph-X</h1>
  <p align="center">
    <strong>AI development loop generator for Claude Code</strong>
  </p>
  <p align="center">
    Build multi-stage <code>claude -p</code> loops via conversation. Skills and MCP included.
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

Ralph-X generates multi-stage `claude -p` loop scripts through conversation. Tell it what you want, pick a pipeline, set completion conditions — it builds and runs the script for you.

Each stage runs as a separate `claude -p` call with full access to **skills and MCP servers**. A shared log file bridges context between stages.

## Quick Start

```bash
# Install
claude plugin marketplace add kangraemin/ralph-x
claude plugin install ralph-x@ralph-x

# Run
/ralph-x
```

## How It Works

```
/ralph-x

What task?          → "Improve Kaggle score"
Pipeline?           → Custom: Analyze → Develop → Verify
Max iterations?     → 20
Completion conditions? → "LB score improved", "trial documented"
Skills?             → /browse (Analyze), /kaggle-trial (Verify)

→ Generates .claude/ralph-x-run.sh
→ Runs it
```

The generated script:

```bash
for i in $(seq 1 20); do
  # Check if all conditions met
  if ! grep -q '^\- \[ \]' .claude/ralph-x-checklist.md; then
    echo "✅ All done!"
    break
  fi

  # Stage 1: Analyze (with /browse)
  claude -p "Read log, analyze current state, use /browse..." --max-turns 50

  # Stage 2: Develop
  claude -p "Read log, implement best strategy..." --max-turns 50

  # Stage 3: Verify (with /kaggle-trial)
  claude -p "Read log, verify results, use /kaggle-trial..." --max-turns 50
done
```

## Key Features

- **Conversational setup** — build your loop through dialogue
- **Multi-stage** — each stage is a separate `claude -p` call (focused, no context bloat)
- **Skills & MCP** — bind `/browse`, `/review`, `/test`, or any skill to stages
- **Checklist completion** — loop stops when all conditions are met
- **Log file bridge** — `.claude/ralph-x-log.md` carries context across stages
- **Presets** — save and reuse pipeline configurations

## Why Not a Single `claude -p`?

A single long `claude -p` call forgets early instructions as context grows. Ralph-X splits work into focused stages — each gets a clean context with only the log file for continuity.

## Architecture

```
/ralph-x (Skill)
  ↓ conversation
Collect: task, pipeline, iterations, checklist, skills
  ↓ generate
.claude/ralph-x-run.sh    (staged claude -p loop)
.claude/ralph-x-log.md    (context bridge between stages)
.claude/ralph-x-checklist.md (completion tracking)
  ↓ execute
bash .claude/ralph-x-run.sh
```

No hooks. No state files. Just a skill that writes a script.

## Cancel

```bash
# Kill the running script
Ctrl+C

# Clean up
rm -f .claude/ralph-x-run.sh .claude/ralph-x-log.md .claude/ralph-x-checklist.md
```

## License

MIT
