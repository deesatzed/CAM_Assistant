# CAM Assistant Standards

## Engineering

- Swift 6 strict concurrency and explicit ownership boundaries.
- Small protocols, typed errors, dependency injection, and deterministic core
  logic.
- Atomic writes, reversible migrations, stable identifiers, and no hidden
  mutable global state.

## Repository Awareness

- Read `GOAL.md`, `STANDARDS.md`, `IMPLEMENT.md`, `DECISIONS.md`,
  `PROGRESS.md`, and `TASK_QUEUE.md` before coding.
- Preserve all user and donor changes.
- Record donor origin, commit, license, and adapted files before copying code.

## Security and Privacy

- Local-first and fail-closed for restricted data.
- Never print, persist, transmit, or commit secret values.
- LLM output is advice, never authority.
- Network, execute, mutate, delete, account, and spend actions use typed
  permission classes.
- Tests use synthetic privacy fixtures only.

## Testing

- Test-driven development for every behavior.
- Observe the intended failing test before implementation.
- Use temporary directories and isolated databases.
- Keep unit, integration, conformance, privacy, benchmark, accessibility, and
  packaging evidence distinct.
- Never weaken tests to make a change pass.

## UI and UX

- Native SwiftUI, keyboard-first, VoiceOver-labeled, reduced-motion aware.
- Normal use remains simple; advanced details are discoverable.
- Every background task has status, cancellation, failure, and recovery.
- Every risky action explains access, changes, sensitivity, approval, and undo.

## Performance

- Avoid blocking the main actor with file, database, model, or network work.
- Capture acknowledges within one second on the reference Mac.
- Warm deterministic retrieval targets 500 ms p95 on the frozen suite.
- Measure before making performance claims.

## Documentation

- Current behavior, future plans, and limitations remain distinguishable.
- Commands and benchmark claims must point to saved current evidence.
- Meaningful decisions go in `DECISIONS.md`; verified progress goes in
  `PROGRESS.md`.

## Agent Behavior

- Work in small verified batches.
- Make safe assumptions, record them, and continue.
- Stop only for the conditions in the controlling goal.
- Do not claim completion from intent, smoke tests, or indirect evidence.

## Definition of Done

Done means every controlling proof gate passes, current Git status is reported,
all relevant tests are green, `git diff --check` passes, and no required work
remains.
