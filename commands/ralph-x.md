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

## Checklist Tags

When you complete a checklist item, output the tag inline:

```
Tests are all passing. <ralph-check id="0"/>
```

The stop hook reads these tags and marks items as done.

## Stage Tags

When a pipeline stage is complete:

```
Pre-processing complete. <ralph-advance-stage/>
```

CRITICAL RULE: If a completion promise is set, output it ONLY when genuinely TRUE.
