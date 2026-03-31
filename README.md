<p align="center">
  <h1 align="center">Ralph-X</h1>
  <p align="center">
    <strong>Interactive AI development loop with mode selection</strong>
  </p>
  <p align="center">
    Choose your pipeline before you start. Bind skills to stages. Save and reuse.
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

Most Ralph tools force a single fixed pipeline. Ralph-X asks **"How do you want to proceed?"** every time — pick the right approach for the task, bind skills to stages, save your pipelines as presets.

Built as a **Claude Code plugin** (skill + stop hook), not a `claude -p` bash loop. This means full access to skills, MCP servers, and live conversation — inside the loop.

## Quick Start

```bash
# Add marketplace & install
claude plugin marketplace add kangraemin/ralph-x
claude plugin install ralph-x@ralph-x

# Run
/ralph-x Build a REST API for todos
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

## Key Features

- **Interactive mode selection** — choose your workflow, don't get one forced on you
- **Skill binding** — attach `/review`, `/test`, or any skill to pipeline stages
- **Custom pipeline builder** — compose stages step by step, conversationally
- **Presets** — save and reuse your custom pipelines across sessions
- **Live session** — skills, MCP servers, and user interaction available mid-loop

## Why Not `claude -p`?

| | `claude -p` loop | Ralph-X |
|---|---|---|
| **Implementation** | Bash `while true` | Claude Code plugin (skill + hook) |
| **Session** | Non-interactive, fresh context each run | Interactive, persistent session |
| **Skills** | Not available | Bind to any stage |
| **MCP servers** | Not available | Full access |
| **User interaction** | None | Talk to Claude mid-loop |
| **Pipeline** | Single fixed prompt | Choose or build your own |

## Custom Pipeline Builder

Pick **Custom** and build your pipeline conversationally:

```
Step 1: What should I do first?
> Analyze existing code

Any skill to use? (e.g., /review, or skip)
> /review

Step 2: Then?
> Write tests

Any skill?
> /test

Step 3: Then?
> Implement

Step 4: Then?
> done

Pipeline: Analyze existing code (/review) → Write tests (/test) → Implement

Save as preset? (name it):
> tdd-style
```

Saved presets show up next time you pick Custom.

## Architecture

```
/ralph-x (Skill)          →  setup.sh creates state + shows menu
     ↓
stop-hook.sh (Stop Hook)  →  intercepts exit, reads transcript,
                              detects mode/stage, blocks exit,
                              feeds prompt back with stage info
     ↓
State Files               →  ralph-x.local.md  (iteration + config)
                              ralph-x-stages.json (pipeline stages)
                              ralph-x-presets.json (saved pipelines)
```

## Options

| Flag | Description |
|------|-------------|
| `--max-iterations <n>` | Auto-stop after N iterations |
| `--completion-promise <text>` | Stop when promise is genuinely true |

## Cancel

```bash
/cancel-ralph-x
```

## License

MIT
