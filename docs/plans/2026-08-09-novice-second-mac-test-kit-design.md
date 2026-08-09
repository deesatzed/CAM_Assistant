# Novice Second-Mac Test Kit Design

**Status:** Approved by the product owner on 2026-08-09  
**Tester:** Product owner using a different Mac  
**Environment:** CAM Assistant and a local Ollama or LM Studio model are already installed

## Purpose

Create a plain-language, check-off testing kit that lets one non-developer-style
tester verify the complete ordinary CAM Assistant journey on another Mac. The
kit must explain what each feature should do, make expected results visible,
and make bugs, confusion, and enhancement requests easy to record without
asking the tester to diagnose technical causes.

## Deliverables

The kit lives under `docs/pilots/` and contains four files:

1. `NOVICE_TEST_START_HERE.md` — preparation, privacy precautions, synthetic
   test data, app/model readiness, evidence naming, and safe stop rules.
2. `NOVICE_TEST_CHECKLIST.md` — numbered test journeys with actions, expected
   results, result checkboxes, and evidence prompts.
3. `NOVICE_TEST_PROBLEM_REPORT.md` — a reusable report template for a bug,
   confusing experience, or enhancement request.
4. `NOVICE_TEST_RESULTS.md` — a run-level summary containing environment,
   completed sections, overall outcomes, report links, and final trust/ease
   questions.

Existing human-pilot protocols remain evidence history. This kit makes their
coverage easier for the product owner to execute and does not rewrite or claim
the waived human gates as passed.

## Test Sequence

The checklist follows the product in a realistic order:

1. Install and first launch.
2. Home and primary navigation.
3. Save Clipboard and duplicate handling.
4. Library recognition, search, and source inspection.
5. Model-free Ask, supported/unsupported results, and citations.
6. Keep, duplicate/update choice, restart persistence, and Undo.
7. Direction people, promises, completion, and persistence.
8. Live Local AI Ask and Direction Talk with cite-or-admit expectations.
9. Watched-folder capture and non-destructive source handling.
10. Restart and persistence.
11. Backup, validation, and fresh-root restore.
12. Keyboard, readability, accessibility, privacy understanding, and overall
    ease of use.
13. Final assessment.

The journey uses prepared fictional content with known expected answers. The
tester must not use passwords, credentials, financial information, health
information, private third-party material, or other sensitive content.

## Per-Test Structure

Every test includes:

- the user-facing purpose;
- setup or prerequisite state;
- exact actions in plain language;
- what should happen;
- result choices: `Pass`, `Problem`, `Confusing`, and `Enhancement`;
- an evidence prompt for a screenshot, screen recording, or exact visible text;
- a reference to the reusable problem-report template; and
- a safety instruction telling the tester whether it is safe to continue.

The kit must not tell the tester that an unexpected result is acceptable merely
because automated tests pass.

## Problem and Enhancement Recording

Each copied problem report records:

- test number and feature;
- classification: bug, confusion, or enhancement;
- severity: blocked, difficult, annoying, or suggestion;
- expected and actual behavior;
- exact steps immediately before the observation;
- repeatability;
- exact visible error text;
- screenshot or recording filename;
- whether restart changed the result;
- privacy confirmation; and
- the tester's preferred improvement, when applicable.

The tester records observations rather than diagnosing implementation causes.

## Safety and Stop Rules

Stop the run immediately and preserve evidence if CAM Assistant appears to:

- send content somewhere unexpected;
- overwrite or delete existing data;
- modify the original watched-folder file;
- invent a supported answer without a matching source;
- restore over live application data; or
- expose credentials or private content.

Record ordinary wording problems, navigation confusion, isolated feature
failures, and enhancement ideas, then continue when doing so cannot risk data.

## Completion and Verdict

The result summary distinguishes:

- completed tests from skipped or blocked tests;
- observed passes from waived or untested behavior;
- functional defects from usability confusion;
- optional Local AI behavior from offline core behavior; and
- a local test build from signed/notarized public-release readiness.

The tester finishes by answering:

1. Would I trust this app with ordinary personal notes?
2. Could I repeat the main workflow without instructions?
3. What single change would improve it most?

No human gate or production-readiness claim changes automatically. Results must
be reviewed before updating goals, gate status, or release claims.
