# AGENTS.md

## Source of Truth

Before coding, read in order:

1. `GOAL.md`
2. `STANDARDS.md`
3. `IMPLEMENT.md`
4. `DECISIONS.md`
5. `PROGRESS.md`
6. `TASK_QUEUE.md`
7. `../GOAL_LLM_WIKI.md`

## Autonomous Progress

Make and document safe assumptions. Continue until a real stop condition in the
controlling goal occurs. Preserve user and donor changes.

## Development

- Use test-driven development.
- Work in small verified batches.
- Update progress and decisions.
- Do not weaken tests or safety gates.
- Do not modify donor repos without a separately approved, bounded task.
- Do not print secrets or mutate live databases during read-only work.

## Core Rule

Codex decides. Contributors advise. Tests arbitrate. Markdown remembers.
