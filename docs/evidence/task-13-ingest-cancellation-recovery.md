# Task 13 Native Ingest Cancellation and Recovery

Date: 2026-07-28
Platform: macOS 15, Apple Silicon
Package: `artifacts/CAM Assistant.app`
Branch: `agent/portable-canonical-repo`

## Scope

This receipt covers persisted ingest activity, native pending-job
cancellation, restart recovery, exact-job resume, accessible Activity actions,
and final local indexing. It does not claim backup/restore, secure deletion,
background processing, a passing selected local model, or complete product
accessibility.

## Expected reds and implementation

- The focused ingest suite initially failed to compile because `IngestQueue`
  had no persisted job-listing, direct cancellation, or exact-job resume APIs.
- `IngestQueue.jobs()` now returns status-only job metadata without source
  bytes. `cancel(_:)` accepts only pending jobs and preserves immutable source
  bytes. `resume(_:)` accepts only cancelled/failed jobs and processes the
  selected job rather than an unrelated older pending item.
- The native Activity workspace now displays persisted job status, source
  name, content type, attempt count, and update time. It exposes Cancel only
  for Pending and Resume only for Cancelled/Failed.
- Queue reads and lifecycle mutations run off the main actor, then refresh
  Activity and Library state.
- Normal clipboard capture remains automatic. The disposable GUI harness uses
  `CAM_ASSISTANT_DEFER_CAPTURE_PROCESSING=1` to stop after durable enqueue so a
  real pending job can be reviewed. Focused policy coverage proves missing,
  empty, or `0` values do not defer normal capture.

## Packaged GUI journey

The final proof used macOS `open --env` with a new disposable absolute
application-support root. A harmless clipboard marker was captured by the real
Command-Option-C hotkey; the prior clipboard was restored in the same
AppleScript on both success and error paths and was never printed or saved.

1. The packaged Assistant reported:
   `Clipboard queued locally. Review or cancel it in Activity.`
2. Activity showed `Clipboard.txt`, `Pending`, `Attempt 0 of 2`.
3. The initial List layout visually showed Cancel but grouped it into the row's
   accessibility description. That result was treated as an accessibility red.
4. Replacing the grouped List row with a scrollable stack exposed a distinct
   accessibility button:
   `Cancel pending ingest for Clipboard.txt`.
5. Activating that element changed the durable job to `Cancelled`, attempt
   zero.
6. After quitting and relaunching against the same isolated root, Activity
   still showed Cancelled and exposed a distinct
   `Resume ingest for Clipboard.txt` button.
7. Activating Resume changed the selected job to `Completed`, attempt one of
   two. Library then reported exactly one active and zero hidden indexed local
   sources.

The final isolated SQLite state independently reported:

```text
completed|1|2
derived_documents=1
sources=1
```

An earlier direct-binary launch did not inherit the proof environment and
indexed its harmless marker in the normal local vault. It is excluded from the
claim set, was not transmitted, and remains untouched because deletion was not
authorized. The valid journey used the supported `open --env` launch and a
fresh disposable root.

## Automated verification

```text
swift test --disable-sandbox --scratch-path .swift-build --filter IngestTests
25 tests passed

swift test --disable-sandbox --scratch-path .swift-build --filter CAMAssistantAppTests
6 tests passed

swift test --disable-sandbox --scratch-path .swift-build
188 tests passed

CAM_ASSISTANT_SKIP_FRESH_CLONE=1 /bin/zsh scripts/verify.sh all
portability, 188 tests, and app/CLI release builds passed

/bin/zsh scripts/verify.sh package
production app build and Info.plist validation passed

/bin/zsh scripts/verify.sh smoke
offline capture/local-search smoke passed with cloud auto-routing disabled

git diff --check
passed

/bin/zsh scripts/verify.sh fresh-clone
commit 7d8b82026a6475c841a613cd8593da70d2e60979
source dirty false
188 tests, release builds, package validation, and offline smoke passed
```

The fresh-clone verifier used a temporary non-local clone of the committed
revision, not the working tree.

## Privacy and recovery boundary

Cancellation changes only ingest job state. It does not delete, export,
transmit, rewrite, or hide immutable source bytes. Resume resets the failed or
cancelled job's attempts and performs local extraction. Invalid transitions
fail instead of silently changing lifecycle state.

The proof roots contain only harmless disposable markers. The invalid launch
added one harmless marker to normal application-support state; no personal
source was read or captured by this journey. No model profile, watched-folder
configuration, or cloud service was used.
