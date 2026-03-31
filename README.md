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

## Why Not `claude -p` Loop?

Most Ralph tools use a bash `while true` loop with `claude -p` (non-interactive mode):

```bash
# Traditional Ralph
while true; do
  claude -p "Build a todo API"
done
```

This works, but `claude -p` is non-interactive. You can't use skills, MCP servers, or talk to the agent mid-loop.

**Ralph-X takes a different approach.** It's a Claude Code **plugin** (skill + stop hook) that runs inside your live session:

| | `claude -p` loop | Ralph-X |
|---|---|---|
| **Implementation** | Bash `while true` | Claude Code plugin (skill + hook) |
| **Session** | Non-interactive, new context each run | Interactive, persistent session |
| **Skills** (`/review`, `/test`, ...) | Not available | Bind to any pipeline stage |
| **MCP servers** | Not available | Full access |
| **User interaction** | None — runs blind | Talk to Claude mid-loop |
| **Pipeline** | Single fixed prompt | Choose or build your own |
| **Presets** | None | Save and reuse custom pipelines |

## How It Works

Ralph-X is built on two Claude Code primitives: **skills** and **stop hooks**.

### Architecture

```
┌─────────────────────────────────────────┐
│  /ralph-x (Skill)                       │
│  ┌───────────────────────────────────┐  │
│  │ setup.sh                          │  │
│  │ → Show mode selection menu        │  │
│  │ → Create state file               │  │
│  │   (.claude/ralph-x.local.md)      │  │
│  └───────────────────────────────────┘  │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │ stop-hook.sh (Stop Hook)          │  │
│  │ → Intercept session exit          │  │
│  │ → Read state + transcript         │  │
│  │ → Detect mode selection / stage   │  │
│  │ → Block exit, feed prompt back    │  │
│  │ → Track iteration + stage index   │  │
│  └───────────────────────────────────┘  │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │ State Files                       │  │
│  │ → ralph-x.local.md (YAML + prompt)│  │
│  │ → ralph-x-stages.json (pipeline)  │  │
│  │ → ralph-x-presets.json (saved)    │  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

### Flow

1. **User runs `/ralph-x`** → `setup.sh` creates state file + shows menu
2. **User picks a mode** → Claude responds, then tries to exit
3. **Stop hook fires** → reads transcript, detects user's choice, loads pipeline
4. **Stop hook blocks exit** → feeds same prompt back with stage info in system message
5. **Claude works on the task** → follows pipeline stages, uses bound skills
6. **Claude outputs `<ralph-advance-stage/>`** → stop hook increments stage
7. **Repeat** until max iterations or completion promise

The key insight: by running inside a live session instead of `claude -p`, every feature of Claude Code — skills, MCP, tools, conversation — is available inside the loop.

## License

MIT
