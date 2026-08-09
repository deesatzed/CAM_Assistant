# CAM Assistant Second-Mac Test Results

Complete this after the checklist. Record observed results only. A waived,
skipped, or untested behavior is not a pass.

## Run identity

- Run ID:
- Tester:
- Date started:
- Date finished:
- Mac model:
- Apple chip:
- Memory:
- macOS version:
- Display resolution/scaling:
- Build commit:
- App obtained by: Git clone and local package / other
- Local AI application:
- Local model name and exact ID:
- Network state during offline sections:
- Network state during Local AI sections:

## Counts

Count tests, not individual checkbox marks.

| Result | Count |
|---|---:|
| Completed |  |
| Pass |  |
| Problem |  |
| Confusing |  |
| Enhancement |  |
| Skipped |  |
| Blocked by safety stop |  |

## Section results

Use `PASS`, `PASS WITH IMPROVEMENTS`, `INCOMPLETE`, or `STOPPED FOR SAFETY`.

| Section | Result | Most important observation | Report IDs |
|---|---|---|---|
| Installation and first launch |  |  |  |
| Home and navigation |  |  |  |
| Save Clipboard |  |  |  |
| Library and search |  |  |  |
| Ask without Local AI |  |  |  |
| Keep and Undo |  |  |  |
| Direction |  |  |  |
| Live Local AI Ask and Talk |  |  |  |
| Watched folder |  |  |  |
| Restart and persistence |  |  |  |
| Backup and fresh restore |  |  |  |
| Accessibility and ease |  |  |  |
| Repeat without instructions |  |  |  |

## Problem-report index

| Report ID | Test ID | Classification | Severity | Short title | Evidence filename |
|---|---|---|---|---|---|
| P01 |  |  |  |  |  |
| P02 |  |  |  |  |  |
| P03 |  |  |  |  |  |

Add rows as needed. Do not combine unrelated observations merely to keep the
list short.

## Safety review

- Did any stop rule occur? yes / no
- If yes, which rule and report ID?
- Did any original watched-folder file change? yes / no / not tested
- Did restore overwrite live data? yes / no / not tested
- Did an unsupported claim appear as sourced fact? yes / no / not tested
- Did any unexpected cloud/provider use appear? yes / no / unknown
- Did any screenshot or recording capture sensitive information? yes / no
- If yes, was it redacted or withheld? yes / no / not applicable

## Expected-fact review

| Expected fact | Correctly retrieved | Correct source opened | Notes |
|---|---|---|---|
| Planning call is at 10:00 AM | yes / no / not tested | yes / no / not tested |  |
| Planning call is in the east office | yes / no / not tested | yes / no / not tested |  |
| Bring the blue folder | yes / no / not tested | yes / no / not tested |  |
| Garden key is in the kitchen drawer | yes / no / not tested | yes / no / not tested |  |
| Purple lighthouse answer was refused | yes / no / not tested | not applicable |  |

## Persistence review

| State | Present after restart | Present in backup/restore | Notes |
|---|---|---|---|
| Captured clipboard source | yes / no / not tested | yes / no / not tested |  |
| Watched-folder source | yes / no / not tested | yes / no / not tested |  |
| Kept memory not undone | yes / no / not applicable | yes / no / not tested |  |
| Jordan Lee | yes / no / not tested | yes / no / not tested |  |
| Promise and north star | yes / no / not tested | yes / no / not tested |  |
| Restored watcher paused | not applicable | yes / no / not tested |  |

## Plain-language assessment

### 1. Would I trust this app with ordinary personal notes?

- [ ] Yes
- [ ] Not yet
- [ ] Unsure

Why?

> 

### 2. Could I repeat the main workflow without instructions?

- [ ] Yes
- [ ] Partly
- [ ] No

Where would I hesitate?

> 

### 3. What single change would improve the app most?

> 

## Additional ratings

Rate from 1 (very poor) to 5 (excellent).

- Ease of first launch: /5
- Ease of saving: /5
- Ease of finding and opening a source: /5
- Trust in supported versus unsupported answers: /5
- Ease of Keep and Undo: /5
- Ease of Direction: /5
- Ease of Local AI setup and use: /5
- Ease of backup and restore: /5
- Overall confidence: /5

## Final observed verdict

Choose one:

- [ ] **PASS:** every required test passed with no unresolved safety, data,
      grounding, or core-workflow defect.
- [ ] **PASS WITH IMPROVEMENTS:** the core journey worked, and remaining reports
      concern bounded usability or enhancement work.
- [ ] **INCOMPLETE:** one or more required tests were skipped or blocked without
      a safety failure.
- [ ] **STOPPED FOR SAFETY:** a privacy, data-loss, unsupported-fact, source
      mutation, or unsafe-restore stop rule occurred.

Final explanation:

> 

## Honest boundary

This completed record is human test evidence for one Mac, build, tester, and
model. It does not automatically change a goal, reverse a waiver, prove all
hardware configurations, or make the unsigned app signed/notarized production
software. Review the reports before changing any product or release claim.
