# Repository Evidence and Idea Review Design

## Goal

Complete the user-visible bridge from an explicitly selected local repository
to commit-cited observations and a reviewable idea-card proposal. This is a
local evidence workflow, not autonomous repository analysis, code reuse, CAM
mining, or implementation execution.

## Chosen approach

After an explicit repository inspection of a clean committed snapshot, the
user may request a local observation scan. The app displays only the existing
deterministic observations: literal TODO/FIXME markers and committed Swift
declarations, each with commit, file, line, symbol, and statement.

The user may select one observation and draft an idea card by supplying the
required counterevidence and smallest validation experiment. The app derives
the evidence and license from the recorded snapshot, validates the card, and
creates only a `RepositoryIdeaProposal` for review. It never writes the donor
repository, copies code, creates a task, invokes CAM, or claims the idea is
true.

## Why not automatic idea generation

The existing observation extractor intentionally makes no architectural or
behavior claim. Automatically generating an idea card would fabricate
counterevidence, confidence, and a validation plan. Requiring the user to
provide those fields preserves the contract that an idea is a candidate with
explicit uncertainty.

## Boundaries

- The source must be an explicitly entered local Git repository.
- Observations are read from the recorded commit only and refuse dirty
  snapshots, preserving reproducibility.
- The scan is read-only and foreground-only. It does not persist repository
  text, index extra files, or change the repository.
- An idea-card proposal is ephemeral until a later explicit retention/promotion
  path exists. Its only output here is a typed proposal receipt in the native
  view.
- CAM mining remains disabled and separate exact approval remains required.

## UI flow

```text
Inspect clean local repository
    -> Scan committed observations
    -> inspect commit/file/line/symbol evidence
    -> select one observation
    -> enter title + counterevidence + validation experiment
    -> Create proposal-only idea card
    -> show proposal commit and idea ID
```

## Verification

Core tests must prove presentation contains exact cited evidence and that a
user-provided card promotes only when its selected observation belongs to the
recorded snapshot. A dirty snapshot must remain visibly unavailable. App build
verification must prove the view compiles; a package/smoke run cannot be used
as evidence that a real repository was inspected or that a proposal was
endorsed.
