# Barebones Packaged Journey Evidence

**Date:** 2026-08-06

**Implementation revision:** `d22f7e5b13509e977cbab6ab742ce49643f82e79`

**Machine-gate status:** PASS

**Human-gate status:** PENDING

## What this proves

The repository-owned test rebuilds the unsigned macOS app, launches its real
packaged executable against a disposable Application Support root, and uses
production storage, capture, local-answer, kept-memory, and full-vault recovery
types. The journey proves:

1. the primary shell is Home, Library, and Settings;
2. primary copy excludes provider and storage jargon;
3. repeated clipboard content is idempotent and keeps both capture receipts;
4. saved content survives a storage restart;
5. model-free Ask returns one cited matching passage and makes no model request;
6. Keep survives restart and its revision-bound Undo is exact;
7. backup creation, validation, and fresh-root restore preserve the item and
   kept answer; and
8. a restored watched folder is paused and the running proof process owns no
   network socket.

The proof runner is accepted only when its command-line root exactly matches
`CAM_ASSISTANT_APPLICATION_SUPPORT_ROOT`. Its temporary root is removed after
the test.

## Fresh verification receipts

| Command | Result |
|---|---|
| `swift test --disable-sandbox --scratch-path .build --filter meaningPreviewIsConditionalAndReducedMotionSafe` | PASS, 1 test |
| `swift test --disable-sandbox --scratch-path .build --filter BarebonesSettingsTests` | PASS, 3 tests |
| focused app, Ask, Keep, backup, privacy, and audit suite | PASS, 129 tests |
| `SWT_EXPERIMENTAL_MAXIMUM_PARALLELIZATION_WIDTH=1 swift test --disable-sandbox --scratch-path .build` | PASS, 476 tests |
| `/bin/zsh scripts/verify.sh barebones-packaged` | `CAM_ASSISTANT_BAREBONES_PACKAGED status=pass` |
| `CAM_ASSISTANT_SKIP_FRESH_CLONE=1 /bin/zsh scripts/verify.sh all` | PASS: 476 tests, release build, two-build package reproducibility, package identity, and 73-file zero-finding credential-signature scan |

The aggregate was intentionally run from the pre-commit working tree and
reported `dirty=true`; the exact implementation was then committed as
`d22f7e5b13509e977cbab6ab742ce49643f82e79`.

`/bin/zsh scripts/verify.sh fresh-clone` then verified documentation revision
`95cd2a0ec36ce4990f99dde379f8d3fb1b306273` from a temporary clone: all 476
tests, release build, reproducibility, privacy, package, and offline smoke
passed. The packaged identity reported that exact commit with `dirty=false`.
The outer checkout remained intentionally dirty only because unrelated,
untracked user files were preserved.

## Honest boundary

This receipt satisfies the repository-owned machine evidence for barebones
Gates 1-6. It does not prove that a general user understands the interface or
can complete the journey unaided. Gate 7 remains pending until a human follows
`docs/pilots/barebones-general-user-protocol.md` and returns an authentic
observation record. The app is unsigned and not notarized; this is internal
pilot evidence, not public-release approval.
