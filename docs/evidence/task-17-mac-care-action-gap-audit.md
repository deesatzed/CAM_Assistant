# Safe Mac Care Action Gap Audit

**Date:** 2026-07-28  
**Status:** Read-only implementation inventory. No Mac maintenance action is
implemented or authorized.

## Scope

This audit compares the current Mac Care observation, assessment, planner,
native view, module manifest, and focused tests with CAM-017 and the
`GOAL_FINISH_WIKI.md` Mac Care gate. It inspects repository-owned code and
synthetic temporary fixtures only at commit
`5aa465ce62bf82cf791e2266901aa8c25046f5cb`.

The audit did not press the packaged app's `Assess Standard Locations` button
and did not inspect the live Mac's application or startup-item inventory.

## What is currently real

- `MacWiseAdapter.assess` validates storage totals and deterministically hashes
  free/total bytes plus sorted caller-supplied application and startup paths.
- `inspectReadOnly` reads filesystem capacity and immediate directory entries
  only from caller-selected locations.
- A temporary-fixture test proves read-only application/startup counts.
- The standard native operation is non-blocking and reads `/Applications`,
  `/Library/LaunchAgents`, the user's `Library/LaunchAgents`, and volume
  capacity when explicitly triggered.
- Presentation reports byte counts, free-space percentage, application count,
  startup-item count, and bounded review prompts.
- Low free space is reported as a review condition below 10 percent.
- The application inventory explicitly says usage and removal recommendations
  are unavailable.
- A proposal can be bound to the exact assessment digest; a stale digest fails.
- Apply and undo always return a typed unavailable error.
- The native view states that Mac Care is read-only and exposes no mutation
  control.
- Current focused verification:
  `swift test --disable-sandbox --scratch-path .swift-build --filter
  MacCareTests` passed all five tests.

## Missing assessment behavior

| Required behavior | Current state | Missing proof or implementation |
|---|---|---|
| Storage assessment | Free/total bytes and one low-space threshold | Bounded directory/category attribution, uncertainty, permission failures, and evidence explaining major space consumers |
| Application assessment | Immediate `/Applications` entry count | Per-application identity, version, size, origin, signing facts, duplicates, user Applications, uncertainty, and bounded evidence display |
| Startup assessment | Immediate LaunchAgents entry count | Typed launch-agent/login-item identity, enabled/loaded status, owner, target, source, uncertainty, and safe explanation |
| Duplicate assessment | Not implemented | Content-identity hashing, hard-link awareness, package/resource exclusions, size bounds, cancellation, and false-positive handling |
| Organization assessment | Not implemented | Caller-selected scope, non-mutating classification, uncertainty, proposed destination, conflict handling, and evidence |
| Necessity judgment | Explicitly unavailable | Keep unavailable; size/count/age/usage absence alone must never decide an app is unnecessary |
| Native evidence review | Counts and generic findings only | Inspectable item rows, how-obtained details, uncertainty, excluded scope, refresh/cancel/error states, and accessible large-data journey |

## Missing action behavior

| Required behavior | Current state | Missing proof or implementation |
|---|---|---|
| Closed safe action set | Actions are `reviewStorage` and `reviewStartupItems`, not mutations | Enumerate a minimal non-privileged reversible mutation; keep deletion, privilege, account, credential, and security changes unavailable |
| Preview | No action preview exists | Exact source/target/change summary, affected bytes, conflicts, exclusions, and undo feasibility |
| Exact approval | Plan stores only `.exact` and assessment digest | Bind an `ActionCard` and one-use approval to action, exact paths, scrubbed payload digest, current precondition, expiry, and recovery |
| Precondition | Aggregate assessment digest only | Action-specific file identity, metadata/content digest, existence, ownership/permission, and destination state |
| Execution | `apply` always unavailable | Typed executor limited to the enumerated operation and caller-approved roots |
| Cancellation | No execution exists | Cooperative safe boundaries and a visible persisted result |
| Postcondition | No execution exists | Verify exact expected state and refuse success on mismatch |
| Audit receipt | No action receipt exists | Status-only action/target digest, before/after identities, timestamps, approval ID, verifier, and failure code without sensitive content |
| Undo/recovery | `undo` always unavailable | Durable undo receipt, stale-state refusal, conflict behavior, idempotency, and verified restoration |
| Restart | Plans are in memory only | Canonical app-owned job/receipt store and interrupted-state recovery |
| Native workflow | UI offers assessment only | Preview, approve, apply, cancel, result, undo, failure, and recovery controls |
| Packaged proof | Read-only accessibility slice exists | Disposable-root/synthetic-filesystem action journey proving no system or unrelated user state changes |

## Correctness and safety notes

- `MacCareObservation` sorts paths but does not de-duplicate them, so caller
  duplicates can inflate counts. A richer assessment must define identity and
  duplicate handling explicitly.
- The current digest binds aggregate paths and capacity, not the preconditions
  of any future mutation.
- The Mac Care module manifest declares write, execute, and delete permissions,
  but the packaged app does not initialize the module registry and no executor
  consumes those declarations. They are not current authority.
- Missing directories are treated as empty, while other directory errors
  throw. Native presentation should distinguish absent scope from permission
  or read failure before making assessment claims.

## Required action boundary

1. Read-only assessment remains useful without enabling any mutation.
2. Assessment, proposal, approval, execution, verification, and undo are
   separate typed transitions.
3. The first action must be non-privileged, narrowly scoped, reversible, and
   testable entirely inside a disposable caller-approved root.
4. No broad cleanup, recursive delete, application uninstall, startup-item
   removal, privileged command, security-setting change, credential operation,
   or account change enters the initial action set.
5. Approval binds exact paths and hashes. A changed source or destination
   invalidates approval.
6. Tool/model text cannot choose targets or authorize execution.
7. Cancellation and failure leave either the verified before-state or a
   typed recoverable state; partial success cannot be reported as complete.
8. Undo requires its own current-state check and postcondition proof.
9. Layer 1 vault content, CAM data, donor repositories, and unrelated user
   files stay outside the action scope.

## Candidate first bounded proof

A safe first mutation candidate is an explicit move/rename of one synthetic
file between two locations inside a disposable caller-approved organization
root. It can provide an exact preview, content/metadata precondition, atomic
move where supported, destination-conflict refusal, postcondition, durable undo
receipt, stale-undo refusal, and verified move-back. This is a candidate
direction, not an approved implementation design or authorization to move any
real user file.

## Current proof boundary

The five focused tests prove deterministic read-only assessment, selected-root
counting, bounded review messaging, stale aggregate-plan refusal, and honest
apply/undo unavailability. They do not prove duplicate/organization analysis,
item-level evidence, an action card, execution, cancellation, postconditions,
receipts, undo, restart, or a packaged action journey.

No live inventory was collected and no file, application, startup item,
preference, process, account, credential, or system setting was changed during
this audit.

