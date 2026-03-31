---
description: "Start Ralph-X — interactive AI development loop with mode selection"
argument-hint: "[PROMPT] [--max-iterations N] [--completion-promise TEXT]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup.sh:*)"]
hide-from-slash-command-tool: "true"
---

# Ralph-X Command

IMPORTANT: **Respond in the same language the user is using.** Korean → Korean. English → English.

Execute the setup script:

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/setup.sh" $ARGUMENTS
```

## Setup Flow

The stop hook guides you through setup in order:

1. **Mode selection** — user picks 1-4
2. **Max iterations** — user sets a safety limit
3. **Completion checklist** — user adds conditions one by one, then says "done"/"끝"
4. **Loop starts** — autonomous mode

If no prompt was provided, ask the user what they want to work on, then re-run setup.sh with their answer.

## During the Loop — AUTONOMOUS MODE

**DO NOT ask the user questions. DO NOT wait for confirmation. Make decisions yourself.**

- Follow the pipeline stages in order
- If a stage has a bound skill, invoke it
- Output `<ralph-advance-stage/>` when a stage is complete
- When a checklist condition is met, output `<ralph-check id="N"/>` (N = 0-indexed)
- When all checklist items are done, the loop ends automatically
- If unsure about something, pick the best option and proceed
- Only pause if something is truly impossible without user input

## Tags Reference

**Checklist complete** — when a condition is met:
```
Tests are all passing. <ralph-check id="0"/>
```

**Stage complete** — when a pipeline stage is done:
```
Pre-processing complete. <ralph-advance-stage/>
```

**Iteration log** — at the END of every response, write a brief summary:
```
<ralph-log>
- Analyzed 52 OOF files
- Best single model: RealMLP (0.91945)
- Implemented Hill Climbing ensemble
- New best: 0.91964 (+0.00019)
</ralph-log>
```
This log is saved to `.claude/ralph-x-log.md` and fed back to you in subsequent iterations. Even if context is compressed, you can read the log to continue where you left off.

CRITICAL RULE: If a completion promise is set, output it ONLY when genuinely TRUE.
