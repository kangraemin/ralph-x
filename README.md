# Ralph-X

Interactive AI development loop with mode selection for Claude Code.

Most Ralph loop tools force you into a single fixed pipeline. Ralph-X asks **"How do you want to proceed?"** before starting — choose the right pipeline for the task.

## Modes

| Mode | Pipeline | Best for |
|------|----------|----------|
| **Quick** | Code → Test → Iterate | Small tasks, prototypes |
| **Standard** | Pre-process → Develop → Post-process | Features, bug fixes |
| **Thorough** | Interview → Design → Develop → Review → Test | Complex features, greenfield |
| **Custom** | You pick the stages | Everything else |

## Quick Start

```bash
# Install as Claude Code plugin
claude plugin add kangraemin/ralph-x

# Start with interactive mode selection
/ralph-x Build a REST API for todos

# Or specify mode directly
/ralph-x Build a REST API --mode thorough --max-iterations 30 --completion-promise "DONE"
```

When you run `/ralph-x` without `--mode`, you'll see:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 How do you want to proceed?
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

 1. 🚀 Quick — Jump straight into coding.
 2. 📋 Standard — Pre → Dev → Post.
 3. 🔬 Thorough — Interview → Design → Dev → Review → Test.
 4. 🎯 Custom — Pick and combine stages yourself.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Options

| Flag | Description |
|------|-------------|
| `--mode <mode>` | Skip selection menu: `quick`, `standard`, `thorough`, `custom` |
| `--max-iterations <n>` | Auto-stop after N iterations |
| `--completion-promise <text>` | Stop when promise is genuinely true |

## How It Works

Ralph-X uses Claude Code's **Stop hook** to create a self-referential loop:

1. You provide a task and choose a mode
2. Claude works on the task following the mode's pipeline
3. When Claude tries to exit, the stop hook intercepts
4. The same prompt is fed back — Claude sees its previous work in files
5. Repeat until completion (or max iterations)

The key difference: the pipeline **guides** how Claude approaches each iteration.

## Custom Mode

Custom mode lets you compose your own pipeline from available stages:

```
interview → research → design → plan → develop → review → test → refactor → document
```

Pick any combination: `"research, develop, test"` or `"interview, plan, develop, review"`.

## Cancel

```bash
/cancel-ralph-x
```

## Why Ralph-X?

Every existing Ralph loop tool picks one approach and forces it on every task. But a prototype doesn't need a 5-stage pipeline, and a critical feature deserves more than "just code it."

Ralph-X gives you the choice.

## License

MIT
