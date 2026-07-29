# Full-Vault Backup and Restore Implementation Plan

> **For Codex:** REQUIRED SUB-SKILL: Use test-driven-development and execute
> this plan task-by-task in the current clean feature branch.

**Goal:** Build and prove an integrity-checked local CAM Assistant vault
package that restores into a fresh application-support root without restoring
ambient authority.

**Architecture:** `FullVaultBackupService` owns a versioned allowlisted
manifest, online SQLite capture, payload hashing, package validation, and
fresh-root staging restore. `LocalVaultPaths` owns canonical state locations.
The CLI and native Settings UI call the same Core service; neither implements
file-copy logic.

**Tech Stack:** Swift 6, Foundation, CryptoKit, SQLite3, Swift Testing, SwiftUI,
AppKit save/open panels.

---

### Task 1: Canonical vault inventory and manifest contract

**Files:**
- Create: `Sources/CAMAssistantCore/Storage/FullVaultBackup.swift`
- Modify: `Sources/CAMAssistantCore/Storage/LocalVaultPaths.swift`
- Create: `Tests/CAMAssistantCoreTests/FullVaultBackupTests.swift`

1. Write a failing test that asks `LocalVaultPaths` for every recognized
   app-owned state path and constructs a sorted version-one manifest with
   relative paths, roles, sizes, digests, required flags, product identity,
   and creation date.
2. Run `/bin/zsh scripts/verify.sh backup`; expect compilation failure because
   the manifest and inventory APIs do not exist.
3. Implement only the typed inventory, manifest, entry, receipt, and error
   contracts plus canonical paths.
4. Re-run the focused suite; expect pass.

### Task 2: Integrity-checked package creation

**Files:**
- Modify: `Sources/CAMAssistantCore/Storage/FullVaultBackup.swift`
- Modify: `Tests/CAMAssistantCoreTests/FullVaultBackupTests.swift`

1. Write failing tests that create a disposable populated vault and require a
   `.camvault` package containing an online SQLite copy, exact immutable
   objects, all recognized existing state files, and no retrieval/lease/temp
   files.
2. Add failure tests for an existing destination, missing database, symlink,
   invalid content-object identity, and changed bytes.
3. Run `/bin/zsh scripts/verify.sh backup`; verify each red is caused by
   missing package behavior.
4. Implement sibling staging, database-first capture, allowlisted copying,
   SHA-256 inventory, manifest writing, self-validation, atomic promotion, and
   status-only receipt.
5. Re-run until every creation test passes.

### Task 3: Untrusted package validation and fresh-root restore

**Files:**
- Modify: `Sources/CAMAssistantCore/Storage/FullVaultBackup.swift`
- Modify: `Tests/CAMAssistantCoreTests/FullVaultBackupTests.swift`

1. Write failing tests for hash/size tampering, absolute/traversal/duplicate
   paths, extra files, symlinks, invalid SQLite, unsupported schema, and
   non-empty destination.
2. Write a failing round-trip test that reopens SQLite, immutable content,
   tasks, research, knowledge, repository receipts, preferences, packets,
   approvals, and module state after restore.
3. Require restored watched sources to be paused and retrieval/lease/cache
   state to be absent.
4. Run `/bin/zsh scripts/verify.sh backup`; observe the intended failures.
5. Implement full preflight validation, staging restore, authority-safe state
   rewriting, post-restore reopening, and atomic destination creation.
6. Re-run focused tests and the existing storage, ingest, research, knowledge,
   repository, privacy, module, and task suites.

### Task 4: CLI backup, validation, and restore

**Files:**
- Create: `Sources/CAMAssistantCLI/VaultCommands.swift`
- Modify: `Sources/CAMAssistantCLI/main.swift`
- Modify: `Tests/CAMAssistantCoreTests/FullVaultBackupTests.swift`
- Modify: `scripts/verify.sh`

1. Write failing parser and executor tests for:
   - `vault backup SOURCE_ROOT PACKAGE`
   - `vault validate PACKAGE`
   - `vault restore PACKAGE DESTINATION_ROOT`
2. Require usage errors to exit 64, validation/operation failures to exit
   nonzero, and output to contain only status, paths, counts, bytes, and
   digests.
3. Add the `backup` focused verifier suite.
4. Implement the parser and Core-backed executor.
5. Run the focused CLI proof against disposable roots.

### Task 5: Native Backup and Recovery workspace

**Files:**
- Modify: `Sources/CAMAssistantApp/AppModel.swift`
- Modify: `Sources/CAMAssistantApp/Views/AssistantWindow.swift`
- Create: `Sources/CAMAssistantApp/Views/BackupRecoveryView.swift`
- Modify: `Tests/CAMAssistantAppTests/AccessibilityViewContractTests.swift`
- Create: `Tests/CAMAssistantAppTests/BackupRecoveryAppModelTests.swift`

1. Write failing AppModel tests for non-blocking backup, package validation,
   fresh-root restore, status/error clearing, and concurrent-action refusal.
2. Write a failing source/accessibility contract for a named Backup and
   Recovery workspace with separate Create, Validate, and Restore actions,
   status values, safety explanations, and no overwrite control.
3. Implement injected operation closures in AppModel and AppKit panel adapters
   in the view.
4. Keep all filesystem work off the main actor and publish only status-only
   receipts.
5. Run focused app and accessibility tests.

### Task 6: Packaged recovery journey and repository truth

**Files:**
- Create: `docs/evidence/task-18-full-vault-backup-restore.md`
- Modify: `docs/evidence/goal-finish-wiki-gate-map.json`
- Modify: `docs/VERIFICATION_REPORT.md`
- Modify: `DECISIONS.md`
- Modify: `PROGRESS.md`
- Modify: `TASK_QUEUE.md`

1. Build the unsigned package with `/bin/zsh scripts/verify.sh package`.
2. Launch against a disposable populated application-support root, create a
   backup, quit, restore to a second fresh root, and relaunch there.
3. Prove restored Library, tasks, research, knowledge, repositories,
   preferences, and audit state; prove watched sources are paused and no
   authority or stale lease was restored.
4. Save hashes, counts, commands, accessibility observations, and limitations.
5. Move `wiki.full-vault-backup` to `passed` only if the complete goal bullet
   is directly proven.
6. Run `/bin/zsh scripts/verify.sh goal-map`,
   `/bin/zsh scripts/verify.sh release-privacy`,
   `CAM_ASSISTANT_SKIP_FRESH_CLONE=1 /bin/zsh scripts/verify.sh all`, and
   `git diff --check`.
7. Commit, push, and run `/bin/zsh scripts/verify.sh fresh-clone` against the
   pushed commit.

