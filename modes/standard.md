# Standard Mode

Balanced 3-stage pipeline. Good for most tasks.

## Pipeline
1. **Pre-process** — Analyze requirements, check existing code, plan approach
2. **Develop** — Implement with TDD (write test → implement → verify)
3. **Post-process** — Review, refactor, clean up, document

## Behavior
- Stage 1 runs once at the start
- Stage 2 is the main loop (iterates until implementation is solid)
- Stage 3 runs when development is stable
- Each iteration tracks which stage it's in
- Best for: features, bug fixes, moderate complexity
