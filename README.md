# Ralph-X

Interactive AI development loop with mode selection for Claude Code.

Most Ralph loop tools force a single fixed pipeline. Ralph-X asks **"How do you want to proceed?"** every time — choose the right approach for the task.

## Quick Start

```bash
# Add marketplace
claude plugin marketplace add kangraemin/ralph-x

# Install
claude plugin install ralph-x@ralph-x

# Run
/ralph-x Build a REST API for todos
```

Or test locally:
```bash
claude --plugin-dir /path/to/ralph-x
```

Every run starts with:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 How do you want to proceed?
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

 1. 🚀 Quick — Just code it.
 2. 📋 Standard — Pre → Dev → Post.
 3. 🔬 Thorough — Interview → Design → Dev → Review → Test.
 4. 🎯 Custom — Build your own pipeline.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Modes

| Mode | Pipeline | Best for |
|------|----------|----------|
| **Quick** | Code → Test → Iterate | Small tasks, prototypes |
| **Standard** | Pre-process → Develop → Post-process | Features, bug fixes |
| **Thorough** | Interview → Design → Develop → Review → Test | Complex features, greenfield |
| **Custom** | You build it | Everything else |

## Custom Pipeline Builder

Pick **4. Custom** and Ralph-X walks you through:

```
Step 1: What should I do first?
> 기존 코드 분석

Any skill to use? (e.g., /review, /test, or skip)
> skip

Step 2: Then?
> 테스트 작성

Any skill?
> /test

Step 3: Then?
> 구현

Any skill?
> skip

Step 4: Then?
> done

Pipeline: 기존 코드 분석 → 테스트 작성 (/test) → 구현

Save as preset? (name it, or skip):
> tdd-style
```

### Presets

Saved pipelines show up next time you pick Custom:

```
You have saved pipelines:
 a. tdd-style (기존 코드 분석 → 테스트 작성 → 구현)

Pick one, or "new" to create:
```

Presets are saved in `.claude/ralph-x-presets.json` per project.

## Skill Binding

Each pipeline stage can bind a skill (e.g., `/review`, `/test`, `/investigate`). When the loop reaches that stage, the bound skill is invoked automatically.

Built-in Thorough mode ships with `/review` on Review and `/test` on Test stages.

## Stage Advancement

Claude outputs `<ralph-advance-stage/>` when a stage is complete. The loop tracks progress and moves to the next stage.

## Options

```bash
/ralph-x Build a CLI tool --max-iterations 30
/ralph-x Fix auth bug --completion-promise "All tests passing"
```

| Flag | Description |
|------|-------------|
| `--max-iterations <n>` | Auto-stop after N iterations |
| `--completion-promise <text>` | Stop when promise is genuinely true |

## Cancel

```bash
/cancel-ralph-x
```

## How It Works

1. You provide a task
2. You pick a mode (or build a custom pipeline)
3. Claude works on the task following the pipeline stages
4. When Claude tries to exit, the stop hook feeds the same prompt back
5. Claude sees its previous work in files and iterates
6. Repeat until completion

## License

MIT
