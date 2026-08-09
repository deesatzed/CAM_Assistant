# AGENTS.md

## Source of Truth

Before coding, read in order:

1. `GOAL.md`
2. `GOAL_BAREBONES.md` and/or `GOAL_DIRECTION.md` (active phase)
3. `STANDARDS.md`
4. `IMPLEMENT.md`
5. `DECISIONS.md`
6. `PROGRESS.md`
7. `TASK_QUEUE.md`
8. `GOAL_FINISH_WIKI.md` (historical/specialist only)

This checkout is a **standalone** git repository. Do not assume parent
workspace paths. Prefer repository-relative scripts under `scripts/`.

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
