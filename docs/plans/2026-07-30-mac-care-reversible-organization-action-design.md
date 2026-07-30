# Mac Care Reversible Organization Action Design

## Decision

The first executable Mac Care action is `moveOneSelectedFile`. It moves one
user-selected regular file to one user-selected existing destination directory
inside one caller-approved organization root. The user may supply a new file
name; CAM never infers a target, destination, or name from age, size, usage,
or model output.

This is the smallest useful action that meets the product requirement for a
closed, exact-approved, reversible Mac Care capability without introducing
deletion, recursive cleanup, startup-item control, application removal,
privilege, account, credential, or security-setting authority.

## Alternatives considered

1. Disable a LaunchAgent. Rejected for the first action: it has greater
   operational impact, platform-specific state, and recovery ambiguity.
2. Delete or quarantine duplicates. Rejected: duplicate identity/evidence is
   not yet complete and deletion is not a safe first executor.
3. Move one explicit file inside an approved root. Chosen: deterministic,
   bounded, previewable, reversible, and fully fixture-testable.

## Contract

The planner requires an existing regular non-symlink source, an existing
directory destination, and a destination path formed from the supplied safe
name. Both source and destination must be descendants of one canonical
organization root. The destination must not already exist. The plan captures
only status-safe metadata: action ID, root-relative source/destination IDs,
source byte count, source SHA-256, state revision, and a precondition digest.
No file bytes, absolute user paths, model text, or directory inventory are
stored in receipts.

An exact `ActionCard` binds the action, root-relative target identifiers,
precondition digest, expiry, and undo contract. One consumed approval is
required before execution. A stale source, changed source bytes, existing
destination, changed plan revision, expired/reused approval, cancellation, or
failed move cannot produce success.

## Execution and recovery

Execution uses one non-recursive filesystem move only after all preconditions
pass. A terminal receipt records IDs/digests/counts/timestamps/status and no
raw paths or file bytes. The executor verifies that the source is absent, the
destination is a regular non-symlink file, and its digest matches the planned
source before marking success.

Undo requires the successful receipt, an exact current-state check of the
destination, and a vacant original path. It moves the file back and verifies
the restored digest. A changed destination or reoccupied original path fails
closed and leaves the file where it is. An action never touches vault content,
CAM data, donor repositories, or files outside the supplied root.

## Native UX

Mac Care presents a clear preview: source label, destination label, byte count,
exact approval requirement, and undo availability. No automatic recommendation
or apply button appears until a user has explicitly selected a file and
destination. Result and undo states are accessible and remain distinct from
read-only assessment findings.

## Proof

Tests use only temporary fixture roots. They prove valid preview/approval/move,
stale source refusal, destination conflict refusal, cancellation, failed
approval reuse, status-only receipt persistence/restart, exact undo, and stale
undo refusal. A packaged isolated-root journey is required before this action
is treated as end-user ready. No real user file is moved during development or
verification.
