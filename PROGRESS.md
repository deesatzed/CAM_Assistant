# CAM Assistant Progress

## Status Overview

Foundation milestones are verified, but the full GOAL_FINISH_WIKI product remains
in progress. See `docs/VERIFICATION_REPORT.md` for the requirement-by-
requirement completion audit and hard remaining gates.

The full objective and all proof gates remain active. Percent complete changes
only after a milestone is verified; early scaffolding is not product readiness.

## Current Assumptions

- Canonical product path: `/Volumes/WS4TB/waswiki/CAM_Assistant`.
- Initial branch: `feat/cam-assistant-foundation`.
- Swift 6.3 is installed on Apple Silicon.
- This repo did not exist before initialization, so no Git worktree could be
  created from an existing branch.
- Donor repos are read-only.

## Donor Baseline

Captured before app edits on 2026-07-24:

| Repo | Head | Dirty entries |
|---|---:|---:|
| `repo412sn/llm_wiki` | `21a9e7d` | 1 |
| `repo622sn/CAM_Codx` | `60f747d` | 0 |
| `repo622sn/CAM_CAM` | `db5495a` | 1 |
| `Codx_macwise` | `7c4128d` | 0 |
| `RedaktSafe` | `858e6ce` | 3 |
| `imbora` | `a25b3e8` | 4 |
| `mimi_prompt` | `1f3203f` | 1 |

These states are evidence, not cleanup authorization.

## Task Tracker

| Task | Status | Owner | Notes |
|---|---|---|---|
| 1. Repo and truth surface | Complete | Codex | Debug tests and release build pass |
| 2. Native shell | Complete | Codex | Offline smoke and health tests pass |
| 3. Storage and audit | Complete | Codex | Restart, backup, and redaction tests pass |
| 4. Module registry | Complete | Codex | Seven manifests and live state tests pass |
| 5. Capture and ingestion | Complete | Codex | Mixed modalities and FSEvents pass |
| 6. Retrieval | Complete | Codex | Frozen v2 synthetic corpus, persistent derived generations, and local benchmark receipt verified; see limitations below |
| 7. Model routing | Complete | Codex | Local parser/profile/catalog/CLI/settings proof is verified; outbound remains gated |
| 8. Privacy and action cards | Complete | Codex | Frozen deterministic classification, zero-byte blocks, exact approvals, and status-only audit proof verified |
| 9. CAM adapter | Complete | Codex | Fixture conformance, non-executing proposals, unavailable-state UI, and release verification |
| 10. Research and knowledge | Complete | Codex | Local checkpoint/resume, citation-bound facts, separate inferences, contradiction candidates, and native status |
| 11. Mac Care and repositories | Complete | Codex | Read-only repository intake/idea proposals and digest-bound Mac assessment plans with unavailable executors |
| 12. UX, packaging, and aggregate proof | In progress | Codex | Local package/smoke and accessibility foundations exist; full completion audit remains red |

## Decision Links

- See `DECISIONS.md`.
- Controlling goal: `GOAL_FINISH_WIKI.md`.
- Approved design: `docs/plans/2026-07-26-finish-wiki-design.md`.

## Current Milestone

Complete the daily-use wiki and grounded local-model chat gate (CAM-013).
Cloud-context loading, live catalog lookup, provider testing, web, embedding
promotion, CAM mining, and mutating workflows remain disabled until their
individual proof gates are met.

## Next Actions

1. Preserve generated-answer v1 as the fixed baseline and run a versioned v2
   experiment comparing a bounded set of already-installed local models or a
   constrained evidence-composition strategy; do not tune v1 labels after the
   observed failures.
2. Run the packaged selected-model chat journey with a versioned local profile,
   recording exact runtime/model identity and retaining visible no-fallback
   behavior.
3. Complete fresh-user/restart GUI proof while preserving immutable source
   bytes.

## Verification Receipts

### Task 1 — 2026-07-24

- Expected red: focused test failed because `BuildIdentity` was absent.
- Expected package red: `swift build --product CAMAssistant` failed because
  the product was absent.
- Green: full Swift test suite passed (1 test).
- Green: production build completed for the app and CLI products.
- SwiftPM required `--disable-sandbox` plus a repo-local module cache because
  the managed execution sandbox blocks SwiftPM's nested sandbox and cache.

### Task 2 — 2026-07-24

- Expected red: focused health test failed because `AppHealth` was absent.
- Green: full Swift test suite passed (4 tests).
- Green: production build completed for app and CLI products.
- Green: the native executable's offline smoke mode exited `0` without keys or
  network and reported capture/local-search available with cloud auto-routing
  disabled.
- Saved receipt: `docs/evidence/task-02-offline-smoke.md`.

### Task 3 — 2026-07-24

- Expected red: focused storage compilation failed because all storage and
  audit contract types were absent.
- Green: full Swift test suite passed (10 tests).
- Green: stable SHA-256 addressing, idempotence, restart, atomic-write cleanup,
  exact-byte content backup/restore, SQLite migration restart, audit database
  backup, and typed audit persistence are covered.
- Green: the saved JSON fixture decodes to exactly the persisted event.
- Green: direct credential-pattern scan of saved evidence returned clean.
- Saved receipt: `docs/evidence/task-03-storage-audit.md`.

### Task 4 — 2026-07-24

- Expected red: focused registry compilation failed because manifest,
  permission, health, and registry contract types were absent.
- Green: full Swift test suite passed (16 tests).
- Green: production app and CLI build passed.
- Green: seven required manifests decode and validate against the versioned
  contract.
- Green: duplicate IDs, invalid versions, and unknown permissions fail closed.
- Green: discovered and enabled modules receive no permissions automatically.
- Green: enable/disable persists atomically, reload discovers new manifests,
  and health failure removes only the affected module's capabilities.
- Saved receipt: `docs/evidence/task-04-module-registry.md`.

### Task 5 — 2026-07-24

- Expected red: focused ingestion compilation failed because capture envelopes,
  queue, extractors, watcher, receipts, and provenance types were absent.
- Expected FSEvents red: the automatic watcher test failed because start/stop
  behavior was absent.
- Green: full Swift test suite passed (22 tests).
- Green: production app and CLI build passed.
- Green: clipboard and folder sources ingest text, Markdown, PDF, image,
  audio/transcript, code, and configuration modalities.
- Green: unchanged bytes produce one source and one job while every capture
  retains provenance.
- Green: malformed media receives a bounded retry and structured warnings
  without blocking the next job.
- Green: cancellation is resumable and pending work survives restart.
- Green: a native FSEvents stream emitted a capture envelope without manual
  rescanning.
- Limitation: user-configurable capture hotkeys and watched-folder onboarding
  remain scheduled for Task 12; this milestone proves the underlying engine.
- Saved receipt: `docs/evidence/task-05-ingestion.md`.

### Task 6 — 2026-07-25

- Expected reds: retrieval fixtures initially had no chunked/citation contract;
  persistent derived generations, non-finite lane rejection, benchmark policy,
  and context serialization accounting were absent.
- Green: `/bin/zsh scripts/verify.sh retrieval` passed 18 focused retrieval
  tests covering v2 validation, frozen hash, expected quote availability,
  deterministic full-text/hybrid fusion, index-generation restart/failed
  rebuild behavior, context budget accounting, and benchmark receipt fields.
- Green: `/bin/zsh scripts/verify.sh retrieval-report` saved
  `docs/evidence/task-06-retrieval-v2-report.json` for the frozen v2 corpus:
  Recall@10 `1.0`, MRR `1.0`, exact cited-claim quote availability `1.0`, and
  warm local p95 `0.100042 ms` across 50 measured samples on this machine.
- Green: `/bin/zsh scripts/verify.sh all` passed 41 tests and a local release
  build. It includes capture → completed ingestion → derived index → cited
  search without changing immutable source bytes.
- Green: `git diff --check` passed before this receipt update.
- Saved methodology and limitations:
  `docs/evidence/task-06-retrieval-methodology.md`.
- Limitation: the frozen corpus is synthetic, small (30 passages/10 queries),
  and exact-quote availability is not semantic claim entailment, real-vault
  quality, model-answer faithfulness, or a SOTA claim. The historic v1 report
  remains recovered scaffolding and is not CAM-006 proof.

### Task 7 — 2026-07-26

- Expected reds: routing/profile/catalog contracts, profile receipts, CLI command
  parser/executor, shared state location, settings snapshot, and typed future
  command gates were absent before their respective small implementations.
- Green: `/bin/zsh scripts/verify.sh routing` passed 6 tests for every routing
  marker, local default, text preservation, unavailable explicit roles, and
  duplicate/incompatible markers.
- Green: `/bin/zsh scripts/verify.sh models` passed 13 profile/catalog/command
  tests covering local-default profile enforcement, atomic revision/rollback,
  receipts across restart, secret-bearing endpoint rejection, local catalog
  facts, CLI command parsing/execution, native settings snapshot, and typed
  policy/proof-gate refusals.
- Green: `/bin/zsh scripts/verify.sh all` passed 60 tests and release-built the
  native app and CLI.
- Saved receipt: `docs/evidence/task-07-model-routing.md`.
- Limitation: no real model endpoint, cloud provider, live catalog, embedding
  evaluation, web request, or CAM action was contacted. These are deliberately
  blocked pending CAM-008 and later proofs.

### Task 8 — 2026-07-26

- Expected reds: privacy classifier/fixture, outbound policy, exact
  action-card/approval contracts, privacy audit fields, and router-to-policy
  handoff were absent before their respective small implementations.
- Green: `/bin/zsh scripts/verify.sh privacy` passed 8 privacy tests and 3
  audit tests. Ten frozen fixtures cover public/generic/contextual/proprietary
  and secret/credential/PII/PHI/path-traversal/prompt-injection cases; every
  restricted fixture produces zero outbound bytes and does not appear in SQLite
  audit bytes or exported JSON.
- Green: `/bin/zsh scripts/verify.sh routing` passed 7 tests including explicit
  web intent entering the policy before any possible transport.
- Saved receipt: `docs/evidence/task-08-privacy-action-cards.md`.
- Limitation: the classifier is a deterministic fail-closed baseline and no
  transport/action executor exists. Exact approval records local consent state
  only; it cannot perform an external or mutating action.

### Task 9 — 2026-07-26

- Expected reds: CAM contract/schema, adapter health, identity, proposal, and
  native-status projection types were absent before their respective small
  implementations.
- Green: `/bin/zsh scripts/verify.sh cam` passed 4 focused fixture contract and
  adapter tests. Owner/version/tool mismatches fail closed; a missing runtime is
  typed as unavailable rather than triggering a fallback or escalation.
- Green: `/bin/zsh scripts/verify.sh all` passed 74 tests and release-built the
  native app and CLI. The app includes a read-only CAM status section with no
  runtime start, mining, or dispatch control.
- Green: `git diff --check` passed before this receipt/tracker update.
- Saved receipt: `docs/evidence/task-09-cam-adapter.md`.
- Limitation: conformance is against a pinned synthetic snapshot only. No CAM
  runtime, MCP server, donor configuration, database, model account, repo mine,
  or action execution was contacted.

### Task 10 — 2026-07-26

- Expected reds: research lifecycle/checkpoint, packet/finding, citation
  validation, knowledge claim/contradiction, and read-only presentation types
  were absent before their respective small implementations.
- Green: `/bin/zsh scripts/verify.sh research` passed 5 tests covering unique
  queries, ephemeral default retention, deterministic checkpoint resume,
  stale-version refusal, citation-verified facts, separate inference support,
  forged-citation refusal, and disabled execution presentation.
- Green: `/bin/zsh scripts/verify.sh knowledge` passed 2 tests for
  citation-bound claims/assumptions and non-merging manual contradiction
  candidates.
- Green: `/bin/zsh scripts/verify.sh all` passed 81 tests and release-built
  the native app and CLI. The app adds a read-only Research section.
- Green: `git diff --check` passed before this receipt/tracker update.
- Saved receipt: `docs/evidence/task-10-research-knowledge.md`.
- Limitation: no web, cloud, CAM runtime, external source acquisition,
  database persistence, cost receipt, background schedule, or automatic
  retention exists in this milestone.

### Task 11 — 2026-07-26

- Expected reds: repository snapshot/intake, evidence/idea-card proposal, Mac
  Care assessment/planner, read-only probe, and unavailable executor types
  were absent before their respective small implementations.
- Green: `/bin/zsh scripts/verify.sh repositories` passed 2 tests. A temporary
  Git fixture proves intake retains source bytes and status while recording
  canonical Git/file/license evidence; idea promotion is evidence-bound and
  proposal-only.
- Green: `/bin/zsh scripts/verify.sh mac-care` passed 3 tests covering
  caller-selected read-only directory/volume assessment, digest-bound exact
  proposals, stale-state refusal, and unavailable apply/undo paths.
- Green: `/bin/zsh scripts/verify.sh all` passed 86 tests and release-built
  the native app and CLI. The app adds read-only Repository and Mac Care views.
- Green: `git diff --check` passed before this receipt/tracker update.
- Saved receipt: `docs/evidence/task-11-repositories-mac-care.md`.
- Limitation: no real user/donor repository, CAM runtime/database/config,
  mining command, or Mac mutation was contacted or changed.

### Task 12 — partial, 2026-07-26

- Green: `/bin/zsh scripts/verify.sh all` passed 100 tests and release-built
  the native app and CLI.
- Green: `/bin/zsh scripts/verify.sh package` produced the unsigned local
  `artifacts/CAM Assistant.app` bundle and validated its `Info.plist`.
- Green: a native accessibility inspection of that bundle confirmed the
  focused local-question field, `Ask locally`, `Capture Clipboard Locally`,
  the offline explanation, and `Global hotkeys active` after Carbon shortcut
  registration returned successfully.
- Limitation: this proves live registration status and the packaged UI, not an
  end-to-end operating-system key-event dispatch. Watched-source onboarding,
  reduced-motion validation, full user-journey automation, signing, and
  notarization remain incomplete.

### Repository-intake persistence extension — 2026-07-26

- Green: `/bin/zsh scripts/verify.sh repositories` passed three tests,
  including a temporary Git fixture whose snapshot is recorded once per
  canonical path and commit and is returned after the local SQLite store is
  reopened.
- Boundary: this records only derived local intake receipts. It does not write
  to the inspected repository, clone a remote, index repository content for
  search, invoke CAM, or mine a CAM corpus.
- Green: selected temporary repository indexing captures permitted code,
  Markdown, and configuration files into the local vault, produces derived
  documents, preserves canonical path/commit provenance, and leaves fixture
  bytes plus Git status unchanged.
- Green: repository comparison emits sorted, exact added, removed, and
  line-count-changed file evidence between snapshots without rereading a
  repository or making semantic claims.

### CAM mining lifecycle contract — 2026-07-26

- Green: `/bin/zsh scripts/verify.sh cam` passed seven tests for bounded
  digest-only plan validation, exact approval consumption, cancellation, and
  unavailable execution receipts.
- Green: `/bin/zsh scripts/verify.sh all` passed 100 tests and release-built
  the native app and CLI; `git diff --check` passed.
- Boundary: the unavailable executor performs no runtime, process, config,
  database, repository, network, or corpus I/O. A live mining integration
  remains a separately exact-approved gate with pinned runtime/config/database
  inspection and dedicated integration proof.

### Coordination event/reducer foundation — 2026-07-26

- Green: `/bin/zsh scripts/verify.sh coordination` passed five tests covering
  current-version verification success, stale-version refusal, budget terminal
  state, atomic local event persistence/restart replay, and stale-writer
  sequence refusal.
- Green: `/bin/zsh scripts/verify.sh all` passed 105 tests and release-built
  the native app and CLI; `git diff --check` passed.
- Green: orchestration artifacts are content-addressed, survive restart, and
  verify byte count plus SHA-256 before reads.
- Green: durable JSON handoff packets round-trip and render a human-readable
  Markdown resume summary with repository identity, run state, blockers, and
  the immediate next safe action.
- Limitation: this is an offline local event/reducer foundation. It does not
  yet provide cross-process leases, snapshots/migrations, tool execution,
  retries, graph dispatch, prompt evaluation, or native orchestration controls.

### Repository observation evidence extension — 2026-07-26

- Expected red: `/bin/zsh scripts/verify.sh repositories` failed because the
  commit-cited observation extractor did not exist.
- Green: the focused repository suite passed six tests, including an explicit
  `TODO` marker observed from the recorded Git commit after the fixture working
  tree was deliberately changed.
- Green: `/bin/zsh scripts/verify.sh all` passed 108 tests and release-built
  the native app and CLI.
- Boundary: observations currently recognize literal `TODO` and `FIXME`
  markers only. They cite commit/file/line and request review; they do not
  infer behavior, architecture, risk, or a reusable pattern from repository
  text.

### Bounded local coordination loop — 2026-07-26

- Expected red: `/bin/zsh scripts/verify.sh coordination` failed because the
  bounded-loop type and typed local steps did not exist.
- Green: the focused coordination suite passed ten tests. The loop writes
  content-addressed local evidence before appending its observe, plan, execute,
  verify, or terminal event; verified success still requires the reducer's
  verification evidence gate.
- Green: reopening the event log rebuilds the identical terminal state and
  evidence references; a terminal run refuses another step.
- Green: `/bin/zsh scripts/verify.sh all` passed 111 tests and release-built
  the native app and CLI.
- Green: adversarial review found that invalid steps could orphan evidence;
  reducer preflight now rejects those steps before storage, and a focused test
  proves the artifact store remains empty.
- Boundary: this does not execute commands, tools, models, CAM, network calls,
  or specialists. Cross-process leases, snapshots/migrations, retry policy,
  graph dispatch, and native controls remain incomplete.

### Cross-process orchestration ownership — 2026-07-26

- Expected reds: the focused coordination suite first failed because the lease
  store and then the lease-bound loop initializer did not exist.
- Green: the focused coordination suite passed 13 tests. A lease rejects a
  competing local owner, requires explicit release before a successor loop can
  recover the run, and is checked before the loop advances.
- Green: a separately spawned native `cam-assistant` lock probe receives the
  expected held result while the parent owns the same run. This proves the
  macOS OS-file-lock boundary rather than only an in-process mutex.
- Green: `/bin/zsh scripts/verify.sh all` passed 114 tests and release-built
  the native app and CLI.
- Boundary: ownership is local to this Mac and its filesystem. It is not a
  remote or multi-machine lease, and snapshots/migrations, execution/retry,
  graph dispatch, and native coordinator controls remain incomplete.

### Validated orchestration snapshots — 2026-07-26

- Expected reds: snapshot derivation/validation and then the durable snapshot
  store were absent from the focused coordination suite.
- Green: the suite passed 15 tests. Snapshots contain a reducer-derived state,
  canonical event count, and SHA-256 event digest; restart validation replays
  the full log and rejects stale or mismatched snapshots.
- Green: the versioned snapshot store uses atomic writes and preserves the full
  event log; an event appended after save invalidates the cached snapshot.
- Green: `/bin/zsh scripts/verify.sh all` passed 116 tests and release-built
  the native app and CLI.
- Boundary: no event compaction, remote sync, or schema migration beyond the
  initial persisted snapshot version exists yet.

### Orchestration persistence migration — 2026-07-26

- Expected red: a synthetic version-one event log/snapshot fixture remained
  version one after load.
- Green: version-one event logs and snapshots migrate atomically to version two
  while retaining the same events, digest, and reducer-derived state.
- Green: `/bin/zsh scripts/verify.sh all` passed 117 tests and release-built
  the native app and CLI.
- Boundary: this is a one-step local v1-to-v2 migration only. Event compaction,
  remote sync, and future schema migrations remain separate gates.

### Repository symbol observation extension — 2026-07-26

- Expected red: committed Swift declarations produced no repository observations.
- Green: the repository suite passed seven tests. `struct`, `class`, `enum`,
  `protocol`, and `func` declarations are extracted only from the pinned commit
  and retain exact file/line/symbol evidence.
- Green: `/bin/zsh scripts/verify.sh all` passed 118 tests and release-built
  the native app and CLI.
- Boundary: declaration evidence is not a claim about behavior, architecture,
  risk, reusability, or licensing; those require separate evidence contracts.

### Incremental repository refresh — 2026-07-26

- Expected red: no service could record a current snapshot and compare it with
  the prior local receipt in one read-only operation.
- Green: the repository suite passed eight tests. Refresh saves the current
  canonical-path/commit receipt idempotently and returns exact snapshot changes
  from the last local receipt.
- Green: `/bin/zsh scripts/verify.sh all` passed 119 tests and release-built
  the native app and CLI.
- Boundary: this is a local receipt refresh only; no repository UI workflow,
  vault reindex delta, CAM invocation, or remote clone is implemented.

### Incremental committed repository indexing — 2026-07-26

- Expected reds: the focused repository suite first failed because incremental
  committed-byte indexing and its failure receipt contract did not exist.
- Green: the suite passed ten tests. Snapshots now include SHA-256 content
  digests from the recorded commit; changed files are detected even when their
  line count is unchanged.
- Green: first indexing captures permitted committed sources; later indexing
  captures only added or changed permitted files, preserves immutable prior
  sources, and ignores uncommitted working-tree edits.
- Green: a malformed local source leaves no new snapshot receipt, so retry is
  possible rather than falsely treating a failed derived write as complete.
- Green: committed Git output is drained before process completion, preventing
  large permitted files from deadlocking the local reader; files over 1 MB are
  retained as snapshot evidence but excluded from vault indexing.
- Green: `/bin/zsh scripts/verify.sh all` passed 122 tests and release-built
  the native app and CLI.
- Boundary: source capture is still local-only and proposal-free. It does not
  delete historical vault material, create a repository UI workflow, invoke
  CAM, clone remotes, or infer semantics from a digest change.

### Selected-repository native inspection — 2026-07-26

- Expected red: the repository presentation contract was absent from the
  focused suite.
- Green: a user-entered local path can now be explicitly inspected from the
  native Repositories screen. It renders canonical path, branch, commit,
  dirty-state, license, and committed-file receipt count.
- Green: `/bin/zsh scripts/verify.sh all` passed 123 tests and release-built
  the native app and CLI.
- Boundary: inspection is read-only and does not automatically index, persist
  a path, invoke CAM, mine a corpus, clone a remote, or turn observations into
  conclusions. CAM mining remains visibly disabled.

### Explicit local repository indexing from the native app — 2026-07-26

- Expected red: the focused repository suite lacked an indexing-result
  presentation contract.
- Green: the native Repositories screen now offers an explicit `Index
  Committed Sources` action. It drives the existing receipt-bound incremental
  indexer into the local vault and reports either captured-source count or an
  unchanged commit.
- Boundary: the action is a local derived write only. It never writes the
  selected repository, sends source bytes externally, invokes CAM, or enables
  mining; path persistence and background indexing remain future work.

### Non-blocking native repository indexing — 2026-07-26

- Expected red: no self-contained local indexing operation owned the vault
  dependencies required to run away from a UI actor.
- Green: the Repositories screen now dispatches committed-source indexing in a
  detached task, disables repeat submission, and exposes an accessible local
  progress state while the core operation owns its queue and receipt store.
- Boundary: there is no cancellation control, persisted job, or background
  scheduler yet; this is an explicit foreground local operation only.
- Green: `/bin/zsh scripts/verify.sh all` passed 125 tests and release-built
  the native app and CLI.

### Native local task workspace — 2026-07-26

- Expected red: task records had no user-facing presentation contract.
- Green: the native Tasks section lists saved local task proposals with status,
  authority, citation count, and acceptance criteria, and refreshes from the
  local task store.
- Boundary: the workspace is read-only. It does not mark tasks complete,
  execute actions, alter authority, or turn a proposal into an approval.
- Update: users can now explicitly mark a local task complete; the status-only
  transition survives restart and leaves proposal authority, criteria, and
  citations unchanged. It never executes the underlying task.
- Green: `/bin/zsh scripts/verify.sh all` passed 127 tests and release-built
  the native app and CLI.

### Native local library summary — 2026-07-26

- Expected red: the core had no presentation contract for the current local
  derived-document set.
- Green: the Library screen replaces its stale placeholder with a read-only
  local source total, per-modality counts, refresh, and useful empty/error
  states.
- Boundary: this is summary metadata only. It does not expose source bytes,
  retain new data, execute indexing, or contact a provider.
- Green: `/bin/zsh scripts/verify.sh all` passed 128 tests and release-built
  the native app and CLI.

### Non-blocking local workspace refresh — 2026-07-26

- Green: Library and Tasks reads now run through a sendable detached local
  reader rather than synchronously on the SwiftUI main actor.
- Green: both views disable refresh and expose an in-progress local status;
  aggregate verification passed 129 tests with production app/CLI builds.

### Explicit native Mac Care assessment — 2026-07-26

- Green: the Mac Care view now offers a user-triggered, non-blocking assessment
  of standard application/startup locations and filesystem capacity.
- Boundary: it displays read-only facts only; all maintenance apply/undo paths
  remain unavailable and no system state is changed.
- Green: `/bin/zsh scripts/verify.sh all` passed 130 tests and release-built
  the native app and CLI.

### Persisted user hotkey configuration — 2026-07-26

- Green: Settings now exposes persisted Command-Option open/capture keys,
  validates configuration locally, and re-registers them for the current app
  session. The atomic configuration store survives restart.
- Boundary: the supported keys are Space or a single letter; no end-to-end
  operating-system event proof is claimed by configuration persistence alone.
- Green: `/bin/zsh scripts/verify.sh all` passed 131 tests and release-built
  the native app and CLI.

### Explicit local research planning — 2026-07-26

- Green: the native Research screen now accepts one local research question
  and creates an ephemeral local research run through the existing
  `ResearchCoordinator` contract.
- Green: the interface reports validation failures and continues to show that
  web, cloud, CAM, automatic retention, and scheduling are disabled.
- Boundary: creating a local plan does not acquire sources, send bytes,
  persist research output, create a task, or execute any external action.
- Green: `/bin/zsh scripts/verify.sh research` passed 5 focused tests and
  `/bin/zsh scripts/verify.sh all` passed 131 tests with production app/CLI
  builds.

### Explicit native watched-source onboarding — 2026-07-26

- Expected reds: watched-source configuration, lifecycle manager, isolated
  start-failure state, presentation, and persisted add/enable/remove service
  contracts were absent.
- Green: `swift test --scratch-path .swift-build --filter IngestTests` passed
  16 focused ingestion tests. New tests prove atomic multi-folder persistence,
  duplicate path/ID rejection, independent pause/remove lifecycle, local-only
  envelope forwarding, isolated watcher-start failure state, presentation
  labels, and persisted add/enable/remove controls.
- Green: Settings now offers an explicit native folder picker, then shows each
  selected canonical path with `Paused`, `Watching locally`, or failure state,
  plus explicit Enable/Pause/Remove controls. A newly selected folder remains
  paused until enabled.
- Green: `/bin/zsh scripts/verify.sh all` passed 139 tests and release-built
  the native app and CLI. `/bin/zsh scripts/verify.sh package` created the
  unsigned local app bundle; `/bin/zsh scripts/verify.sh smoke` remained
  offline with capture/local-search available and cloud auto-routing disabled.
- Boundary: watchers are foreground app-session owned. This does not prove
  background launch, a manually exercised packaged picker, unattended capture,
  cloud processing, or automatic retention of model output.

### Commit-cited repository evidence and proposal-only ideas — 2026-07-26

- Expected reds: observation presentation and a clean-snapshot idea-draft
  proposal helper were absent.
- Green: `swift test --scratch-path .swift-build --filter RepositoryTests`
  passed 16 focused tests. New tests prove exact commit/file/line/symbol
  presentation and that a draft promotes only clean selected-snapshot evidence
  into a typed research-packet proposal; dirty snapshots fail closed.
- Green: the Repositories screen now scans the explicitly inspected clean
  commit for the existing deterministic TODO/FIXME and Swift declaration
  observations, renders cited rows, and requires user-entered title,
  counterevidence, and smallest validation experiment before showing an
  ephemeral proposal-only receipt.
- Green: `/bin/zsh scripts/verify.sh repositories` and
  `/bin/zsh scripts/verify.sh all` passed, with aggregate verification at 141
  tests plus production app/CLI builds.
- Boundary: the feature does not infer architecture or behavior, generate an
  idea automatically, persist a card, create a task/Codex plan, copy code,
  invoke CAM, mine a corpus, or alter the selected repository.

### Explicit repository idea to local-task promotion — 2026-07-26

- Expected red: a repository idea card had no local-task mapping, so the
  focused repository suite failed at compile time before implementation.
- Green: a clean, cited idea card now creates a deterministic `localRead` task
  with every source commit/file/line citation and the user-authored validation
  experiment. The mapper rejects dirty or stale snapshots.
- Green: after a proposal-only idea is shown, the native Repositories screen
  exposes `Save as Local Task`; it stores the cited task in the local vault and
  refreshes the existing task workspace. It does not execute the task, copy
  code, invoke CAM, contact a network, or alter the inspected repository.
- Green: `/bin/zsh scripts/verify.sh repositories` passed 17 focused tests,
  including task-store restart persistence, and `/bin/zsh scripts/verify.sh all`
  passed 142 tests with production app/CLI builds.
- Boundary: idea cards and research-packet receipts remain ephemeral; separate
  durable card/research-packet/Codex-plan promotion, repository job lifecycle,
  and CAM mining proof remain unfinished.

### Retained repository idea decisions — 2026-07-26

- Expected red: no `RepositoryIdeaStore` or retained decision type existed, so
  the focused repository suite failed before implementation.
- Green: explicit Keep and Reject actions now persist a cited local card with
  canonical repository path, exact clean commit, user-authored counterevidence,
  validation experiment, and decision. Restart tests prove both dispositions
  survive and dirty snapshots fail closed.
- Green: Reject disables local-task promotion for the displayed card. Keep and
  reject both preserve evidence only; neither performs research, runs a task,
  invokes CAM, calls a network, copies code, or mutates a repository.
- Green: `/bin/zsh scripts/verify.sh repositories` passed 18 focused tests and
  `/bin/zsh scripts/verify.sh all` passed 143 tests with production app/CLI
  builds. `git diff --check` also passed.
- Boundary: retained cards do not yet have a history/list workspace, and there
  is no durable research-packet or Codex-plan promotion path.

### Retained repository idea history — 2026-07-26

- Expected red: no local display projection existed for retained idea cards.
- Green: the Repositories screen now loads and explicitly reloads retained
  local ideas after restart, showing each Keep/Reject decision, cited commit
  summary, counterevidence, and validation experiment without rereading a
  repository.
- Green: `/bin/zsh scripts/verify.sh repositories` passed 19 focused tests and
  `/bin/zsh scripts/verify.sh all` passed 144 tests with production app/CLI
  builds.
- Boundary: retained history is evidence and review context only; it cannot
  execute tasks, alter a donor repository, invoke CAM, contact a network, or
  create a research packet/Codex plan.

### Persisted selected repository sources — 2026-07-26

- Expected red: no local source registry existed for selected repositories.
- Green: repository paths are now atomically persisted locally, de-duplicated
  by canonical path, restored after restart, and removable without opening a
  repository. The native view can select a saved path, while inspection remains
  an explicit separate action.
- Green: `/bin/zsh scripts/verify.sh repositories` passed 20 focused tests and
  `/bin/zsh scripts/verify.sh all` passed 145 tests with production app/CLI
  builds. `git diff --check` passed.
- Boundary: saving a source does not inspect Git, index bytes, schedule a job,
  invoke CAM, or grant mining authority.

### Approved project-contract retrieval corpus — 2026-07-26

- Assumption: the user-approved local product contracts are safe, non-personal
  evaluation material. Their source paths and pre-evaluation SHA-256 digests
  are frozen in a separate `project-contract-v1` manifest; no v2 labels were
  changed.
- Green: the five-source, ten-passage, six-query corpus passed frozen label,
  retrieval, and exact-citation checks. Its saved report records Recall@10
  `1.0`, MRR `1.0`, cited-claim quote support `1.0`, and warm p95 `0.079417 ms`
  over 30 measured samples.
- Green: `/bin/zsh scripts/verify.sh retrieval` passed 19 focused tests and
  `/bin/zsh scripts/verify.sh all` passed 146 tests with production app/CLI
  builds. `git diff --check` passed.
- Boundary: this is narrow approved project-contract evidence, not a
  personal-vault/repository corpus, generated-answer faithfulness evaluation,
  semantic-entailment proof, or SOTA claim.

### Bounded extractive local chat — 2026-07-26

- Expected red: local chat rendered only the first retrieved passage while
  attaching citations for every retrieved passage.
- Green: a supported local answer now renders at most three locally retrieved
  excerpts and emits exactly the same cited excerpts. Empty excerpts are
  excluded; no model, transport, CAM, or source mutation is involved.
- Green: `/bin/zsh scripts/verify.sh conversation` passed 5 focused tests and
  `/bin/zsh scripts/verify.sh all` passed 147 tests with production app/CLI
  builds. `git diff --check` passed.
- Boundary: this is an extractive evidence display, not generated synthesis,
  semantic-answer faithfulness, or a substitute for a selected local model.

### Read-only Mac Care review findings — 2026-07-26

- Expected red: Mac Care reported raw storage/app/startup counts but offered no
  bounded interpretation for space or inventory review.
- Green: the native assessment now reports free-space percentage, a low-space
  review finding below 10%, and explicit startup/application inventory review
  findings. The app describes these as review prompts only.
- Green: `/bin/zsh scripts/verify.sh mac-care` passed 5 focused tests and
  `/bin/zsh scripts/verify.sh all` passed 148 tests with production app/CLI
  builds. `git diff --check` passed.
- Boundary: this does not collect app-usage history, decide whether an app is
  needed, recommend deletion, perform cleanup, or enable apply/undo actions.

### Explicit kept local research plans — 2026-07-26

- Expected red: local research plans were ephemeral-only and could not survive
  restart or be resumed from a user-kept checkpoint.
- Green: `ResearchPlanStore` now atomically persists only explicitly kept
  question/checkpoint records. The native Research screen exposes Keep and a
  local Resume control; beginning a plan still writes nothing.
- Green: `/bin/zsh scripts/verify.sh research` passed 6 focused tests and
  `/bin/zsh scripts/verify.sh all` passed 149 tests with production app/CLI
  builds. `git diff --check` passed.
- Boundary: a kept plan contains no findings, source bytes, web output, model
  output, task, CAM invocation, or scheduled/external execution authority.

### Repository idea to local research-plan promotion — 2026-07-26

- Expected reds: repository ideas had only a proposal label; no typed local
  research plan carried their clean-snapshot evidence, uncertainty, or
  validation requirement. Resume also discarded plan provenance.
- Green: an explicit Repository action now creates and keeps a local research
  plan from a clean cited idea, preserving canonical source path, commit,
  file/line citations, confidence, counterevidence, and validation experiment.
  Research displays this provenance and resume preserves it.
- Green: `/bin/zsh scripts/verify.sh repositories` passed 21 focused tests and
  `/bin/zsh scripts/verify.sh research` passed 6 focused tests;
  `/bin/zsh scripts/verify.sh all` passed 150 tests with production app/CLI
  builds. `git diff --check` passed.
- Boundary: this is a local planning handoff only. It does not copy repository
  bytes, acquire sources, execute a research run, contact a network, invoke
  CAM, create a Codex plan, or alter a repository.

### Repository idea to local Codex-plan handoff — 2026-07-26

- Expected red: a repository idea could not become a durable, cited planning
  handoff without pretending to invoke a live Codex/CAM runtime.
- Green: an explicit action now saves a `proposal`-authority task titled
  `Codex plan handoff`, with the clean commit/file/line citations,
  counterevidence, and smallest validation experiment preserved as criteria.
- Green: `/bin/zsh scripts/verify.sh repositories` passed 22 focused tests and
  `/bin/zsh scripts/verify.sh all` passed 151 tests with production app/CLI
  builds. `git diff --check` passed.
- Boundary: this is a local handoff for a future coordinator. It does not call
  Codex/CAM, execute work, perform repository I/O, or authorize any mutation.

### Bounded low-confidence local chat follow-up — 2026-07-26

- Expected red: an empty local context reported low confidence but offered no
  single bounded next action.
- Green: the response carries one local-only follow-up—capture or index a
  relevant source and ask again—and the native chat view renders it.
- Green: `/bin/zsh scripts/verify.sh conversation` passed 5 focused tests and
  `/bin/zsh scripts/verify.sh all` passed 151 tests with production app/CLI
  builds. `git diff --check` passed.
- Boundary: the follow-up is not an auto-retry or an invitation to web, cloud,
  CAM, or any other escalation.

### Commit-cited Swift import dependency observations — 2026-07-26

- Expected red: repository review exposed TODO/FIXME markers and declarations
  only; committed module dependencies were not visible as cited evidence.
- Green: clean-snapshot Swift scans now record literal `import` module names
  with commit/file/line evidence for review.
- Green: `/bin/zsh scripts/verify.sh repositories` passed 23 focused tests and
  `/bin/zsh scripts/verify.sh all` passed 152 tests with production app/CLI
  builds. `git diff --check` passed.
- Boundary: imports are factual dependency declarations only; this does not
  infer architecture/behavior, inspect a dirty worktree, mine CAM, or mutate a
  repository.

### Explicit local knowledge and contradiction retention — 2026-07-26

- Green: kept cited chat answers can be classified as facts or assumptions and
  are shown in the native Library. `KnowledgeStore` persists them atomically
  across restart.
- Green: `ContradictionStore` persists a manually supplied candidate with both
  cited positions, steelman, and bridge suggestion intact.
- Green: `/bin/zsh scripts/verify.sh knowledge` passed 4 focused tests and
  `/bin/zsh scripts/verify.sh conversation` passed 5 focused tests;
  `/bin/zsh scripts/verify.sh all` passed 154 tests with production app/CLI
  builds. `git diff --check` passed.
- Boundary: no content becomes knowledge automatically; contradiction storage
  has no automatic resolution.

### Native contradiction review workflow — 2026-07-26

- Green: the Library lets the user select two distinct retained claims, supply
  a required steelman plus optional bridge, keep the candidate, and review
  both positions without merging them.
- Green: `/bin/zsh scripts/verify.sh knowledge` passed 4 focused tests and the
  native app compiled.
- Boundary: candidate creation and retention are local-only; no automatic
  conflict detection, resolution, external research, or source mutation runs.

### Explicit verified research-packet retention — 2026-07-26

- Green: `ResearchPacketStore` atomically persists only explicit
  citation-validated `ResearchPacket` records across restart.
- Green: `/bin/zsh scripts/verify.sh research` passed 7 focused tests and
  `/bin/zsh scripts/verify.sh all` passed 155 tests with production app/CLI
  builds. `git diff --check` passed.
- Boundary: packet retention does not acquire documents, contact a network,
  generate findings, retain raw source bytes, or provide a native
  packet-authoring UI.

### Cancellable local repository indexing — 2026-07-26

- Expected red: repository indexing could only run to completion; an explicit
  cancellation path did not exist and snapshot receipt behavior was unproven.
- Green: native repository indexing now exposes Cancel and checks a shared
  cancellation token before/among capture, retry, processing, and receipt
  persistence. Cancellation leaves no new snapshot receipt.
- Green: `/bin/zsh scripts/verify.sh repositories` passed 24 focused tests and
  `/bin/zsh scripts/verify.sh all` passed 156 tests with production app/CLI
  builds. `git diff --check` passed.
- Boundary: indexing is still foreground-only and has no persisted job or
  background scheduler; cancellation preserves immutable captured content.

### Canonical finish goal and publication baseline — 2026-07-26

- Green: `GOAL_FINISH_WIKI.md` now provides a self-contained completion
  contract for the full three-layer native wiki/assistant product, including
  explicit current baseline, proof gates, scope, constraints, iteration,
  provenance, stop, and completion rules.
- Green: the approved design and eight-phase implementation plan are saved at
  `docs/plans/2026-07-26-finish-wiki-design.md` and
  `docs/plans/2026-07-26-finish-wiki.md`.
- Green: `/bin/zsh scripts/verify.sh all` passed 156 tests and release-built
  the native app and CLI; package validation, offline smoke, and
  `git diff --check` passed before publication.
- Boundary: this establishes the canonical recovered foundation and finish
  contract. It does not claim that the remaining live local-model, web,
  CAM-mining, mutating Mac Care, accessibility, or distribution gates are
  implemented.

### Portable fresh-clone verification — 2026-07-26

- Expected red: focused portability tests failed because `IMPLEMENT.md` and
  `PROGRESS.md` still depended on parent-workspace plans and `scripts/verify.sh`
  had no portability or fresh-clone entry points.
- Green: governing truth now resolves entirely inside the canonical repository;
  tracked Finder/build/artifact output is rejected and `git diff --check` is
  part of the portability receipt.
- Green: a temporary `git clone --no-local` of commit `162de43` passed the
  repository-local portability check, 158 tests, native app/CLI release build,
  unsigned app package validation, and offline smoke.
- Saved receipt: `docs/evidence/task-13-portable-fresh-clone.md`.
- Boundary: this proves a clean clone can reproduce the local foundation. It
  does not prove any remaining live model, web, CAM, Mac mutation, or complete
  GUI journey.

### Native Library source detail and citation navigation — 2026-07-27

- Expected reds: `LibraryPresentation` had aggregate modality counts only and
  could not represent source rows, capture provenance, or resolve a citation
  to a local source.
- Green: Library now lists stable derived-source IDs, citation passage IDs,
  modality, extractor, bounded derived preview, and every stored clipboard,
  watched-folder, or repository capture origin.
- Green: each cited local chat passage exposes `Open in Library`; navigation
  succeeds only for an exact source/passage match and selects the corresponding
  read-only detail.
- Green: the focused ingestion/Library suite passed 17 tests;
  `/bin/zsh scripts/verify.sh all` passed 159 tests and release-built the native
  app and CLI; package validation, offline smoke, and `git diff --check` passed.
- Boundary: the detail is derived local text and provenance only. It does not
  expose immutable raw source bytes, edit or delete a source, create knowledge,
  invoke a model, or change authority.

### Grounded selected local-model chat — 2026-07-27

- Expected reds: no typed local inference transport/client, selected-model
  health identity, generated-response conversation route, redirect refusal, or
  exact evidence-ID validation existed.
- Green: an explicitly selected local assignment can be health-checked through
  its OpenAI-compatible loopback `/models` endpoint and invoked through
  `/chat/completions`; the native UI displays health, route, model, and
  endpoint identity.
- Green: generation sends the current bounded local context without an
  authorization header and accepts only structured answers whose unique
  passage IDs exactly match that context. Unknown/missing evidence, HTTP
  errors, malformed responses, model identity drift, and every redirect fail
  visibly without fallback.
- Green: generated answers become citation-bearing, supported, ephemeral
  conversation responses and retain no output automatically.
- Green: `/bin/zsh scripts/verify.sh models` passed 6 focused inference tests;
  `CAM_ASSISTANT_SKIP_FRESH_CLONE=1 /bin/zsh scripts/verify.sh all` passed 165
  tests and release-built the native app and CLI; package validation, native
  offline smoke, and `git diff --check` passed.
- Saved receipt:
  `docs/evidence/task-13-grounded-local-model-chat.md`.
- Boundary: this checkout has no active local profile or running compatible
  model service. No live generation receipt, generated-claim faithfulness
  score, or end-to-end model latency claim is made; those remain hard CAM-013
  proof work, not a blocker.

### Agno cookbook adaptation recon — 2026-07-27

- Green: checkpoint commit `dd73348` was pushed to
  `origin/agent/portable-canonical-repo` before the recon.
- Green: the two 231,721-line `agnocook.txt` copies are byte-identical; the
  local `py314` environment contains `agno 2.8.5` and exposes the surveyed
  approval, checkpoint, filesystem, workflow, eval, and wiki APIs.
- Green: a read-only map and ranked risk assessment are saved under
  `docs/research/agno/`.
- Assessment: eval trajectories, safe-boundary checkpoint/fork, atomic
  approval resolution, tool middleware, and bounded durable working records
  are worth designing as Swift-native additions.
- Boundary: no Agno code was copied, no cookbook was executed against a model,
  no external repo was modified, and no Python/Agno dependency was added.
  Checkpoint examples are syntax-only in their saved log and many workflow
  examples have red receipts, so none is treated as production proof.

### Reversible local source visibility lifecycle — 2026-07-27

- Expected reds: the Library presentation had no hidden-source collection or
  lifecycle action contract, and `IngestQueue` had no durable source lifecycle
  API. The corrected focused suite failed specifically on those missing APIs.
- Green: SQLite schema version 7 stores explicit Active/Hidden source state;
  missing legacy state remains Active. Hide and restore survive restart.
- Green: hiding removes the derived document from active Library rows, exact
  citation navigation, and database-backed local conversation context. Hidden
  sources remain visible in a separate native review list with an explicit
  Restore action.
- Green: content-addressed bytes, object count, every capture provenance
  record, and derived-document history remain unchanged through hide,
  restart, and restore.
- Green: 20 focused ingestion/lifecycle tests, 5 conversation tests, and 4
  storage tests passed. `CAM_ASSISTANT_SKIP_FRESH_CLONE=1 /bin/zsh
  scripts/verify.sh all` passed 168 tests and release-built the app and CLI;
  package validation, offline smoke, and `git diff --check` passed.
- Green: a temporary clean clone of commit `a80367a` independently passed all
  168 tests, release builds, package validation, and offline smoke.
- Saved receipt: `docs/evidence/task-13-source-lifecycle.md`.
- Boundary: Hidden is not deletion, secure erasure, or raw-source inspection.
  Existing retained claims/citations are not rewritten; their Library
  navigation remains unavailable until the source is restored.

### Integrity-checked bounded raw-source inspection — 2026-07-27

- Expected red: the focused build failed because `ContentStore` had no
  invalid-identity or integrity-mismatch failures and `IngestQueue` had no
  typed raw-source inspection API.
- Green: content reads now reject traversal-shaped or otherwise invalid
  identities and re-hash every object before returning its bytes. Tampering
  fails closed.
- Green: the explicit native Library action displays verified source identity,
  byte count, content type, and original name. Valid textual content receives a
  bounded selectable preview with a truncation notice; binary and invalid
  UTF-8 content receives metadata only.
- Green: hidden sources remain selectable and inspectable without changing
  lifecycle, content bytes, provenance, derived history, or retention state.
- Green: 6 focused storage tests and 22 focused ingestion tests passed.
  `CAM_ASSISTANT_SKIP_FRESH_CLONE=1 /bin/zsh scripts/verify.sh all` passed 172
  tests and release-built the app and CLI; package validation, offline smoke,
  and `git diff --check` passed.
- Green: a temporary clean clone of commit `3ed92c5` independently passed all
  172 tests, release builds, package validation, and offline smoke.
- Saved receipt: `docs/evidence/task-13-raw-source-inspection.md`.
- Boundary: inspection is not edit, export, deletion, secure erasure, media
  rendering, or evidence that source claims are true.

### Frozen generated-answer evaluation and live local-model comparison — 2026-07-27

- Expected reds: explicit model abstention was not represented in conversation
  state; no frozen generated-answer fixture/evaluator/CLI existed; and the
  machine-readable report initially omitted its computed gate verdict.
- Green: generated requests use JSON Schema with exact current-context
  passage-ID constraints, deterministic settings, and a bounded token count.
  Only empty answer plus empty citations is accepted as abstention; mixed
  states fail closed. Abstention remains identified, ephemeral, low-confidence,
  uncited, and unpromotable.
- Green: the frozen seven-passage/seven-case manifest validates against hard
  SHA-256
  `5eff382987e236994bc755c9107c169fda1896c99cbb4c353dad64ad1e8006ae`.
  The evaluator measures retrieval, bounded context, selected loopback-model
  generation, exact citations, deterministic claim coverage, abstention, and
  warm latency as one operation. Reports serialize runtime/model/endpoint
  identity, failures, thresholds, and the final gate verdict.
- Green: focused generated-answer tests passed after the expected
  serialization red. A live LM Studio MLX service and an outside-sandbox
  Ollama service were bound to loopback only; temporary model/server state was
  stopped after measurement.
- Green: `/bin/zsh scripts/verify.sh generated` passed 3 evaluator, 7 local
  inference, and 6 conversation tests.
  `CAM_ASSISTANT_SKIP_FRESH_CLONE=1 /bin/zsh scripts/verify.sh all` passed all
  177 tests and release-built the native app and CLI; package validation,
  offline smoke, and `git diff --check` passed.
- Negative evidence: valid `llama3.2:1b` runs reached at most `0.3333`
  cited-claim support with zero abstention accuracy and p95 above `619 ms`;
  `ornith:9b` reached correct abstention but zero claim support and p95 above
  `60 s`; MLX `vibethinker-3b-optiq-5bpw-mlx` reached `0.1667` support,
  correct abstention, and p95 `1,393 ms`. Retrieval Recall@10 and MRR were
  `1.0` in every valid run. No model passed the frozen gate.
- Invalid-environment evidence: an initial sandbox-contained Ollama run failed
  Metal command-queue creation and every generation returned HTTP 500. It is
  preserved separately and excluded from model comparison.
- Saved receipt:
  `docs/evidence/task-13-generated-answer-evaluation.md` plus six
  machine-readable reports.
- Boundary: this proves a usable evaluation surface and real negative model
  results, not a passing generated-answer model or packaged GUI journey.
  CAM-013 remains in progress and the overall goal is not blocked.

## Blockers

None.

## Questions for User

None required for the initialization milestone.
