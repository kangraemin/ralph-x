---
description: "Start Ralph-X — interactive AI development loop with mode selection"
argument-hint: "[PROMPT] [--max-iterations N] [--completion-promise TEXT]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup.sh:*)"]
hide-from-slash-command-tool: "true"
---

# Ralph-X Command

IMPORTANT: **Respond in the same language the user is using.** If they write in Korean, respond in Korean. If English, respond in English. Match their language throughout the entire session.

Execute the setup script to initialize Ralph-X:

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/setup.sh" $ARGUMENTS
```

## If No Prompt Was Provided

The setup script will print a welcome message. **Do NOT try to exit.** Instead:

1. Ask the user what task they want to work on (in their language)
2. Wait for their response
3. Once they respond, run the setup script again WITH their response as the prompt:

```
"${CLAUDE_PLUGIN_ROOT}/scripts/setup.sh" <user's response>
```

## After Setup (With Prompt)

The setup script will show a selection menu. Wait for the user to pick a mode (1-4).

### When user picks 1 (Quick), 2 (Standard), or 3 (Thorough)

The stop hook loads the built-in pipeline. Start working on the task following the pipeline stages. Output `<ralph-advance-stage/>` when you complete each stage to move to the next one.

### When user picks 4 (Custom)

Enter the custom pipeline builder. Follow the stop hook's system messages:

1. **If saved presets exist**: Show them and ask user to pick one or create new
2. **Step builder**: Ask what the first step should be → get answer
3. **Skill binding**: Ask if there's a skill to use for that step → get answer
4. **Repeat**: Ask for next steps until user says they're done
5. **Confirm**: Show the pipeline summary, ask to confirm
6. **Save**: Ask if they want to save it as a preset

### During the Loop

- Follow the pipeline stages in order
- The system message tells you which stage you're in
- If a stage has a bound skill, invoke that skill
- Output `<ralph-advance-stage/>` when a stage is complete
- When all stages are done, the cycle restarts for the next iteration

CRITICAL RULE: If a completion promise is set, you may ONLY output it when the statement is completely and unequivocally TRUE. Do not output false promises to escape the loop.
