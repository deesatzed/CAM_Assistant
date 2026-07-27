# CAM-013 Integrity-Checked Raw Source Inspection Receipt

**Date:** 2026-07-27

## Contract

- Raw-source inspection is an explicit native Library action; source bytes are
  never displayed automatically.
- Every read validates a lowercase 64-character SHA-256 content identity before
  resolving its object path.
- Every object is re-hashed at read time. Missing, unsafe, or tampered objects
  fail closed and are not displayed.
- The stored byte count must match the verified object.
- UTF-8 text previews are limited to at most 10,000 characters and report
  truncation.
- Binary, non-text, and invalid UTF-8 content exposes verified metadata only;
  arbitrary bytes are never rendered as text.
- Hidden sources remain inspectable because visibility is reversible metadata,
  not deletion.
- Inspection never changes source bytes, provenance, lifecycle, derived
  documents, or retention state.

## Verification

| Command | Result |
|---|---|
| Focused `StorageTests` | PASS — 6 tests |
| Focused `IngestTests` | PASS — 22 tests |
| `CAM_ASSISTANT_SKIP_FRESH_CLONE=1 /bin/zsh scripts/verify.sh all` | PASS — 172 tests plus app/CLI release builds |
| `/bin/zsh scripts/verify.sh package` | PASS — production app and valid `Info.plist` |
| `/bin/zsh scripts/verify.sh smoke` | PASS — offline capture/local-search smoke |
| `git diff --check` | PASS |

The expected-red build failed on the absent invalid-ID and integrity-mismatch
errors plus the absent typed raw-source inspection API before implementation.

## Non-claims

- Inspection is not source editing, deletion, export, or secure erasure.
- The bounded preview is not a file-format renderer or media viewer.
- A verified object hash proves local byte identity, not the truth or safety of
  the source's claims.
- Packaged GUI automation remains a separate proof gate.
