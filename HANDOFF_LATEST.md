# CAM Assistant Continuation Handoff

**Generated:** 2026-08-09T19:10:17-04:00

**Repository:** `https://github.com/deesatzed/CAM_Assistant.git`

**Branch / revision:** `main@083b6b93c4323c9790ac0a52b4fba1352e75d85f`

**Last commit:** `083b6b9 docs: normalize test kit design formatting`

**Working tree at handoff start:** clean and synchronized with `origin/main`

**Current product state:** machine-verified and clone-ready; novice second-Mac testing has not yet been performed

## Quick Resume Checklist

1. Clone or update the canonical repository:

   ```bash
   git clone https://github.com/deesatzed/CAM_Assistant.git
   cd CAM_Assistant
   git status --short --branch
   git rev-parse HEAD
   ```

2. Confirm the checkout is `main` and the revision is at least `083b6b9`.
3. Read, in order: `AGENTS.md`, `GOAL.md`, `STANDARDS.md`, `IMPLEMENT.md`,
   `DECISIONS.md`, `PROGRESS.md`, and `TASK_QUEUE.md`.
4. For the owner's different-Mac test, begin at
   `docs/pilots/NOVICE_TEST_START_HERE.md` and follow the linked checklist.
5. For a developer verification pass, run:

   ```bash
   swift test --disable-sandbox --scratch-path .handoff-verify
   /bin/zsh scripts/verify.sh barebones-packaged
   /bin/zsh scripts/verify.sh portability
   ```

6. Do not reopen the parked Finish Wiki, ADD2CAM, CAM mining, signing, or
   notarization work unless a new approved goal explicitly does so.

## AI Continuity Checklist

- [ ] Review this `HANDOFF_LATEST.md` copy before acting.
- [ ] Import the open assumptions listed under configuration and boundaries.
- [ ] Import the priority debt items; do not silently discard them.
- [ ] Import the stale-cache error reference before diagnosing build failures.
- [ ] Execute the verification suite appropriate to the next change.
- [ ] Keep next actions prioritized P1 before P2.
- [ ] Confirm the exact repository path and `main` branch before editing.
- [ ] Confirm `git status --short --branch`; preserve unrelated user changes.
- [ ] Read all source-of-truth files in the prescribed order.
- [ ] Treat `GOAL.md`, `GOAL_BAREBONES.md`, and `GOAL_DIRECTION.md` as the
  active Pattern A contract.
- [ ] Treat the lower specialist queue as historical/parked, not as authority to
  expand ordinary navigation.
- [ ] Keep Home, Library, and Settings as the only primary places.
- [ ] Preserve local-first behavior: capture, Find, Library, Keep, and backup
  must remain useful without a model server.
- [ ] Preserve ephemeral answers until the user explicitly chooses Keep.
- [ ] Preserve cite-or-admit behavior; never fabricate support for a claim.
- [ ] Never treat synthetic or packaged proof as a human usability result.
- [ ] Never put API keys in source, Markdown, shell history, logs, fixtures, or
  environment files. OpenRouter keys are Keychain-only.
- [ ] Use a fresh SwiftPM scratch path if an inherited build cache reports
  permissions, read-only database, or stale output-map errors.
- [ ] Add focused tests before changing behavior, then run proportional
  regression and packaged proof.
- [ ] Update `PROGRESS.md`, `DECISIONS.md` when needed, and the queue when a task
  genuinely changes state.
- [ ] Run `git diff --check` before committing.

## What This Project Does

CAM Assistant is a native, local-first macOS private-memory application. Its
ordinary product has three places:

- **Home:** Direction strip, Save Clipboard, Find/Ask, citations, Keep/Discard.
- **Library:** browse and search captured material, inspect sources, and manage
  kept answers.
- **Settings:** watched folders, optional Local AI, backup/restore, and an
  explicitly disclosed Advanced area.

The core loop is: capture once, find with sources, and keep only the answer that
matters. Direction adds private people, promises, a north star, and optional
Talk without becoming a fourth destination or companion-bot product.

Ordinary capture, exact Find, Library, Keep, and backup operate without a cloud
account or model. LM Studio or Ollama can optionally provide a local
OpenAI-compatible endpoint for generated Ask/Talk answers.

**Tech Stack:** Swift 6, SwiftUI, SwiftPM, SQLite 3, optional local model server

**Architecture Pattern:** standalone native macOS application with shared core
library and companion CLI; local persistence and explicit service boundaries

## Technology Stack

| Area | Current choice |
|---|---|
| Platform | macOS 15+; Apple Silicon recommended |
| Language/UI | Swift 6 tools; SwiftUI |
| Build | Swift Package Manager; standalone repository |
| Storage | Local files plus SQLite 3 under Application Support |
| Retrieval | Local indexing/retrieval with Library citations |
| Optional inference | LM Studio or Ollama through a local OpenAI-compatible endpoint |
| Optional specialist dependency | MeaningCore pinned to revision `23db68044ebdc410edf3b7f436e433ffba6e94b8` |
| CI | GitHub Actions on `macos-15` |
| Documentation site | Static GitHub Pages content in `docs/landing/` |
| License | MIT; see `THIRD_PARTY_NOTICES.md` for attributions |

Package products are:

- `CAMAssistantCore` library;
- `CAMAssistant` SwiftUI app executable; and
- `cam-assistant` command-line executable.

## Architecture and Data Flow

```text
Clipboard / watched folder
          |
          v
Capture + ingest --> local content/SQLite vault --> retrieval/index
                                                   |          |
                                                   v          v
                                                Library   Find / Ask
                                                              |
                                         citations + ephemeral answer
                                                              |
                                                explicit Keep / Discard

Direction profile JSON --> Home Direction strip --> optional Talk
                                                   |
                                      local citations or explicit admission

Full-vault backup/restore covers ordinary memory and Direction state.
```

`AppModel` is the main UI orchestration surface. Core services own capture,
storage, retrieval, model routing, Keep, Direction, and backup boundaries. The
app should not silently bypass those services or create a parallel persistence
path.

## Project Structure

```text
CAM_Assistant/
├── Sources/
│   ├── CAMAssistantApp/       SwiftUI entry point, AppModel, UI, packaged proof
│   ├── CAMAssistantCore/      storage, capture, retrieval, models, Direction
│   └── CAMAssistantCLI/       command-line entry and commands
├── Tests/
│   ├── CAMAssistantAppTests/
│   ├── CAMAssistantCoreTests/
│   └── ReleaseProofTests/
├── Modules/                   packaged optional module manifests/resources
├── Schemas/                   machine-readable contracts
├── scripts/                   verification, packaging, smoke, and probes
├── docs/
│   ├── evidence/              recorded machine and waiver evidence
│   ├── pilots/                human protocols and novice second-Mac test kit
│   ├── plans/                 accepted and historical implementation plans
│   └── landing/               static product page
├── Package.swift
├── GOAL.md                    controlling product sequence
└── TASK_QUEUE.md              active and parked work state
```

## Entry Points and Key Modules

| Surface | File or directory | Responsibility | Status |
|---|---|---|---|
| App launch | `Sources/CAMAssistantApp/CAMAssistantApp.swift` | SwiftUI executable, smoke/proof arguments | ✅ |
| UI state/orchestration | `Sources/CAMAssistantApp/AppModel.swift` | joins views to core services and persisted state | ✅ |
| Packaged journey | `Sources/CAMAssistantApp/BarebonesPackagedProof.swift` | exercises the real packaged executable on isolated data | ✅ |
| Vault paths | `Sources/CAMAssistantCore/Storage/LocalVaultPaths.swift` | default and proof-only Application Support roots | ✅ |
| Primary storage | `Sources/CAMAssistantCore/Storage/SQLiteStore.swift` and `ContentStore.swift` | local durable content | ✅ |
| Capture | `Sources/CAMAssistantCore/Capture/` | clipboard and watched-folder ingestion | ✅ |
| Retrieval | `Sources/CAMAssistantCore/Retrieval/` | indexing, retrieval, context, and citation verification | ✅ |
| Local answers | `Sources/CAMAssistantCore/Conversation/LocalAnswerCoordinator.swift` | model-free matches and grounded local answers | ✅ |
| Keep | `Sources/CAMAssistantCore/Knowledge/KeptMemoryStore.swift` | explicit, reversible answer persistence | ✅ |
| Direction | `Sources/CAMAssistantCore/Direction/` | people, promises, north star, and Talk policy | ✅ |
| Models | `Sources/CAMAssistantCore/Models/` | local catalog/inference and advanced provider state | ⚠️ live model unverified here |
| Backup/restore | `Sources/CAMAssistantCore/Storage/FullVaultBackup.swift` | validates and restores full-vault archives | ✅ |
| CLI | `Sources/CAMAssistantCLI/main.swift` | command-line executable entry | ✅ |

## How to Run

### Developer run

```bash
git clone https://github.com/deesatzed/CAM_Assistant.git
cd CAM_Assistant
swift build
swift run CAMAssistant
```

The first dependency resolution requires network access to fetch the pinned
MeaningCore repository. Ordinary Home/Library/Settings usage does not require
enabling Meaning Preview.

### Package a local app

```bash
/bin/zsh scripts/package-app.sh
open "artifacts/CAM Assistant.app"
```

The bundle is local and unsigned. Signing, notarization, App Store distribution,
and production deployment are explicitly out of scope for the current goal.

### Test on a different Mac as a novice

Open `docs/pilots/NOVICE_TEST_START_HERE.md`. It supplies:

- safe fictional data;
- clone and package commands;
- a 40-item stable-ID checklist;
- the expected result for every item;
- stop rules for privacy or data risk;
- evidence naming instructions;
- a reusable problem/confusion/enhancement report; and
- a final results summary.

The owner has said the second Mac already has LM Studio or Ollama and a model
installed. Installation is therefore not part of the test; readiness and actual
Ask/Talk behavior still must be observed and recorded on that Mac.

## Tests and Verification

**Current Status:** 496 passing, 0 failing, 0 skipped in the fresh Swift test
run. **Known Failures:** none in that run.

### Fresh handoff evidence on `083b6b9`

| Check | Result | Evidence from this handoff run |
|---|---|---|
| Full Swift test suite | ✅ PASS | 496 tests passed; zero failures |
| Packaged barebones/Direction journey | ✅ PASS | `CAM_ASSISTANT_BAREBONES_PACKAGED status=pass` |
| Portability | ✅ PASS | required files, external truth links, generated artifacts, and diff check all clean |
| GitHub CI at exact revision | ✅ PASS | workflow run `31340973068` completed successfully |
| Git worktree before packet creation | ✅ CLEAN | `main...origin/main` with no changes |
| Human novice second-Mac run | ⚠️ NOT RUN | kit is ready; no human result has been recorded |
| Live local model on this host | ⚠️ NOT AVAILABLE | most recent probe found no ready LM Studio/Ollama endpoint |

Commands used for the fresh local evidence:

```bash
swift test --disable-sandbox --scratch-path .handoff-build
/bin/zsh scripts/verify.sh barebones-packaged
/bin/zsh scripts/verify.sh portability
git diff --check
```

The temporary `.handoff-build` directory was removed after verification.

### Single-command verification suite

For the deeper repository aggregate, use:

```bash
/bin/zsh scripts/verify.sh all
```

This aggregate was not rerun as one command during handoff creation. Its most
important constituent product checks were rerun separately above and passed.
Use a fresh clone or scratch/build path if inherited SwiftPM artifacts fail with
read-only database, permission, or `output-file-map.json` errors; those errors
have previously been build-cache failures rather than source loss.

There is no separate SwiftLint or SwiftFormat configuration. Swift compilation,
tests, repository proof scripts, `git diff --check`, and CI are the enforced
verification surfaces.

## Current State Assessment

### What's Working ✅

- ✅ Native SwiftUI app launches from SwiftPM and packages as a local app bundle.
- ✅ Home, Library, and Settings are the only primary places.
- ✅ Clipboard capture and watched-folder ingestion are implemented.
- ✅ Duplicate capture is idempotent in the packaged proof.
- ✅ Library search, source navigation, and model-free matching work offline.
- ✅ Ask answers remain ephemeral until explicit Keep.
- ✅ Keep, duplicate/update handling, exact Undo, and restart persistence are
  machine-proven.
- ✅ Direction people, promises, north star, and Talk policy are shipped.
- ✅ Full-vault backup validation and restore include Direction state.
- ✅ Sheets repaired during the UX pass expose Done and Escape.
- ✅ Optional local model discovery and local OpenAI-compatible inference paths
  exist.
- ✅ Landing page deploy and CI are green on current `main`.
- ✅ Pattern A machine gates are complete; G7 and D6 are explicitly waived for
  controlling-goal completion.

### What's Incomplete ⚠️

- ⚠️ The new 40-item novice second-Mac checklist has not been run by the owner.
- ⚠️ Live Ask/Talk with the owner's installed local model is unverified.
- ⚠️ Real-world ease of use, confusion, accessibility observations, and desired
  enhancements require the human run; automated proof cannot establish them.
- ⚠️ Parked specialist items remain incomplete by their own historical gates,
  including broad accessibility/release evidence and ADD2CAM human evidence.
- ⚠️ Signing, notarization, distribution, and production release remain a later
  product decision and are not current blockers for clone/build testing.

### What's Broken ❌

- ❌ `IMPLEMENT.md` lines 35–36 still point to the historical Finish Wiki plan,
  even though `GOAL.md` parks that plan and makes Pattern A controlling.
- ❌ Some older chronological sections of `PROGRESS.md` describe human gates as
  pending; the newest entries and waiver evidence supersede them. Do not rewrite
  history, but add a current-status index or clear supersession note if editing.
- ❌ `GOAL.md`'s Phase 2 heading still says “build paused for review,” while the
  body correctly says the implementation shipped and D6 was waived.

These are governance/documentation defects, not demonstrated runtime failures.
They should be corrected before a new implementation phase so an agent does not
resume the wrong historical plan.

### Current Blockers 🚧

There is no blocker to cloning, building, packaging, or running the ordinary app
locally. The only immediate evidence dependency is the owner's physical access
to the different Mac for the authentic novice run. A public signed release would
also require a separate scope decision and Apple signing/notarization authority.

### Feature Completion Matrix

| Feature | Status | Evidence | Gap to Done | Priority |
|---|---|---|---|---|
| Three-place shell | ✅ | `TASK_QUEUE.md:7-14`; packaged proof pass | new human observation optional under waiver | P1 |
| Clipboard capture + dedupe | ✅ | `docs/evidence/BAREBONES_GATE_STATUS.md`; packaged proof pass | novice run not yet recorded | P1 |
| Watched folders | ✅ | `TASK_QUEUE.md:13`; packaged proof pass | novice run not yet recorded | P1 |
| Library/search/citations | ✅ | `TASK_QUEUE.md:10-12`; 496-test run | novice run not yet recorded | P1 |
| Model-free Ask | ✅ | `TASK_QUEUE.md:11`; packaged proof pass | novice run not yet recorded | P1 |
| Keep/Discard/Undo/restart | ✅ | `TASK_QUEUE.md:12`; packaged proof pass | novice run not yet recorded | P1 |
| Direction profile | ✅ | `TASK_QUEUE.md:25-31`; packaged proof pass | novice run not yet recorded | P1 |
| Offline Direction Talk | ✅ | `TASK_QUEUE.md:29`; focused tests | novice run not yet recorded | P1 |
| Live local Ask/Talk | ⚠️ | `docs/evidence/local-model-probe-2026-08-09.md` | run with installed model on tester Mac | P1 |
| Backup/validate/fresh restore | ✅ | `TASK_QUEUE.md:28`; packaged proof pass | novice run not yet recorded | P1 |
| General usability/accessibility | ⚠️ | `docs/pilots/NOVICE_TEST_CHECKLIST.md` | authentic second-Mac evidence | P1 |
| Local unsigned package | ✅ | packaged proof pass | different-Mac launch not yet recorded | P1 |
| Signed/notarized distribution | ⚠️ | `GOAL.md:73-82` | new goal, credentials, and release proof | P2 |
| Historical specialist systems | ⚠️ | `TASK_QUEUE.md:42-77` | explicitly parked; do not resume implicitly | P2 |

## Recent Changes

Newest first:

| Date | SHA | Change | Why |
|---|---|---|---|
| 2026-08-09 | `083b6b9` | normalize test-kit design formatting | keep the novice kit readable and consistent |
| 2026-08-09 | `7bd94da` | normalize novice test-kit formatting | repair Markdown presentation |
| 2026-08-09 | `37818b2` | add novice second-Mac testing kit | let the owner test and record each product item |
| 2026-08-09 | `04fe9c3` | document test-kit design | lock the human-test approach before writing it |
| 2026-08-09 | `4668dc4` | sync waiver, CI, and Pages status | keep public and repository claims honest |
| 2026-08-09 | `e2a1038` | normalize hotkeys in nonisolated code | fix Swift concurrency compilation in CI |
| 2026-08-09 | `907b9dc` | fix AppModel StateObject initialization | restore CI compilation |
| 2026-08-09 | `2840cce` | focus CI on the product spine | give macOS Actions a stable relevant gate |
| 2026-08-09 | `94eb48f` | note Swift tools 6.0 | align package/CI expectations |
| 2026-08-09 | `d8de82e` | select the CI Xcode toolchain | make GitHub builds deterministic |

**Uncommitted Changes:** this dated packet plus `HANDOFF_LATEST.md`; no product
source change.

**Stashed Work:** none.

## Configuration & Secrets

### Required for ordinary use

- macOS 15 or later;
- Swift 6 tools/Xcode command-line tools to build from source;
- network access once to resolve the exact MeaningCore dependency revision;
- no hosted database, Docker, cloud account, `.env`, or API key.

Default user data lives under:

```text
~/Library/Application Support/CAMAssistant/
```

### Optional local inference

- LM Studio or Ollama may expose a local OpenAI-compatible server.
- Use Settings → Local AI → Check Again before opening Advanced settings.
- The current host's last probe found neither port `1234` nor `11434` ready.
  That is an honest environment result, not a failure of offline product paths.

### Advanced cloud-provider path

OpenRouter support is retained only in the Advanced/specialist surface. Its API
key is stored in macOS Keychain under service
`com.deesatzed.cam-assistant.openrouter`; no environment variable is required or
accepted as the ordinary secret path. Do not add the key to this repository.

### Test/proof-only environment variables

| Variable | Purpose |
|---|---|
| `CAM_ASSISTANT_APPLICATION_SUPPORT_ROOT` | isolate test/proof data from the real user vault |
| `CAM_ASSISTANT_DEFER_CAPTURE_PROCESSING` | deterministic capture scheduling in tests |
| `CAM_ASSISTANT_BAREBONES_PROOF_HOLD_SECONDS` | hold packaged proof briefly for socket inspection |
| `CAM_ASSISTANT_BUILD_DIR` | choose a fresh build directory for package proof |
| `CAM_ASSISTANT_SKIP_FRESH_CLONE` | prevent recursion inside the aggregate fresh-clone verifier |

These are developer/proof controls, not required novice setup.

### External Dependencies

| Service/dependency | Purpose | Local alternative or boundary |
|---|---|---|
| MeaningCore Git repository | exact Swift package resolution | fetched once; ordinary UI does not require enabling its pilot |
| LM Studio or Ollama | optional generated local Ask/Talk | model-free Find/Ask remains available offline |
| GitHub Actions | hosted CI evidence | run the same Swift/proof commands locally |
| GitHub Pages | optional landing page | open `docs/landing/index.html` locally |

## Known Issues & Tech Debt

1. **P1 — source-of-truth drift:** align `IMPLEMENT.md` and the Phase 2 heading
   in `GOAL.md` with the shipped Pattern A state before authorizing new work.
2. **P1 — human product evidence:** run the novice kit on the different Mac and
   preserve the completed checklist, results, problem reports, and safe evidence.
3. **P1 — live local-model evidence:** record the server/model name, readiness,
   supported answer, unsupported-answer admission, citations, and any latency or
   setup confusion on the test Mac.
4. **P2 — accessibility breadth:** use the human run to identify VoiceOver,
   focus, contrast, layout, and reduced-motion gaps beyond machine contracts.
5. **P2 — build-cache hygiene:** do not diagnose stale/read-only `.swift-build*`
   artifacts as source loss; rerun with a new scratch path.
6. **P3 — ignored Finder/build residue:** local `.DS_Store` and `.swift-build-*`
   files may exist but must remain untracked and absent from handoff claims.

No genuine `TODO`, `FIXME`, or `HACK` marker was found in the recent product/test
slice during the preceding completeness review. This does not convert parked
historical gate work into completion.

## Next Steps (Priority Order)

### Step 1 — Run the owner test on the different Mac

Open `docs/pilots/NOVICE_TEST_START_HERE.md` and follow it without improvising
the first pass. Record the build commit and a Run ID. Use only its fictional
content. Expected outcome: every stable test ID has Pass, Problem, Confusing,
Enhancement, or Skipped recorded, with filenames for supporting evidence.

### Step 2 — Triage the recorded findings

For each report, classify it as runtime defect, unclear wording/navigation,
accessibility issue, local-model interoperability, or enhancement. Preserve the
user's words. Do not silently recast “confusing” as “pass.” Rank privacy/data
risk first, then blocked core journeys, then friction and enhancements.

### Step 3 — Fix governance drift before feature work

Update only the stale controlling-plan references and headings. Preserve the
chronological record. Verify that `GOAL.md`, `IMPLEMENT.md`, `PROGRESS.md`, and
`TASK_QUEUE.md` agree about Pattern A completion, explicit waivers, and parked
specialist scope.

### Step 4 — Implement only accepted findings

Use one bounded, test-driven change per behavior. Run the nearest focused tests,
the full suite when shared core behavior changes, packaged proof for the
ordinary journey, and portability/diff checks. Update project truth files with
verified results, not expectations.

### Step 5 — Decide the next product goal separately

After the human results are adjudicated, choose whether the next approved goal
is usability remediation, local-model hardening, accessibility, or signed
distribution. Do not resume every parked historical task by default.

## Key Files Reference

| File | Purpose | When to modify |
|---|---|---|
| `AGENTS.md` | standing contributor rules | only when repository working policy changes |
| `GOAL.md` | controlling sequence and scope | approved product goal/status change |
| `GOAL_BAREBONES.md` | Phase 1 gates | approved memory-inbox contract change |
| `GOAL_DIRECTION.md` | Phase 2 gates | approved Direction contract change |
| `STANDARDS.md` | engineering and evidence standards | accepted standard/policy change |
| `IMPLEMENT.md` | implementation workflow/plan link | active implementation plan changes; stale link needs repair |
| `DECISIONS.md` | durable decisions | meaningful architecture, scope, privacy, or UX decision |
| `PROGRESS.md` | chronological verified results | after each verified work slice |
| `TASK_QUEUE.md` | active and parked task status | when evidence genuinely changes task state |

For the immediate human test:

1. `docs/pilots/NOVICE_TEST_START_HERE.md`
2. `docs/pilots/NOVICE_TEST_CHECKLIST.md`
3. `docs/pilots/NOVICE_TEST_PROBLEM_REPORT.md`
4. `docs/pilots/NOVICE_TEST_RESULTS.md`

For proof and boundaries:

- `docs/evidence/BAREBONES_GATE_STATUS.md`
- `docs/evidence/direction-GATE_STATUS.md`
- `docs/evidence/HUMAN_GATE_WAIVER_2026-08-09.md`
- `docs/evidence/local-model-probe-2026-08-09.md`
- `Tests/ReleaseProofTests/barebones-packaged-journey-tests.sh`
- `scripts/verify.sh`
- `scripts/package-app.sh`
- `scripts/probe-local-models.sh`

## Open Questions / Decisions Needed

These questions do not block the different-Mac test:

1. Which installed local model/server combination will the owner use, and does
   ordinary Local AI discovery find it without Advanced settings?
2. Which checklist items feel confusing even when they technically pass?
3. Are any accessibility issues severe enough to block the next local package?
4. After test findings are resolved, is the next goal private local use only or
   signed/notarized distribution to other people?
5. Should parked specialist surfaces remain code-only indefinitely, or be
   removed in a later explicitly approved simplification goal?

## Appendix: Machine-Readable Summary

```json
{
  "project": "CAM Assistant",
  "generated": "2026-08-09T19:10:17-04:00",
  "generated_at": "2026-08-09T19:10:17-04:00",
  "repo": {
    "url": "https://github.com/deesatzed/CAM_Assistant.git",
    "branch": "main",
    "commit": "083b6b93c4323c9790ac0a52b4fba1352e75d85f",
    "commit_date": "2026-08-09T19:04:14-04:00",
    "last_commit": "083b6b9 docs: normalize test kit design formatting",
    "uncommitted_changes": true,
    "stashed_work": 0
  },
  "stack": {
    "language": "Swift",
    "language_version": "6.0+ tools; 6.3 verified locally",
    "framework": "SwiftUI",
    "framework_version": "macOS 15 SDK target"
  },
  "control_goal": "Pattern A: barebones memory inbox plus Direction strip",
  "control_status": "complete under machine evidence plus explicit G7/D6 owner waiver",
  "runtime_status": "machine_verified",
  "human_second_mac_status": "ready_not_run",
  "local_model_status_on_handoff_host": "none_ready_at_last_probe",
  "health": {
    "tests_passing": 496,
    "tests_failing": 0,
    "tests_skipped": 0,
    "barebones_packaged": "pass",
    "portability": "pass",
    "github_ci_run": 31340973068,
    "github_ci_conclusion": "success",
    "lint_clean": null,
    "type_check_clean": true
  },
  "primary_navigation": ["Home", "Library", "Settings"],
  "ordinary_cloud_required": false,
  "ordinary_api_key_required": false,
  "signing_and_notarization": "out_of_scope",
  "immediate_next_step": "run docs/pilots/NOVICE_TEST_START_HERE.md on the owner's different Mac",
  "priority_debt": [
    "align IMPLEMENT.md with the controlling Pattern A plan",
    "correct GOAL.md Phase 2 stale heading",
    "collect and adjudicate authentic second-Mac findings",
    "record live local-model Ask/Talk evidence on the tester Mac"
  ],
  "status": {
    "working": ["Home", "Library", "Settings", "Direction", "packaging", "offline retrieval"],
    "incomplete": ["human second-Mac evidence", "live local-model evidence on the tester Mac"],
    "broken": ["stale controlling-plan references in IMPLEMENT.md and GOAL.md heading"],
    "blockers": []
  },
  "continuity": {
    "previous_handoff_loaded": true,
    "previous_handoff_is_historical": true,
    "assumptions_imported": 4,
    "debt_items_carried": 4,
    "error_references_carried": 1
  },
  "feature_completion_matrix": [
    {"feature": "ordinary local-first product", "status": "✅", "evidence": "packaged proof and 496 tests", "priority": "P1"},
    {"feature": "novice second-Mac run", "status": "⚠️", "evidence": "docs/pilots/NOVICE_TEST_CHECKLIST.md", "priority": "P1"},
    {"feature": "live local Ask/Talk", "status": "⚠️", "evidence": "docs/evidence/local-model-probe-2026-08-09.md", "priority": "P1"},
    {"feature": "signed distribution", "status": "⚠️", "evidence": "GOAL.md:73-82", "priority": "P2"}
  ],
  "verification_suite": {
    "command": "/bin/zsh scripts/verify.sh all",
    "pass_condition": "all aggregate steps exit zero and report pass",
    "result": "not_run"
  },
  "next_steps": [
    {"task": "run novice kit on the owner's different Mac", "priority": "P1", "scope": "medium"},
    {"task": "triage and verify recorded findings", "priority": "P1", "scope": "medium"},
    {"task": "align controlling documentation before feature work", "priority": "P1", "scope": "small"}
  ]
}
```
