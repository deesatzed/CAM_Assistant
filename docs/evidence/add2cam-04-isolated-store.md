# ADD2CAM-04 Isolated Meaning Preview Store (Initial Slice)

Date: 2026-07-30

The pilot now has a separate CAM-owned SQLite database at:

```text
<CAM application-support root>/CAMAssistant/meaning-preview/MeaningPreview.sqlite
```

It uses a dedicated v1 schema and a singleton, atomically updated snapshot.
The primary CAM vault schema and URL are not referenced. A focused temporary-
root test proves saving/reloading an encoded MeaningCore `CoreState` plus
identifier-only provenance does not alter primary-vault bytes.

Verification:

```text
swift test --disable-sandbox --scratch-path .swift-build-meaning-preview \
  --filter MeaningPreviewTests
swift test --disable-sandbox --scratch-path .swift-build-meaning-preview \
  --filter StorageTests
```

Both focused suites passed (3 Meaning Preview tests; 8 existing storage tests).

This is an initial persistence slice, not Gate 3 completion. Archive/
reinitialize recovery, malformed-state recovery presentation, full backup
boundary, disable lifecycle, and durable feedback/decision receipts remain for
the coordinator and native-workspace tasks.
