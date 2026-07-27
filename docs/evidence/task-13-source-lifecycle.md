# CAM-013 Reversible Local Source Lifecycle Receipt

**Date:** 2026-07-27

## Contract

- Every previously ingested source defaults to Active.
- Hide is reversible local visibility metadata, not deletion.
- A hidden source is excluded from active Library rows, exact citation
  navigation, and database-backed local conversation context.
- The native Library lists hidden sources separately and offers an explicit
  Restore action.
- Content-addressed source bytes, capture provenance, derived-document history,
  and retained citations are never rewritten by hide or restore.
- Lifecycle state persists across process/database restart.

## Verification

| Command | Result |
|---|---|
| Focused `IngestTests` | PASS — 20 tests |
| `/bin/zsh scripts/verify.sh conversation` | PASS — 5 tests |
| Focused `StorageTests` | PASS — 4 tests |
| `CAM_ASSISTANT_SKIP_FRESH_CLONE=1 /bin/zsh scripts/verify.sh all` | PASS — 168 tests plus app/CLI release builds |
| `/bin/zsh scripts/verify.sh package` | PASS — production app and valid `Info.plist` |
| `/bin/zsh scripts/verify.sh smoke` | PASS — offline capture/local-search smoke |
| `git diff --check` | PASS |
| `/bin/zsh scripts/verify.sh fresh-clone` | PASS — commit `a80367a`, 168 tests, release builds, package, and smoke |

The lifecycle restart test reads the exact original bytes after hide and
restore, confirms the object count remains one, and compares all provenance
records before and after the transition.

## Non-claims

- Hidden does not securely delete or erase source bytes.
- This batch does not expose unrestricted raw binary content in the UI.
- A citation retained elsewhere is not altered; opening it from the active
  Library remains unavailable until the source is restored.
- Packaged GUI automation, real global-hotkey dispatch, and background watched
  source lifecycle remain separate proof gates.
