# CAM Assistant Task Queue

## Active Barebones Queue

| ID | Task | Status | Acceptance |
|---|---|---|---|
| BARE-001 | Controlling user-first contract | Complete | `GOAL_BAREBONES.md` and repository verifier pass |
| BARE-002 | Three-place primary shell | Complete | Fresh production profile exposes only Home, Library, Settings |
| BARE-003 | Friendly Home capture | Complete | One obvious Save and Ask path with ordinary-language status |
| BARE-004 | Recognizable searchable Library | Complete | Titles, dates, previews, search, citation navigation, Details |
| BARE-005 | One local Ask path | Complete | Local-model cited answer or visible model-free matches; no fallback |
| BARE-006 | Reversible cited Keep | Complete | Keep/Discard/duplicate/update/Undo/restart proof |
| BARE-007 | Friendly layered Settings | Complete | Capture, Local AI, Backup & Restore, Advanced |
| BARE-008 | Packaged and human proof | **Complete** (machine + G7 waived) | Packaged journey pass; Gate 7 waived 2026-08-09 |

## Phase 2 Direction Queue (Pattern A N3) — shipped

Controlling: `GOAL_DIRECTION.md`. Plan:
`docs/plans/2026-08-09-pattern-a-direction-implementation.md`.
**Status: implemented; D6 waived 2026-08-09.**

| ID | Task | Status | Acceptance |
|---|---|---|---|
| DIR-000 | Goal + plan review | Complete | Human approved 2026-08-09; build authorized |
| DIR-001 | Direction profile store (people, promises, north star) | Complete | Store + DirectionProfileStoreTests pass |
| DIR-002 | Home Direction strip + empty invites | Complete | DirectionStripView on Home; presentation tests |
| DIR-003 | Add/edit person and promise sheets | Complete | Sheets + AppModel mutators |
| DIR-004 | Backup/restore includes Direction profile | Complete | Full-vault Direction test + packaged restore |
| DIR-005 | Talk offline coach (no model) | Complete | Coordinator offline + AppModel wiring |
| DIR-006 | Talk cite-or-admit (local model) | Complete | Coordinator library grounded / admit tests |
| DIR-007 | Packaged non-regression + Direction proof | Complete | `scripts/verify.sh barebones-packaged` status=pass |
| DIR-008 | Human Direction gate | **Waived** | D6 waived — `docs/evidence/HUMAN_GATE_WAIVER_2026-08-09.md` |
| UX-B1 | Promise done / remove person Manage | Complete | Strip Done + Manage sheet + confirms |
| UX-B2 | Confirm remove watched folder | Complete | confirmationDialog before remove |
| UX-B3 | Guided hotkey editor | Complete | Preview, normalize, conflict, tips |
| UX-B4 | Plainer local model labels | Complete | LocalModelDisplayName + full id caption |
| UX-B5 | Human pilots G7 + D6 | **Waived** | Owner explicit waiver 2026-08-09 |
| OPT-01 | Live local-model Ask/Talk env proof | Complete (honest) | Probe none_ready this host; offline paths re-proven; re-run script when server up |
| OPT-02 | Landing page GitHub Pages | Complete | `.github/workflows/pages.yml` deploys `docs/landing` |
| OPT-03 | Product GIF refresh | Complete | Escape/Done frame + landing honesty labels |

## Parked Historical and Specialist Queue

The entries below preserve implementation and evidence history. They are not
the active product sequence while `GOAL_BAREBONES.md` controls the reset.

| ID | Task | Status | Acceptance |
|---|---|---|---|
| CAM-001 | Canonical repo and Swift package | Complete | Build/test/diff pass |
| CAM-002 | Native shell and health | Complete | Offline launch smoke |
| CAM-003 | Stable storage and audit | Complete | Restart/backup/redaction tests |
| CAM-004 | Module registry | Complete | Manifest and live enable tests |
| CAM-005 | Capture and ingestion | Complete | Idempotent mixed-fixture ingest |
| CAM-006 | Retrieval | Complete | Frozen v2 synthetic quality/latency, exact-quote availability, index-generation, and receipt gates |
| CAM-007 | Model routing | Complete | Marker/profile/catalog/CLI/settings tests; local-only and proof-gated outbound |
| CAM-008 | Privacy and action cards | Complete | Frozen classifier, zero-byte restricted blocks, exact approval, and status-only audit tests |
| CAM-009 | CAM adapter | Complete | Fixture conformance, non-executing proposals, unavailable-state UI, and release verification |
| CAM-010 | Research and knowledge | Complete | Local checkpoint/resume, explicit plan-only Keep persistence, repository-cited plan promotion, citation-bound facts, separate inferences, contradiction candidates, and native status |
| CAM-011 | Mac Care and repos | Complete | Read-only repository intake, commit-cited marker observations, retained Keep/Reject idea cards, cited local task promotion, and digest-bound Mac assessment plans with unavailable executors |
| CAM-012 | UX and packaging | In progress | Packaged hotkey, watched-source, accessible ingest cancel/restart/resume, selected-model, full-vault fresh-root recovery, keyboard/focus/empty-state and motion-free slices, package/smoke, fresh-clone, and UX/release gap audit pass; a repeatable repository-owned packaged GUI suite, complete VoiceOver/visual accessibility, and final aggregate proof remain |
| CAM-013 | Daily-use wiki and local-model chat | In progress | Library/recovery, integrity-checked full-vault backup/restore, persistent retrieval, typed loopback synthesis, frozen v1 evaluation, generated-v2 split latency contract frozen (retrieval &lt;50 ms / generation &lt;2500 ms), failed-report nonzero CLI status, and the packaged selected-model journey pass; live named-model v2 receipts and CAM-013 overall product gate remain open until user-selected models are run |
| CAM-014 | Policy-gated research acquisition | Complete | Exact-approved direct public-document transport, zero-egress privacy gate, durable cancellation/recovery, targeted ingest/deduplication, complete zero-cost/source-quality receipts, live disposable proof, and packaged native ephemeral review/Keep/Discard/restart pass |
| CAM-015 | Persistent repository intelligence | In progress | Restart-safe jobs, non-destructive removal, frozen V1/V2/V3 evaluation, strict loopback generation, citation-free abstention, bounded clean-commit runtime evidence, native accepted/abstained/failed/cancelled review, and explicit evidence-complete retention controls pass; named model failures are preserved, while a named V3-passing model, packaged live-model journey, broader intake, and live typed coordination remain |
| CAM-016 | Live bounded CAM/Codex | In progress | Native/CLI selection derives and drift-checks the launcher, interpreter, installed package/source commit, metadata, sqlite dependency, secret-free config, and WAL-consistent corpus family under cancellable deadlines. A typed native snapshot verifier and an explicitly cancellable closed sandboxed `stats --json` process executor run only on disposable copies; the installed runtime proof returned 2,557 methodologies/199 repositories, donor surfaces unchanged, cleanup, retry/idempotency, durable replay, a status-only interrupted-run journal that fails closed without relaunch, and native restart-visible interruption status. A separate in-process structured synthetic corpus executor now writes pre-mutation checkpoints, validates bounded write sets, saves status-only receipts, and discards only its private copy on success/cancellation/failure; it never opens CAM. Atomic restart state preserves only a revalidated pin and bound terminal receipt as historical, non-authoritative evidence. Real exact-approved mining, real mutation checkpoint/rollback, trajectory proof, and complete coordination remain |
| CAM-017 | Safe Mac actions and module lifecycle | In progress | The trusted packaged `cam.text-summary` module now has an isolated native install/enable/grant/exercise/disable/remove/relaunch proof; app-owned organization mutation is gated closed with copyable manual user guides; item-level duplicate/organization evidence, complete reversible Mac actions with undo/receipts, module health execution, and permission-change receipts remain |
| CAM-018 | Final portability and release evidence | In progress | Fresh-clone verifier, packaged keyboard/focus/AX and full-vault recovery journeys, UX/release gap audit, deterministic two-build package proof, credential-signature gate, and a validated 48-bullet machine-readable goal map pass; automated packaged journeys, broader VoiceOver/visual accessibility, resolution of 32 non-passed map gates, final reality audit, and release report remain |
| ADD2CAM-001 | MeaningCore dependency and provenance | Complete | Exact library pin, focused import contract, clean CAM release build, independent MeaningCore aggregate proof, and an owner-scoped CAM use/package/distribution grant for the GOAL_ADD2CAM pilot are recorded. |
| ADD2CAM-002 | Opt-in module and default-effect boundary | Complete | Manifest discovery grants nothing; enablement grants nothing; exact read/write permission drift fails closed; disabled navigation and source access remain absent; typed health failure affects only Meaning Preview. |
| ADD2CAM-003 | Explicit CAM context adapter | Complete | Bounded deterministic mapping, typed commitments, fail-closed exclusions and identifier ownership, current explicit-selection isolation, provenance, and coordinator invocation-boundary tests pass. |
| ADD2CAM-004 | Isolated Meaning Preview store | Implemented; gate partial | Separate SQLite URL, unchanged primary bytes, restart reload, secret-fixture exclusion, backward-compatible revisions, atomic mutation rollback, typed corruption/incompatibility, authorized archive/reinitialize, disable lifecycle, and durable feedback/audit pass. Gate 3 remains partial only for full packaged backup/recovery-boundary proof. |
| ADD2CAM-010 | Deterministic practical coordinator | Complete | Fourteen focused tests prove permission-first lazy access, silence/one item, exact depleted-capacity deadline behavior, typed lifecycle, correction/rejection/expiry/restart, stale/failed-write refusal, actor serialization, explicit-selection isolation, and deterministic replay. |
| ADD2CAM-020 | Native opt-in Meaning Preview UX | Complete | Fifty-nine app tests plus independent spec and quality review prove disabled absence, separate exact grant, recognizable explicit source selection, zero/one card, Inspect including silence/exclusions, typed actions/feedback, accessible motion-free controls, corruption/incompatibility recovery, in-flight Disable, and ordinary-Assistant restoration. |
| ADD2CAM-021 | Feedback, correction, audit, and proposals | Complete | Exact-card one-shot helpfulness, classifier-bounded correction, retirement propagation, serialized status-only audit, proposal-only external possibilities, and privacy regressions pass. Restart intentionally requires a fresh explicit preview request. |
| ADD2CAM-030 | Frozen reflective evaluation | Complete | Frozen 22-case offline corpus, neutral label-free supplier input, strict schema/grounding/prohibited-behavior gates, replay-vs-model eligibility, exact digest, CLI, and repository verifier pass. |
| ADD2CAM-040 | Explicit loopback reflective lane | Complete; verified partial | Sixteen reflection tests, 36 AppModel tests, canonical report-byte and selected-assignment admission, loopback-only no-ambient-authority transport, runtime grounding, revocation suppression, and no persistence/fallback pass. No selected named model was available, so reflection remains disabled while practical Preview remains eligible. |
| ADD2CAM-050 | Packaged pilot readiness | Complete | Integrated from `agent/add2cam-50-packaged-pilot` (`d1a6ed7`); disposable packaged Enable→Grant→use journey green; meaning-preview verify pass; containment report and draft human protocol recorded. Integrator may still re-run aggregate/fresh-clone on the merge tip. |
| ADD2CAM-060 | Human evidence | Pending human | Approved protocol, consented participants, authentic lived-use evidence, limitations-first verdict, and promotion decision; agents cannot satisfy this gate. |
