# Custom Mode

User defines their own pipeline stages.

## Behavior
When custom mode is selected, ask the user:

```
Which stages do you want? (comma-separated or describe your pipeline)

Available stages:
  interview  — Ask clarifying questions first
  research   — Investigate codebase and dependencies
  design     — Architecture and API design
  plan       — Break down into tasks
  develop    — Write code with TDD
  review     — Self-review against requirements
  test       — Comprehensive testing
  refactor   — Clean up and optimize
  document   — Write docs and comments

Example: "interview, develop, test"
Example: "research, plan, develop, review"
```

Then follow the user-defined stage order.
