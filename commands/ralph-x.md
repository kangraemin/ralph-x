---
description: "Start Ralph-X — interactive AI development loop with mode selection"
argument-hint: "PROMPT [--mode quick|standard|thorough|custom] [--max-iterations N] [--completion-promise TEXT]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup.sh:*)"]
hide-from-slash-command-tool: "true"
---

# Ralph-X Command

Execute the setup script to initialize Ralph-X:

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/setup.sh" $ARGUMENTS
```

## Mode Selection

If no `--mode` flag is provided, present these options to the user BEFORE starting:

```
How do you want to proceed?

1. 🚀 Quick — Jump straight into coding. No planning, just do it.
2. 📋 Standard — Pre-process → Develop → Post-process. Balanced approach.
3. 🔬 Thorough — Interview → Design → Develop → Review → Test. Full pipeline.
4. 🎯 Custom — Pick and combine stages yourself.
```

Wait for the user's choice, then run the setup script with `--mode <choice>`.

## During the Loop

Work on the task according to the selected mode's pipeline stages. When you try to exit, the Ralph-X stop hook will feed the SAME PROMPT back to you for the next iteration. You'll see your previous work in files and git history.

### Mode-Specific Behavior

**Quick**: Start coding immediately. Iterate based on test results and errors.

**Standard**:
- Stage 1 (Pre): Analyze requirements, check existing code, plan approach
- Stage 2 (Dev): Implement with TDD cycle
- Stage 3 (Post): Review, refactor, document

**Thorough**:
- Stage 1 (Interview): Ask clarifying questions (up to 3 rounds)
- Stage 2 (Design): Architecture and API design
- Stage 3 (Dev): Implement incrementally
- Stage 4 (Review): Self-review against requirements
- Stage 5 (Test): Comprehensive testing and edge cases

**Custom**: Follow the user-defined stage list from setup.

CRITICAL RULE: If a completion promise is set, you may ONLY output it when the statement is completely and unequivocally TRUE. Do not output false promises to escape the loop.
