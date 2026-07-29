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
| 12. UX, packaging, and aggregate proof | In progress | Codex | Isolated packaged clipboard/hotkey/watched-source/cancel/restart/resume/selected-model/full-vault-recovery journeys and aggregate proof pass; full accessibility, repeatable GUI automation, and completion audit remain |

## Decision Links

- See `DECISIONS.md`.
- Controlling goal: `GOAL_FINISH_WIKI.md`.
- Approved design: `docs/plans/2026-07-26-finish-wiki-design.md`.

## Current Milestone

Find a named local model that passes the now-frozen V3 repository contract and
complete its packaged native clean-repository journey, while preserving the
verified durable repository-job lifecycle and full-vault fresh-root recovery
gate. CAM-013 remains in progress because the frozen generated-answer quality
checks pass but its latency gate does not. Cloud-context loading, live catalog
lookup, provider testing, web, embedding promotion, CAM mining, and mutating
workflows remain disabled until their individual proof gates are met.

## Next Actions

1. Run the unchanged V3 contract against a different named loopback model;
   preserve every failure and do not change its claim catalog, roles,
   distractors, labels, or thresholds.
2. If a named model passes, complete the packaged native journey with a
   disposable clean repository, saved pre/post byte and Git-status proof, and
   one explicit disposition or promotion.
3. Preserve generated-answer v1 as the fixed baseline while separately
   designing its versioned latency contract, then extend packaged accessibility
   proof through VoiceOver speech, contrast, text scale, and large-data states.

### Live CAM runtime identity and disposable preflight — 2026-07-29

- The installed `cam` CLI, selected CAM_Codx/CAM_CAM repositories, selected
  config, and selected corpus were identified without loading credential
  values or authorizing execution.
- Pinned selected identities: CAM_Codx
  `60f747db61791a6addba8db1cbafbd5121fd2a29`, CAM_CAM
  `db5495a5b963688a9c29e5d06c5447e781544f1c`, config SHA-256
  `13c04f0939142042bc560849b0ea7193d9a9d9cbddfd02ee949094312f4f7597`,
  and corpus SHA-256
  `e391bf171f66c2086ad8b8785432d9b142f8f4c5a9ad5e7f8db41ea69339ca74`.
- The installed `claw` `0.1.0` entry point resolves through
  `/Volumes/WS4TB/WS4TBr/CAM_Codx/CAM_CAM`, a different checkout at the same
  runtime commit. This path/commit distinction is now an explicit drift check.
- Immutable SQLite inspection passed `quick_check` and found 2,516
  methodologies. A copied corpus/config then passed real `cam stats`,
  `cam status`, and `cam doctor expectations`; CAM reported 197 source
  repositories and successfully loaded `sqlite-vec`.
- Critical boundary: direct protected-corpus `status`/`stats` failed because
  CAM unconditionally enables WAL and initializes schema. The disposable
  database hash changed after the nominal health commands, directly proving
  that current CAM health startup is mutating.
- The selected corpus/config hashes and donor Git states remained unchanged.
  No provider request, mining, MCP server, repository mutation, or credential
  value access occurred.
- Goal-map effect: `cam.runtime-verification` moves from `missing` to
  `partial`; totals are now `12 passed`, `27 partial`, and `9 missing`.
- Saved evidence:
  `docs/evidence/task-16-live-cam-runtime-preflight.md`.
- Next implementation boundary: app-owned discovery must pin executable,
  source, config, corpus, and capability identities, then probe only an
  integrity-checked disposable copy before any separately approved executor.

### Named repository-semantic local-model runs — 2026-07-29

- LM Studio was started on loopback only and the unchanged frozen semantic-v2
  manifest was run through the existing release CLI against
  `vibethinker-3b-optiq-5bpw-mlx` and `gemma-4-12b-it-optiq`.
- Both runs completed with exit `2` and zero on all four frozen metrics. The
  reports remain separate failures and do not satisfy CAM-015.
- Vibethinker recorded one duplicate-evidence failure plus three generator
  failures. Gemma recorded two missing-required-concept failures plus two
  generator failures.
- Direct synthetic-case diagnosis proved the abstention generator failures
  occur because an empty allowed-ID set becomes an invalid `enum: []` JSON
  Schema rejected by LM Studio before inference.
- Gemma returned the required evidence and counterevidence IDs with a
  semantically correct cache/actor limitation, but the frozen lexical matcher
  rejected its wording because it omitted the literal accepted
  `actor-isolated` phrase.
- V2 labels and thresholds remain unchanged after observation. A later
  separately pre-registered contract must repair empty-ID abstention and
  evaluate semantic support without tuning to these outputs.
- Both models were unloaded and the LM Studio server was stopped after the
  bounded runs. No cloud, web, CAM, credential, donor, or personal-data route
  was used.
- Saved receipts:
  `docs/evidence/task-15-repository-semantic-vibethinker-failed.json` and
  `docs/evidence/task-15-repository-semantic-gemma-failed.json`.

### Additional generated-answer local-model investigation — 2026-07-29

- The installed 423M `gemma-4-12b-it-qat-assistant-mtp` model was selected as
  a fast candidate but failed two local LM Studio load attempts before
  inference. Runtime logs identify the exact cause:
  `Gemma4Assistant requires ctx_other to be set`.
- The installed
  `qwen3.6-35b-a3b-claude-4.7-opus-oq4e-dwq-mc-mtp-mlx` model loaded with
  MTP speculative decoding at 19.32 GiB resident memory and ran the unchanged
  frozen generated-v1 corpus.
- The complete 21-measurement run retained perfect retrieval but produced
  zero cited-claim support, zero abstention accuracy, seven failed cases, and
  `3,821.14 ms` p95. It is both lower quality and slower than the current
  Gemma 12B result.
- The report serializes `meetsFrozenThresholds=false`; the CLI originally
  returned process status `0`. A focused red/green contract now maps a passing
  report to `0` and a failed report to `2`, after the report is written.
- A disposable loopback command proof returned invalid structured answers for
  all seven unchanged cases. The CLI saved the failed JSON report, printed
  `frozen gates: fail`, and terminated with process status `2`. No result,
  threshold, live model, cloud route, or personal-vault state was used or
  changed.
- The Qwen report is saved at
  `docs/evidence/task-13-generated-answer-qwen36-a3b-mtp-failed-report.json`
  with SHA-256
  `191ca518a66fa90867319c64fa1fecb99d5039f8e21d148013b6ee5e84a19669`.
- Fresh verification after archiving the report passes the 48-gate source
  coverage validator with the honest `12 passed / 27 partial / 9 missing`
  verdict, all 222 Swift tests, deterministic two-build packaging, and the
  48-file release credential-signature scan with zero findings.
- All models were unloaded and LM Studio was stopped. CAM-013 remains in
  progress and the generated-answer goal gate remains partial.

## Verification Receipts

### Clean packaged empty-state accessibility inspection — 2026-07-29

- Rebuilt the packaged app at exact clean commit
  `94977951b558435f97c5c4967092dd73edfa88dc`; embedded dirty state is false,
  bundle version is `51`, and the executable SHA-256 is
  `2112dac8cd45cb69e7132249b44b29c15f602c39c6d72a876166ea50743d3e61`.
- Launched only with disposable application-support root
  `/private/tmp/cam-gui-audit-clean.GrWMaK` and inspected a fresh native
  accessibility tree after selecting Assistant, Library, Activity, Tasks,
  CAM, Research, Repositories, Mac Care, Settings, and every Settings pane.
- Every empty primary workspace exposed a named container or control set plus
  an honest empty/offline/disabled authority message. The isolated database
  remained empty across sources, derived documents, tasks, and repository
  jobs; the disposable root was removed after quit.
- An ordinary Tab key produced no observable focus change under the host's
  current keyboard-navigation setting. No system setting was changed. This
  remains a keyboard-harness limitation, not proof of an app focus defect.
- Saved bounded evidence:
  `docs/evidence/task-18-packaged-empty-state-accessibility.md`. Complete
  VoiceOver speech, every tab stop, populated/error/large-data states, visual
  accessibility, and repeatable repository-owned GUI automation remain open.

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
- Green: a temporary clean clone of pushed commit `b9707ae` independently
  passed portability, all 177 tests, release builds, package validation, and
  offline smoke.
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

### Isolated packaged hotkey, capture, and restart journey — 2026-07-27

- Expected red: the first real Command-Option-K exercise remained in Finder.
  A focused regression test proved the app incorrectly treated macOS letter
  virtual key codes as alphabetically contiguous.
- Green: every A-Z shortcut now maps to its explicit Carbon key constant. The
  collision-safe default open shortcut is Command-Option-K; capture remains
  Command-Option-C.
- Green: the packaged global-open journey changed the frontmost process from
  `Finder -> CAMAssistant`. A reversible harmless clipboard marker triggered
  the real capture action and the native UI reported successful local indexing.
- Green: a new absolute-path-only application-support override isolated vault,
  model, and hotkey state. The isolated vault contained one 46-byte source and
  one derived document; the normal vault counts and normal hotkey-file absence
  remained unchanged during the valid proof.
- Green: native Settings exposed Models, Hotkeys, and Capture Sources panes.
  Duplicate C/C shortcuts produced a visible save error; K/C saved only inside
  the disposable root.
- Green: after packaged-app termination and relaunch on the same isolated root,
  Library reported one active source and the K/C registration recovered.
- Green: the non-recursive aggregate verifier passed portability, all 183
  tests, and app/CLI release builds. Package validation and native offline
  smoke also passed.
- Green: a temporary non-local clone of pushed commit `715dfc3` independently
  passed portability, all 183 tests, release builds, package validation, and
  offline smoke from a clean source tree.
- Saved receipt: `docs/evidence/task-13-packaged-hotkey-journey.md`.
- Boundary: an earlier exploratory non-isolated clipboard capture is explicitly
  excluded; its local content was neither committed nor transmitted and was
  not deleted without authorization. The valid isolated proof does not close
  watched-folder, backup/restore, selected-model, or full accessibility gates.

### Packaged watched-folder lifecycle and live Library refresh — 2026-07-28

- Expected red: after a real watched-folder event, the isolated database
  advanced from one to three sources and derived documents while the packaged
  Library remained visibly stale at one.
- Green: successful watched capture now posts a local status and schedules a
  main-actor Library reload. The focused regression test requires message
  before refresh.
- Green: the corrected package updated an already-visible Library from three
  to four active sources automatically after a watched event.
- Green: folder selection began Paused; explicit Enable showed
  `Watching locally`. Pause prevented an immediate capture and Resume returned
  to watching. The next event captured both pending and new files, producing
  six isolated sources.
- Green: Remove returned the UI to no configured folders, a later file event
  did not change the six-source count, and all previously captured immutable
  sources remained in Library.
- Green: all 184 tests passed and the corrected unsigned package rebuilt and
  validated.
- Green: a temporary non-local clone of pushed commit `e5a0238` independently
  passed portability, all 184 tests, release builds, package validation, and
  offline smoke from a clean source tree.
- Boundary: proof used only ignored harmless files and the disposable
  application-support root. It does not yet prove a native cancellation
  journey, backup/restore, or the selected-model journey.

### Native ingest cancellation and restart recovery — 2026-07-28

- Expected red: focused ingest tests failed to compile because the queue had no
  persisted job-listing, direct cancellation, or exact-job resume APIs.
- Green: Activity reads status-only persisted job metadata without source
  bytes. Pending jobs can be cancelled; cancelled/failed jobs can be resumed;
  invalid transitions fail; exact resume cannot consume an unrelated older
  pending item.
- Green: cancellation preserves content-addressed source bytes. Cancelled state
  survives packaged-app restart; Resume completes local extraction and
  refreshes Library.
- Green: automatic capture remains the default. Only the explicit disposable
  `CAM_ASSISTANT_DEFER_CAPTURE_PROCESSING=1` proof harness stops after durable
  enqueue for native lifecycle review.
- Accessibility red and correction: SwiftUI List grouped the visual job action
  into its row description. The final scrollable Activity stack exposes
  separate `Cancel pending ingest` and `Resume ingest` accessibility buttons;
  both were exercised through their accessibility elements.
- Green: the final isolated packaged journey progressed
  Pending/0 -> Cancelled/0 -> restart -> Cancelled/0 -> Completed/1, then
  Library reported one active indexed source. The isolated database independently
  reported one source and one derived document.
- Evidence correction: an invalid direct-binary launch did not inherit the
  isolation environment and added its harmless marker to the normal local
  vault. It is excluded from the valid proof, was not transmitted, and remains
  untouched because deletion was not authorized.
- Green: 25 focused ingest tests, 6 app tests, all 188 tests, portability,
  app/CLI release builds, unsigned package validation, offline smoke, and
  `git diff --check` passed locally.
- Green: a temporary non-local clone of pushed commit `7d8b820` independently
  passed portability, all 188 tests, app/CLI release builds, package
  validation, and offline smoke from a clean source tree.
- Saved receipt:
  `docs/evidence/task-13-ingest-cancellation-recovery.md`.
- Boundary: this closes the bounded capture cancellation/recovery slice, not
  full-vault backup/restore, background ingestion, secure deletion, selected
  model, or complete accessibility/release gates.

### Live Gemma evaluation and packaged selected-model journey — 2026-07-28

- Green quality evidence: installed LM Studio model
  `gemma-4-12b-it-optiq` passed all six frozen answer cases and the explicit
  unsupported-case abstention across 21 measured samples. Recall@10, MRR,
  cited-claim support, and abstention accuracy were all `1.0`; there were no
  failed or unanswered cases.
- Honest red: warm end-to-end p95 was `2,010.38 ms`, above the frozen
  `<500 ms` threshold. The saved report verdict remains Fail and CAM-013 stays
  in progress. The report SHA-256 is
  `fd18e613f1dc0e2d87cdaf9b85302e1198150a9c43258605f9dfb70f1b81db4a`.
- Packaged-journey red: a fresh isolated source completed ingestion, but
  selected-model chat rejected it as missing context. Root-cause tracing showed
  production chat required every raw question token to be an exact substring
  while the evaluator used the persistent FTS/hybrid retrieval stack.
- TDD correction: the database-backed regression first failed on empty context
  and absent `retrieval-index/active-generation.json`. Production chat now
  rebuilds/opens that persistent generation and ranks through
  `HybridRetriever`, while preserving canonical `source#0` citations for exact
  Library navigation.
- Green packaged journey: isolated profile `gemma-local` revision 1
  health-checked the exact loopback model; the rebuilt package generated a
  supported cited answer, displayed model/endpoint identity, offered no
  fallback, kept the answer ephemeral, and opened its exact citation in
  Library. No normal-vault or cloud data was used.
- Green verification: the focused red/green test passed, the aggregate
  verifier passed all 189 tests plus app/CLI release builds, the unsigned
  package rebuilt and validated, and `git diff --check` passed.
- Green: a temporary non-local clone of pushed commit `5ea2395` independently
  passed portability, all 189 tests, app/CLI release builds, package
  validation, and offline smoke from a clean source tree.
- Saved receipts:
  `docs/evidence/task-13-generated-answer-evaluation.md`,
  `docs/evidence/task-13-generated-answer-gemma-4-12b-optiq-report.json`, and
  `docs/evidence/task-13-grounded-local-model-chat.md`.
- Boundary: this closes the packaged selected-model workflow for the tested
  LM Studio adapter, not the frozen latency gate, native in-process MLX,
  full-vault backup/restore, or the remaining accessibility/release gates.

### Packaged accessibility, keyboard, and motion slice — 2026-07-28

- Green baseline: the isolated unsigned package opened with the local question
  field focused; blank Return exposed the validation error and retained focus.
  Tab selected the sidebar and Down traversed Library, Activity, Tasks, CAM,
  Research, Repositories, Mac Care, and Settings in order.
- Green semantics: Activity, CAM, Research, Repositories, Settings, Hotkeys,
  and Capture Sources exposed their controls, selected values, empty/offline
  states, and local/disabled-execution boundaries in the native accessibility
  tree. A disposable duplicate-hotkey attempt exposed its error while retaining
  field focus.
- Expected red: Library, Tasks, and Mac Care collapsed their descendants into
  repeated root summary labels, hiding meaningful empty/read-only descriptions
  and controls from the accessibility tree.
- TDD correction: the new source-contract regression failed against all three
  views. Their root summary elements now preserve children with
  `.accessibilityElement(children: .contain)`. Review then tightened the
  regression to bind the exact root chain to each required state/action and
  added a negative case that rejects unrelated containment; both focused tests
  pass.
- Green packaged recheck: the rebuilt Library exposes Refresh plus its empty
  guidance, Tasks exposes Refresh plus its no-saved-tasks guidance, and Mac
  Care exposes its assessment control plus exact read-only/approval boundary.
- Green motion scan: the app target contains no explicit SwiftUI animation,
  transition, matched-geometry, symbol-effect, or content-transition APIs.
- Green verification: portability, all 191 tests, the release build, package
  validation, native offline smoke, and `git diff --check` pass.
- Saved receipt:
  `docs/evidence/task-12-packaged-accessibility.md`.
- Boundary: this is a strong accessibility matrix slice, not a complete
  VoiceOver spoken-audio, every-tab-stop, populated-large-data, contrast,
  dynamic-type, signed-distribution, or final release proof. CAM-012 and
  CAM-018 remain in progress.

### Durable repository-job and source lifecycle slice — 2026-07-28

- Expected red: focused tests failed to compile because repository indexing
  had no durable job store, state machine, persistent runner, lifecycle writer,
  or status-only presentation.
- Green: schema version 8 adds `repository_jobs` and
  `repository_source_lifecycle`. Jobs persist pending/running/cancelled/failed/
  completed state, bounded attempts, stable status-only failures, and exact
  completed snapshot commit/source-count linkage.
- Green: app startup converts persisted running work into a visible
  failed/interrupted row only after acquiring that job's OS `flock` lease.
  Work held by another live app process remains running. Cancelled and failed
  work below its attempt limit can resume under the same job ID; completed or
  exhausted work exposes no action.
- Review correction: persistent runners now require one stateful cancellation
  token. Cancellation can win before the terminal snapshot phase; after that
  boundary it is explicitly refused, so the app cannot claim cancellation
  while saving or completing a snapshot receipt.
- Green: the persistent runner's cancellation/retry test proves no cancelled
  snapshot receipt, exact successful snapshot linkage on retry, three derived
  local documents, byte-identical repository source, and unchanged
  `git status --porcelain`.
- Green: SQLite saved-source lifecycle is authoritative. JSON remains a
  compatibility/cache surface and reload repairs either stale-JSON direction
  after a simulated crash split. Synchronous failures roll back; removal
  preserves snapshot history and has no cascade into vault bytes, provenance,
  derived documents, jobs, or ideas.
- Green: Repositories shows status-only recent jobs with independent bounded
  Cancel/Resume controls and explicit local/no-network/no-CAM/no-repository-
  write language. Removal text explicitly states its evidence-preservation
  boundary.
- Review: the first adversarial pass found four Important consistency/test
  gaps. After the lease, terminal-boundary, authoritative lifecycle, and
  injected AppModel corrections, re-review reports zero Critical, Important,
  or Minor findings.
- Verification: all 33 repository-focused tests, all 10 app tests, and all 202
  aggregate tests pass; portability checks, app/CLI production builds,
  unsigned package validation, offline smoke, and `git diff --check` pass.
- Green: a temporary non-local clone of pushed code checkpoint `3762c2c`
  independently passed portability, all 202 tests, app/CLI release builds,
  package validation, and offline smoke from a clean source tree.
- Saved receipt:
  `docs/evidence/task-15-repository-job-lifecycle.md`.
- Boundary: this closes the durable foreground repository-job/removal slice,
  not background scheduling, remote cloning, submodule or issue ingestion,
  secret scanning, semantic observation evaluation, live Codex/CAM execution,
  network authority, or source-byte deletion.

### Full-vault backup and restore gap audit — 2026-07-28

- Green inventory: current app-owned durable state is mapped across
  `vault.sqlite`, immutable `content/` objects, model/hotkey/watched-source/
  repository-source preferences, kept research plans, knowledge, and
  contradictions.
- Existing proof remains correctly bounded: exact immutable-byte component
  backup/restore and a separate SQLite audit backup pass, but they do not prove
  one consistent full-vault snapshot or fresh-root recovery.
- Gap: verified research packets, approvals, module state, and orchestration
  artifacts have store types but no canonical app-owned paths; retrieval
  generations are derived, while process leases and temporary files must not be
  restored.
- The saved audit defines the common requirements for either package choice:
  SQLite online backup, object re-hashing, a versioned relative-path manifest,
  path/symlink rejection, staging validation, authority-safe restore, and
  post-restore reopening.
- Saved audit:
  `docs/evidence/task-18-full-vault-backup-gap-audit.md`.
- Boundary: no backup archive was created, no live application-support data
  was inspected, and no restore, overwrite, merge, deletion, or encryption was
  performed. Full-vault backup/restore remains in progress pending the package
  choice and implementation.

### Dynamic module lifecycle gap audit — 2026-07-28

- Green foundation: versioned manifest decoding, repository fixture discovery,
  enable/disable persistence, separate stored grants, undeclared-permission
  refusal, and isolated health degradation remain verified. The current
  focused `ModuleRegistryTests` rerun passed all six tests with SwiftPM's
  required `--disable-sandbox` option after the unmodified command hit the
  known nested-sandbox denial.
- Reality boundary: manifests are not Swift package resources, the packaged
  app does not initialize a registry or expose a Modules workspace, and no
  module installer, uninstaller, typed dispatcher, real health executor,
  lifecycle receipt, or home-grown module execution exists.
- Authority gap: `ModuleRegistry.capabilities()` currently reflects enabled
  healthy manifests without enforcing declared permissions against current
  grants. No executor consumes this surface today, so it is not live leaked
  authority; a future dispatcher must fail closed on missing grants.
- The audit recommends a first native read-only synthetic module and a
  disposable packaged install/enable/explicit-grant/exercise/disable/remove/
  restart proof, while preserving Layer 1 data.
- Saved audit:
  `docs/evidence/task-17-module-lifecycle-gap-audit.md`.
- Boundary: no live module was installed, enabled, granted permission,
  executed, disabled, or removed. CAM-017 remains planned.

### Policy-gated research acquisition gap audit — 2026-07-28

- Green foundation: seven current focused research tests pass for local
  planning, expected-version resume, citation-verified facts, separately typed
  inferences, explicit plan Keep, and component packet persistence.
- Reality boundary: `WR`/`WRGR` stop at deferred policy, and no typed source
  transport, persistent acquisition job, cancellation/retry, deduplication,
  source-quality record, cost/byte/time receipt, or native packet review exists.
- Correctness gap: `ResearchPacketStore.keep` can persist a packet, but the
  packet still carries `ResearchRetention.ephemeral`; the store also has no
  canonical AppModel-owned path or native history surface.
- The audit defines the required zero-byte protected-data boundary,
  exact request/target/budget binding, untrusted-content isolation,
  citation-before-Keep rule, and visible partial/cancelled/failure semantics.
- Saved audit:
  `docs/evidence/task-14-research-acquisition-gap-audit.md`.
- Boundary: no network, provider, paid request, live source, approval
  consumption, or live-app packet retention occurred. CAM-014 remains planned.

### Live bounded CAM/Codex integration gap audit — 2026-07-28

- Green foundation: seven current CAM adapter/mining tests and sixteen
  coordination tests pass, including exact approval consumption, honest
  unavailable execution, reducer evidence gates, restart replay,
  snapshot/migration validation, handoff packets, and a native child-process
  ownership probe.
- Reality boundary: runtime identity remains caller-supplied fixture data; no
  live runtime/config/database probe, disposable CAM corpus, closed tool
  executor, retry/timeout/idempotency registry, postcondition/recovery
  execution, persisted mining run, trajectory evaluation, or native/CLI run
  controls exist.
- Convergence gap: the simple `CoordinationRun` and event-sourced
  `OrchestrationRunState` overlap with different budget behavior;
  `verifiedPartial` has no reducer transition; and CAM mining has no persisted
  failed/recovered/completed/verified-success lifecycle.
- The audit defines the runtime-drift, exact-plan, untrusted-output,
  closed-tool, disposable-state, verification, and failure-never-success
  boundaries for a future integration.
- Saved audit:
  `docs/evidence/task-16-live-cam-codex-gap-audit.md`.
- Boundary: no CAM runtime, MCP server, config, database, corpus, donor repo,
  credential, network call, or live command was inspected or invoked. CAM-016
  remains planned.

### Safe Mac Care action gap audit — 2026-07-28

- Green foundation: all five current focused Mac Care tests pass for
  deterministic read-only assessment, caller-selected temporary-directory
  counts, bounded review findings, aggregate digest binding, stale refusal, and
  honest apply/undo unavailability.
- Reality boundary: assessment currently exposes free space plus application
  and startup-entry counts only. It has no item-level evidence,
  duplicate/organization analysis, action-specific precondition, preview,
  action card, approval consumption, executor, cancellation, postcondition,
  receipt, undo, restart, or packaged mutation journey.
- Safety boundary: the audit keeps uninstall, delete, privilege, account,
  credential, security-setting, and broad cleanup actions outside the initial
  action set. A first candidate would operate only on synthetic files inside a
  disposable caller-approved root.
- Saved audit:
  `docs/evidence/task-17-mac-care-action-gap-audit.md`.
- Boundary: no live inventory was collected and no file, app, startup item,
  process, preference, account, credential, or system setting was changed.
  CAM-017 remains planned.

### UX, accessibility, recovery, and release gap audit — 2026-07-28

- Green foundation: four current focused accessibility tests and ten app tests
  pass. Existing disposable packaged receipts remain valid for hotkeys,
  watched sources, ingest recovery, selected local-model chat/citations,
  question focus, sidebar keyboard traversal, and repaired accessibility
  containment.
- Proof boundary: several app accessibility tests are source-contract checks,
  not runtime accessibility-tree or VoiceOver proof. Package validation checks
  bundle syntax, and offline smoke executes a direct debug binary's special
  mode rather than a packaged interaction.
- Aggregate gap: `verify.sh all` does not automate the saved GUI journeys,
  VoiceOver speech, contrast/text-scale/large-data matrices, full-vault
  recovery, or a unified fresh-user/restart journey. There is no XCTest UI
  target or repository-owned packaged journey harness.
- Release gap: no final machine-readable requirement map, final package/evidence
  privacy scan, embedded commit/build identity, signing, notarization, or
  distribution proof exists. The latter three remain policy/credential gated.
- Saved audit:
  `docs/evidence/task-18-ux-release-gap-audit.md`.
- Boundary: no packaged GUI, VoiceOver speech, visual measurement, backup,
  signing, notarization, or distribution action occurred. CAM-012 and CAM-018
  remain in progress.

### Release credential-signature gate — 2026-07-28

- Red: the release-proof integration test initially failed because
  `verify.sh` had no `release-privacy` suite.
- Green: the new scanner tests prove a clean scope passes, a synthetic
  credential signature fails, JSON receipts parse, and neither the receipt nor
  command output exposes the matching bytes.
- Green: the real release integration builds the unsigned package, scans the
  package and saved evidence, and records `40` scanned files, `0` findings, and
  `status=pass` in
  `docs/evidence/task-18-release-privacy-scan.json`.
- Green: `scripts/verify.sh all` now invokes this release-privacy suite, making
  the package/evidence credential scan part of aggregate verification.
- Environment note: SwiftPM release building requires execution outside the
  managed nested macOS sandbox; one bounded reusable approval now covers the
  release-proof integration test instead of repeated Swift prompts.
- Claim boundary: the scanner recognizes bounded credential/private-key token
  signatures. It is not a general PII/PHI/content classifier and does not
  replace zero-egress tests, action-policy proof, or human privacy review.
- CAM-018 remains in progress because packaged GUI automation, full-vault
  recovery, final requirement mapping, broader accessibility proof, and the
  remaining product gates are still incomplete.

### Reproducible package build identity — 2026-07-28

- Red: the package identity test failed because the existing `Info.plist` had
  no `CAMBuildCommit` key.
- Green: package creation now derives `CAMBuildCommit` from exact repository
  `HEAD`, `CFBundleVersion` from the deterministic commit count, and
  `CAMBuildSourceDirty` from the current Git state.
- Green: the focused test rejected the old package and then passed with commit
  `650a90f9a3e1d804dfe127aac9b48b75107a1df7`, build `36`, and `dirty=true`,
  exactly matching the implementation worktree at test time.
- Green: the release-privacy integration now runs the identity assertion after
  package creation and passes before scanning the package/evidence set.
- Reproducibility boundary: no wall-clock timestamp or branch-dependent value
  is embedded. A clean-clone run remains the authoritative proof that a
  committed package reports `dirty=false`.
- CAM-018 remains in progress; this closes embedded build identity only, not
  the final requirement map, recovery, packaged GUI, accessibility, signing,
  notarization, or distribution gates.

### Machine-readable finish-goal gate map — 2026-07-28

- Red: the release-proof test failed because no goal-gate validator or
  machine-readable map existed; its aggregate-wiring assertion then failed
  until `verify.sh all` invoked the new suite.
- Green: `docs/evidence/goal-finish-wiki-gate-map.json` maps all `48`
  Proof-of-Done bullets by exact source line to a stable ID, verdict, existing
  repository evidence, and a limitation for every non-passed gate.
- Green: the validator proves the controlling goal SHA-256, one-to-one bullet
  coverage, unique ordered IDs/lines, repository-relative existing evidence,
  legal verdicts, non-passed limitations, summary counts, and overall-status
  consistency.
- Current honest verdict: `11 passed`, `26 partial`, `11 missing`, `0
  deferred`, overall `incomplete`.
- Green: the focused contract and named `goal-map` verifier pass, and
  `scripts/verify.sh all` now runs that validation before build and test work.
- Claim boundary: a passing map validator proves completeness and consistency
  of the audit map, not product completion. Only an all-`passed` map plus the
  remaining packaged/recovery/reality evidence may support the final claim.
- CAM-018 remains in progress.

### Unsigned package reproducibility — 2026-07-28

- Red: the focused test failed because no two-build reproducibility verifier
  existed; its aggregate-wiring assertion then failed until the named suite
  was added to `verify.sh all`.
- Green: two real release package builds at the same source/state produce an
  identical canonical manifest covering all `4` bundle entries, their entry
  types, permission modes, and file-content SHA-256 digests.
- Green: exact package commit/build/dirty identity is validated after each
  build; filesystem timestamps are excluded because they are not content or
  source identity.
- Green: the focused suite passes and aggregate verification now runs
  `package-reproducibility` before the final package/evidence credential scan.
- Goal-map effect: `release.reproducible-package` moves from `partial` to
  `passed`; the overall goal remains `incomplete` at `11 passed`, `26 partial`,
  and `11 missing`.
- Claim boundary: this proves deterministic unsigned bundle content on the
  reference environment at one source/state. Signing, notarization, and
  distribution remain unapproved and unperformed.

### Module authority and approval-churn consolidation — 2026-07-28

- Approval recorded: the evidence-first hybrid design for semantic repository
  observations is accepted. Deterministic clean-commit evidence remains
  authoritative; a selected loopback model may generate only validated,
  citation-bound candidates.
- Expected red: the focused module suite produced four failing tests and seven
  issues because enabled modules advertised capabilities with zero or partial
  declared permission grants.
- Green: `./scripts/verify.sh modules` passed all seven focused tests after the
  registry required every declared permission before advertising capabilities.
  Coverage includes zero grants, partial grants, full grants, restart, revoke,
  disable, reload, health isolation, invalid manifests, and duplicate IDs.
- Green: `./scripts/verify.sh all` passed the local `203`-test suite, release
  build, two-build package reproducibility, package identity, 41-file
  credential-signature scan with zero findings, offline smoke, and the
  non-recursive fresh-clone verification of the previously committed baseline.
- Verification automation: `scripts/verify.sh` now owns a named `modules`
  suite, and every repository-owned Swift test/build/run entry uses
  `--disable-sandbox`. Package and smoke helpers use the same SwiftPM policy.
  Future Codex checks should use this single already-approved entry point
  instead of issuing raw Swift command variants.
- Environment boundary: the repeated approval dialogs were caused by the
  managed Codex execution sandbox rejecting SwiftPM's nested `sandbox-exec`;
  they were not CAM Assistant product permission prompts. Signing,
  notarization, deployment, external accounts, secrets, sensitive egress, and
  destructive Mac actions remain deliberate approval boundaries.

### Frozen repository semantic evaluation — 2026-07-28

- Approved design and TDD plan:
  `docs/plans/2026-07-28-semantic-repository-intelligence-design.md` and
  `docs/plans/2026-07-28-semantic-repository-intelligence.md`.
- Frozen before implementation: four synthetic cases with exact
  commit/file/line/symbol evidence, required support and counterevidence,
  concept groups, and two explicit abstentions. Independent review then
  required a separately frozen v2 with four same-role distractors and
  misleading lexical matches. V2 manifest SHA-256:
  `5fe3b45ab5bbfdabd08eadf0871348a5830a5d4cd6c2213350be493293f64b25`.
- Expected REDs: the repository suite failed for the absent manifest,
  deterministic validator, evaluator/generator protocol, strict loopback
  generator, evidence-complete idea conversion, and CLI request parser before
  each implementation.
- Green: `./scripts/verify.sh repository-semantic` passes all `50` repository
  tests. The scripted frozen run reaches `1.0` observation recall, evidence
  precision, counterevidence recall, and abstention accuracy; a contaminated
  run fails with separate invalid and unanswered case receipts, and citing a
  same-role distractor lowers precision and fails the v2 gate.
- Green: `./scripts/verify.sh all` passes the local `221`-test suite, app/CLI
  release build, two-build package reproducibility, package identity,
  42-file credential-signature scan with zero findings, and offline smoke.
- Green: the strict loopback generator requires an explicit local assignment
  and selected-model health check, revalidates decoded endpoints and generator
  construction, bounds evidence/request/response bytes, sends no authorization
  header, requests a strict JSON schema, rejects unknown response keys,
  preserves explicit abstention and cancellation, and rejects identity drift
  and unknown evidence.
- Green: validated semantic candidates can form only ephemeral
  evidence-complete cards preserving exact support/counterevidence citations,
  confidence, license, rejected alternatives, rationale, and smallest
  experiment. Legacy retained cards remain decodable.
- Live truth: read-only checks of the previously evidenced loopback endpoints
  on ports `1234` and `11434` both refused connection. No real-model report
  was fabricated.
- Goal-map effect: `repositories.semantic-evaluation` moves from `missing` to
  `partial`; totals are now `11 passed`, `27 partial`, and `10 missing`.
- Saved receipt:
  `docs/evidence/task-15-repository-semantic-evaluation.md`.
- Claim boundary: no named real model has passed the frozen corpus, and no
  native selected-repository semantic journey exists. CAM-015 remains in
  progress.
- Independent-review adjudication:
  - Accepted and fixed: decoded-assignment loopback bypass, successful CLI
    status on a failed gate, caller-supplied license provenance, swallowed
    cancellation, non-discriminative v1 evidence selection, legacy-card
    migration coverage, permissive response decoding/unbounded responses, and
    unsorted case results.
  - Rejected: none.
  - Needs investigation: none for this synthetic-validator checkpoint. Broad
    repository quality and a named live-model result remain explicit future
    proof gates rather than claims from this slice.
- Exact-commit receipt: `./scripts/verify.sh fresh-clone` passed from a clean
  temporary clone of feature commit
  `e5770f04abf80781da7ce9527786b71b3d65e77a`: 221 tests, release app/CLI,
  reproducible package, package identity, 42-file zero-finding privacy scan,
  offline smoke, and the honest 48-gate map.

### Goal-map reality correction — 2026-07-28

- Read-only reality audit found that `modules.no-grant-on-enable` still
  described the pre-`86d08c8` registry even though current
  `ModuleRegistry.capabilities()` requires every manifest-declared permission.
- Reproduced: `./scripts/verify.sh modules` passed all seven tests covering
  zero/partial/full grants, enable, disable, revoke, restart, reload, isolated
  health failure, duplicate IDs, and invalid manifests.
- Corrected only that gate from `partial` to `passed`. The adjacent
  permission/health gate remains `partial` because receipts, expected-state
  revisions, real health execution, and native review are absent.
- Current map totals: `12 passed`, `26 partial`, `10 missing`, overall
  `incomplete`.
- Saved evidence:
  `docs/evidence/task-17-module-permission-enforcement.md`.

### Remaining-gate reality audit — 2026-07-28

- Rechecked repository idea quality, semantic evaluation, promotions, typed
  research results, native research review, and module permission/health
  against current public types and focused tests.
- No additional gate is fully proved. The map remains `12 passed`,
  `26 partial`, and `10 missing`.
- Tightened stale limitations: semantic cards now enforce the complete
  evidence/rejected-alternative/experiment shape, but manual cards do not;
  research packets separate facts and inferences but have no typed unanswered
  questions or recommendations.
- Read-only checks of loopback ports `1234` and `11434` again refused
  connection. No named-model receipt was fabricated and no cloud fallback was
  attempted.
- Saved evidence:
  `docs/evidence/goal-map-reality-audit-2026-07-28.md`.

### Full-vault backup, validation, and fresh-root recovery — 2026-07-29

- Approved and implemented the format-neutral local V1:
  `docs/plans/2026-07-29-full-vault-backup-design.md` and
  `docs/plans/2026-07-29-full-vault-backup.md`.
- Expected red: malformed recognized JSON was published in an otherwise
  integrity-valid package, and a schema-v8 SQLite database missing a required
  table passed its schema-number check.
- Green: `scripts/verify.sh backup` passes all `18` manifest, creation,
  validation, CLI, representative-state, and authority-safe restore tests.
  Validation now checks typed recognized stores, SQLite quick-check, contiguous
  migration history, required tables and columns, foreign keys, content
  identities, all manifest bytes, symlinks, safe paths, and unexpected
  payloads before destination creation.
- Green: `scripts/verify.sh app` passes all `13` app tests, including
  off-main recovery work, safe status/errors, concurrent-operation refusal,
  and controls with no overwrite or merge authority.
- The packaged native app created and validated
  `/private/tmp/cam-vault-recovery-proof.20260729/Representative-UI.camvault`:
  `7` entries, `158151` bytes, schema `8`, manifest SHA-256
  `ab7b533af8a41f3a7e0be8b156acb378e56e0beaac4d4f22573bdbdcaff75a08`.
- Native restore created a new previously absent root. Packaged relaunch
  showed `3` active Library sources, `1` cited local-read task, `1` kept
  research plan, the saved repository path, its completed job, and its kept
  commit-cited idea. One retained knowledge claim was present on disk.
- Exact source/restored immutable-object identities matched for all three
  objects. Retained research, knowledge, and repository-selection JSON was
  byte-identical; retrieval generations and job leases were absent.
- The packaged journey exposed a separate repository evidence defect:
  snapshots counted only non-empty lines while observations cited physical
  lines. A TODO at `README.md:5` therefore rejected itself against a receipt
  claiming three lines. A red regression test reproduced the error; physical
  line counting now preserves internal blank lines, and all `51` repository
  tests pass.
- Goal-map effect: `wiki.full-vault-backup` moves from `missing` to `passed`.
  Current totals are `13 passed`, `27 partial`, and `8 missing`, overall
  `incomplete`.
- Green: the aggregate verifier passes portability, the 48-gate map, all
  `244` Swift tests, release app/CLI builds, two-build package
  reproducibility, package identity, a `50`-file zero-finding
  credential-signature scan, and offline smoke with fresh-clone recursion
  intentionally skipped for the in-tree aggregate.
- Green: `/bin/zsh scripts/verify.sh fresh-clone` passed from a clean temporary
  non-local clone of exact feature checkpoint
  `988015954e42483f3f08c6796f08054fee746ebe`: portability, the honest 48-gate
  map, all `244` Swift tests, release app/CLI builds, two-build package
  reproducibility, exact package identity with `dirty=false`, a `50`-file
  zero-finding credential-signature scan, and offline smoke all pass.
- Saved evidence:
  `docs/evidence/task-18-full-vault-backup-restore.md`.
- Boundary: the V1 does not overwrite, merge, upload, schedule, encrypt, or
  silently switch the running vault. Password encryption remains an optional
  future wrapper. No normal personal application-support vault was used.

### Repository semantic empty-enum repair and live rerun — 2026-07-29

- Expected red: the required-abstention transport regression exposed an empty
  JSON Schema `enum`, reproducing the LM Studio pre-inference rejection.
- Green: empty allowed-ID sets now omit only the `enum` keyword; non-empty sets
  remain exact enums, and decoded IDs still fail closed against the complete
  evidence set. All `51` repository tests pass.
- The frozen semantic-v2 manifest remained byte-identical at
  `5fe3b45ab5bbfdabd08eadf0871348a5830a5d4cd6c2213350be493293f64b25`.
- A real loopback Gemma 12B rerun preserved exit `2` and the failed overall
  verdict. Abstention accuracy improved from `0.0` to `1.0`; both observation
  cases remain failed with `missing_required_concept`, so observation recall,
  evidence precision, and counterevidence recall remain `0.0`.
- Saved failed receipt:
  `docs/evidence/task-15-repository-semantic-gemma-schema-fix-rerun-failed.json`,
  SHA-256
  `cb4d0cb5350b9ec6bec9bc6bad794265af2e79c564e8370ba8e6a7b410781095`.
- The model was unloaded and the loopback server stopped. No personal data,
  donor source, cloud, web, CAM, authorization header, or network bind was
  used.
- Aggregate verification passes the honest 48-gate map, all `244` Swift tests,
  release app/CLI builds, reproducible packaging, package identity, a
  `51`-file zero-finding credential-signature scan, and offline smoke with
  recursive fresh-clone verification intentionally deferred until commit.
- CAM-015 remains in progress. A separately pre-registered semantic-support
  contract and native clean-repository journey remain required; immutable v2
  is not tuned after model observation.

### Repository semantic V3 and native clean-commit path — 2026-07-29

- V1 and V2 remain unchanged. The separately designed and frozen V3 manifest
  uses closed claim IDs, same-topic distractors, exact evidence roles, and
  hidden required labels instead of lexical phrase matching. Frozen SHA-256:
  `222b3c705f4fd32a68039a6bad45c49663fae10d228446b4b9090a3323a0debe`.
- Expected REDs were observed for the absent V3 manifest/validator/evaluator,
  strict loopback generator/CLI, runtime bundle builder, health-checked runtime
  analyzer, evidence-complete V3 card conversion, AppModel state machine, and
  native accessibility controls.
- A named unchanged Gemma 12B V3 run exited `2` and remains failed: claim
  recall `0.5`, claim precision `1.0`, support precision `1.0`,
  counterevidence recall `0.5`, and abstention accuracy `1.0`. The immutable
  report SHA-256 is
  `dc1407b6fe58dedaeccbc67961bf82072f3ac7bf087ea1c42b376693691b5340`.
  No V3 label, role, distractor, claim, or threshold changed after observation.
- The runtime path now revalidates canonical path, clean state, and current
  commit; reads exact physical-line excerpts only from commit-addressed Git
  bytes; and deterministically selects at most eight representative items with
  support and counterevidence. Dirty state, drift, insufficient evidence,
  excerpt bounds, and cancellation fail before model generation.
- The analyzer health-checks the exact selected loopback model, requires
  generator/candidate identity agreement, and deterministically accepts or
  abstains. It has no provider, web, CAM, repository mutation, code-copy, or
  fallback route.
- Native Repositories controls expose progress/cancellation, exact
  model/runtime/commit identity, claims, confidence, support,
  counterevidence, and an evidence-complete proposal form. Accepted output is
  memory-only until a separate explicit Keep, Reject, task, research, or
  Codex-plan action.
- Green focused proof: `64` repository tests, `16` AppModel/accessibility
  tests, all model suites, and all privacy suites pass.
- Green aggregate proof: repository portability and the honest 48-gate map,
  all `260` Swift tests, release app/CLI builds, two-build package
  reproducibility, package identity, a `53`-file zero-finding
  credential-signature scan, and offline smoke pass.
- Green portable proof: `/bin/zsh scripts/verify.sh fresh-clone` passed from a
  clean temporary non-local clone of implementation checkpoint
  `4193820165d12d057f512bce17350bf02f4b6dd6`: all `260` tests, release
  app/CLI, reproducible package, exact package identity with `dirty=false`,
  the `53`-file zero-finding scan, and offline smoke pass.
- The adversarial review found and fixed large-repository rejection,
  cancellation granularity, inaccurate insufficient-evidence attribution, and
  misleading retention wording. Saved review: `REVIEW.md`.
- Saved evidence:
  `docs/evidence/task-15-repository-semantic-evaluation.md`,
  `docs/evidence/task-15-native-repository-semantic-journey.md`, and
  `docs/evidence/task-15-repository-semantic-v3-gemma-failed-report.json`.
- CAM-015 remains in progress. No named model passes V3, and no packaged
  live-model clean-repository journey has been claimed.

### Policy-gated research acquisition V1 — 2026-07-29

- Approved direct-document boundary implemented: canonical public HTTPS only,
  same-origin redirects, fixed document MIME types, streamed 5 MiB maximum,
  credential/cookie/cache-free GET, fixed tool and route, and USD 0 maximum
  and actual provider cost.
- Schema v9 stores durable typed acquisition jobs with exact request,
  consumed approval, status-only failure, attempt/state version, cancellation,
  restart interruption, safe resume, receipt, and late-completion refusal.
- Research capture enters the immutable vault and processes only its exact
  ingest job. Repeated bytes preserve a new attempt receipt while resolving to
  one stable content identity.
- Acquired content remains inert untrusted data. Every protected privacy
  fixture blocks before transport and persistence; prompt-like content can
  create only a visible review signal.
- Research packets now expose source receipts plus typed facts, inferences,
  contradictions, unanswered questions, recommendations, and limitations.
  Acquisition creates no fabricated finding and stays ephemeral until Keep.
- Native Research exposes the exact target/limits/route/tool, progress,
  cancellation, safe resume, status-only failures, source quality and safety
  signals, typed packet review, Keep, and Discard. A completed durable receipt
  can reopen an ephemeral review packet after restart without automatic
  retention.
- Fixed a real cancellation propagation defect: cancelling the AppModel task
  now cancels its detached transport worker, rejects late results, waits for
  durable cancellation, and only then returns to idle.
- Green focused proof: research `27`, app `22`, privacy `8` plus audit `3`,
  ingest `27`, storage `8`, and full-vault backup `18` tests pass.
- One exact-approved live CLI run acquired
  `https://www.rfc-editor.org/rfc/rfc9110.txt` into a disposable vault:
  `502941` bytes, SHA-256
  `21c1cdce6ab0e5509b04d84a28000836c7a087cf786efe6f04877ebfff47232a`,
  completed job and ingest, USD `0`, unreviewed/unknown source quality, a
  conservative PII review signal, and an ephemeral packet. SQLite
  `quick_check` and immutable-object identity passed; response text was not
  saved in evidence.
- The packaged app reopened the completed job without a second request,
  reconstructed its ephemeral review packet, displayed the typed receipt and
  review signal, explicitly kept it, discarded only the ephemeral
  presentation, and reopened the kept packet after restart.
- Goal-map effect: `research.acquisition`, `research.native-review`, and
  `research.untrusted-output` move to `passed`; `research.typed-results` stays
  `partial`. Totals are now `16 passed`, `26 partial`, and `6 missing`,
  overall `incomplete`.
- Green aggregate proof after adversarial hardening: repository portability
  and the honest 48-gate map, all `287` Swift tests, app/CLI release builds,
  two-build package
  reproducibility, package identity, a `54`-file zero-finding
  credential-signature scan, and offline smoke pass.
- Green exact-commit proof: `/bin/zsh scripts/verify.sh fresh-clone` passed
  from a clean temporary non-local clone of implementation checkpoint
  `8d2dc163f3a516598967f9700406cd58b9d2c098`: all `287` tests, release
  app/CLI, reproducible package
  (`29f454a176ab2fdd38d1e02bdb6e70ccee73fea47d109fce55c9eba11c1cbc9f`),
  exact package identity with `dirty=false`, the `54`-file zero-finding scan,
  and offline smoke pass.

### Durable historical CAM runtime state — 2026-07-29

- Added a schema-versioned atomic `cam-runtime-history.json` store for the
  latest derived schema-v2 runtime pin and its latest bound terminal
  `cam.stats.snapshot.v1` receipt.
- Decode revalidates the pin's complete identity material and refuses corrupt
  state, unsupported schema, receipt-to-pin drift, invalid digests, and a
  malformed terminal shape. A replacement pin atomically clears the prior
  receipt.
- The native CAM view restores saved paths, identity, and a verified receipt
  as visibly historical evidence. Another probe remains disabled until a fresh
  current-session re-pin succeeds; persistence failure cannot be displayed as
  durable verified success.
- The machine-specific file contains no configuration bytes, secret value,
  approval, tool authority, mining plan, or corpus content. It intentionally
  remains outside the portable full-vault manifest and is re-derived after
  restore or machine/runtime drift.
- Expected red/green proof: the missing store first failed compilation; the
  native source contract then failed until historical restoration and the
  current-session gate were implemented; a forged verified receipt with
  failure state and no statistics was observed failing before validation was
  hardened.
- Focused green proof: `30` CAM tests (`25` runtime/probe plus `5` restart
  state), all `24` app tests, and all `18` backup tests pass.
- Exact final-worktree aggregate green: portability and the honest 48-gate
  validator pass; all `312` Swift tests pass; native app and CLI release builds
  pass; deterministic package manifest is
  `9ae5537913528eae2e4e9a3f9bc1744ad6344f0ad32a3db18710bc1e2d8d1542`;
  the `56`-file credential-signature scan has zero findings; and the current
  debug binary reports offline capture/search available with automatic cloud
  routing disabled.
- Green exact-commit proof: `/bin/zsh scripts/verify.sh fresh-clone` passed
  from a clean temporary non-local clone of pushed implementation checkpoint
  `0528cb8aca357504d2292fbf4bf876878c20c76a`: all `312` tests, release
  app/CLI builds, reproducible package
  (`e2707e1c1f948551004a8a949011dce89e12a629a04520b1e1568fd93f0c1830`),
  exact package identity with `dirty=false`, the `56`-file zero-finding scan,
  and offline smoke pass.

### Packaged CAM restart and picker accessibility — 2026-07-29

- The first packaged runtime attempt exposed a real accessibility red: the
  visible `Select CAM Executable…` button was absent from the native
  accessibility tree while Configuration and Database were present.
- Root cause was SwiftUI collapsing the first action-bearing
  `LabeledContent` into the following row because the reusable selection row
  had no contained, named accessibility boundary.
- Added an expected-failing source contract, then made every runtime selection
  row a contained accessibility element labeled `<Surface> runtime selection`.
  The rebuilt package exposes separate Executable, Configuration, and Database
  containers and all three picker buttons.
- Against isolated application-support root
  `/private/tmp/cam-runtime-gui-proof.FQO9Vl`, the packaged app selected the
  installed CAM launcher, config, and corpus, derived runtime identity
  `557d14e9fd5b9e276a2b4d58920bd0a39e2efb220b71743f04bae19f6c2cb45a`,
  and explicitly stated that no CAM process started.
- The packaged disposable probe returned `2,516` methodologies, `197`
  repositories, tool `cam.stats.snapshot.v1`, and `workspaceRetained=false`.
  Its persisted receipt proves all seven donor surfaces unchanged.
- After quit and relaunch against the same isolated root, the packaged native
  tree showed `Historical pinned identity`, `Historical receipt`, the exact
  prior statistics, and a disabled `Run Disposable Statistics Probe`. A fresh
  `Pin Selected Runtime` changed the heading to current `Pinned identity` and
  re-enabled the probe.
- Focused green proof: all `25` app tests pass. No CAM subprocess, mining,
  provider, MCP, or personal-corpus mutation was authorized.
- Aggregate green proof: portability and the honest 48-gate validator pass;
  all `313` Swift tests pass; native app and CLI release builds pass;
  deterministic package manifest is
  `628822441262b3bfc75d03629464e3049d534c002aa6d154474b06eadf6b69a0`;
  and the `56`-file credential-signature scan has zero findings.
- Clean exact-commit package proof: implementation commit
  `3ed8704e67a24e08aab5300d5cd1eedf1b68436d`, bundle build `75`, and embedded
  `dirty=false` repeated the native re-pin/probe/quit/relaunch journey. The
  restarted app restored the exact historical `2,516`/`197` receipt and kept
  the probe disabled until re-pin.
- Green exact-commit proof: `/bin/zsh scripts/verify.sh fresh-clone` passed from
  a clean temporary non-local clone of `3ed8704e67a24e08aab5300d5cd1eedf1b68436d`
  with all `313` tests, release builds, reproducible package
  `8287301b9725b3b136953827e51fab3285cba4240ace5ab9e97bf089fe34eaa9`,
  exact package identity with `dirty=false`, the `56`-file zero-finding scan,
  and offline smoke.
- Saved evidence:
  `docs/evidence/task-16-cam-runtime-restart-state.md`.
- Boundary: no live CAM process, capability discovery, mining, exact approval,
  retry executor, or live-run recovery is claimed. CAM-016 remains in progress
  and the 48-gate map remains honestly incomplete.
- Saved evidence: `docs/evidence/task-14-research-acquisition.md`.
- Boundary: V1 does not provide provider search, arbitrary HTML/browser
  acquisition, model-generated findings, paid APIs, cloud models, link
  following, or automatic knowledge promotion.
- Adversarial review adjudication:
  - Accepted: pin production TLS to validated addresses; revalidate redirects;
    refuse transition/private address forms; make native cancellation
    lifecycle-atomic; distinguish production transport/DNS/ingestion failures;
    classify recursively decoded targets; show full digest, timing, and binary
    inspection state; and correct resume design truth.
  - Rejected: none.
  - Needs investigation: none for the V1 checkpoint. A future in-process
    Network.framework transport may replace the fail-closed macOS system-curl
    adapter if it preserves SNI/TLS validation, address pinning, redirect
    control, and the streaming byte cap.
- Hardened live receipt: the pinned adapter acquired the same RFC in one
  exact-approved disposable run as job
  `1628f604-c1ce-4cc3-9ec0-da37111da780`, preserving the exact prior
  `502941` byte count and SHA-256 while identifying tool
  `pinned-curl-public-document-v1`.

### Native CAM runtime pin and disposable snapshot verifier — 2026-07-29

- Expected reds added for derived behind-launcher identity, package drift,
  inline secrets, committed WAL state, external-write/nonterminating/output
  launcher behavior, cleanup, and CLI receipts.
- Independent review rejected the first copied-state subprocess design because
  it did not enforce hard process/output confinement, trusted caller metadata,
  copied only the SQLite main file, and lacked complete postconditions and
  failure receipts. That proof was discarded rather than relabeled.
- The replacement schema-v2 pin derives the interpreter, installed
  distribution/version/entry point, editable package root, source Git commit,
  installation loader/metadata, sqlite extension, secret-free config, and
  stable main/WAL database-family identity.
- `cam.stats.snapshot.v1` never launches CAM. It reads fixed statistics from a
  stable disposable SQLite family, emits typed success/failure state, checks
  every donor surface, and automatically removes config/database copies.
- Independent re-review then found cancellation, timeout, scan-bounding, and
  read-write-copy defects. The accepted remediation adds a terminal
  cancellation check, monotonic phase deadlines plus a SQLite progress
  handler, per-chunk/entry deadlines and surface size/file-count ceilings,
  streaming row/byte/source ceilings, a read-only/query-only SQLite connection,
  immutable handling for closed WAL-mode databases, a required unchanged
  disposable-family digest, and explicit cleanup truth in receipts.
- Native CAM controls expose file selection, derived pin, probe progress,
  cancellable/time-bounded initial hashing, cancellable probe progress, full
  identities, typed counts, and the explicit
  no-mining/no-provider/no-MCP/no-personal-mutation boundary. The CLI supports
  bounded pinning and probe receipts.
- Real proof derived runtime identity
  `557d14e9fd5b9e276a2b4d58920bd0a39e2efb220b71743f04bae19f6c2cb45a`
  and returned `2,516` methodologies and `197` source repositories. Seven
  donor surfaces matched before/after, stderr was zero bytes, and the
  disposable workspace was removed.
- Focused green proof: all `25` CAM and `24` app tests pass, including initial
  pin timeout/cancellation,
  deterministic cancellation, in-hash deadline, scan-ceiling, disposable
  mutation, cleanup failure, closed-WAL, active-writer WAL+SHM, and stale
  native completion rejection cases.
- Backup decision: no duplicate product-managed CAM-corpus backup is required
  for this verifier. Isolation, stable snapshots, donor drift proof, and
  cleanup protect the read-only operation; full-vault backup covers app-owned
  durable truth, while Time Machine/APFS/encrypted external backup may protect
  the external corpus at host level.
- Saved evidence:
  `docs/evidence/task-16-native-cam-runtime-snapshot.md`.
- Boundary: no CAM process, mining, exact approval, provider, MCP server,
  durable runtime run, coordination executor, or personal-corpus mutation is
  claimed. CAM-016 remains in progress.
- Goal-map effect: `cam.disposable-integration` moves from `missing` to
  `partial`; totals are now `16 passed`, `27 partial`, and `5 missing`,
  overall incomplete.
- Exact final-worktree aggregate green: portability and the 48-gate validator
  pass; all `307` Swift tests pass; native app and CLI release builds pass;
  two-build package reproducibility passes with canonical manifest
  `b0cf81e4293c43ee3d53d4394ddefd9fe71eae389c137c03be2212c65bbf09b9`;
  the 55-file credential-signature scan has zero findings; and direct current
  debug-binary offline smoke reports capture/search available with no automatic
  cloud route.
- Green exact-commit proof: `/bin/zsh scripts/verify.sh fresh-clone` passed
  from a clean temporary non-local clone of pushed implementation checkpoint
  `ef2a7bf8e03d2de4b58317bb83885483fa42396f`: all `307` tests, release
  app/CLI builds, reproducible package
  (`eecd0db30b046519a1ba12bf9643d4186cac611ef5aa33f3671462b3932db596`),
  exact package identity with `dirty=false`, the `55`-file zero-finding scan,
  and offline smoke pass.

## Blockers

None.

## Questions for User

1. Choose whether generated-answer v2 should retain full generation below
   `500 ms`, or split the gate into retrieval/context below `500 ms` and a
   separately measured human-usable generation target.

This decision does not block independent local proof work. No overall project
blocker is asserted.
