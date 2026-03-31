---
description: "Start Ralph-X — interactive AI development loop with mode selection"
argument-hint: "PROMPT [--max-iterations N] [--completion-promise TEXT]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup.sh:*)"]
hide-from-slash-command-tool: "true"
---

# Ralph-X Command

Execute the setup script to initialize Ralph-X:

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/setup.sh" $ARGUMENTS
```

## After Setup

The setup script will show a selection menu. Wait for the user to pick a mode (1-4).

### When user picks 1 (Quick), 2 (Standard), or 3 (Thorough)

The stop hook loads the built-in pipeline. Start working on the task following the pipeline stages. Output `<ralph-advance-stage/>` when you complete each stage to move to the next one.

### When user picks 4 (Custom)

Enter the custom pipeline builder. Follow the stop hook's system messages:

1. **If saved presets exist**: Show them and ask user to pick one or create new
2. **Step builder**: Ask "Step 1: What should I do first?" → get answer
3. **Skill binding**: Ask "Any skill to use? (e.g., /review, /test, or skip)" → get answer
4. **Repeat**: Ask "Step N: Then?" until user says "done" / "끝"
5. **Confirm**: Show the pipeline summary, ask to confirm
6. **Save**: Ask "Save as preset? (name it, or skip)"

### During the Loop

- Follow the pipeline stages in order
- The system message tells you which stage you're in
- If a stage has a bound skill, invoke that skill
- Output `<ralph-advance-stage/>` when a stage is complete
- When all stages are done, the cycle restarts for the next iteration

CRITICAL RULE: If a completion promise is set, you may ONLY output it when the statement is completely and unequivocally TRUE. Do not output false promises to escape the loop.
