---
description: "Cancel active Ralph-X loop"
allowed-tools: ["Bash(rm -f .claude/ralph-x.local.md .claude/ralph-x-stages.json .claude/ralph-x-checklist.json .claude/ralph-x-log.md:*)"]
---

# Cancel Ralph-X

```!
rm -f .claude/ralph-x.local.md .claude/ralph-x-stages.json .claude/ralph-x-checklist.json .claude/ralph-x-log.md && echo "🛑 Ralph-X loop cancelled."
```
