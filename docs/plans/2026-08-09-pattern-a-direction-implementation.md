# Pattern A Direction Implementation Plan

> **For implementers:** Execute only after human approval.  
> **REQUIRED:** Phase 1 barebones non-regression on every Direction PR.  
> **No mocks** of Partner Talk. No time estimates.

**Goal:** Add a thin Home **Direction** strip (people, promises, north star) and optional **Talk** that cites Library material or admits absence—Pattern A N3 face on the existing N4 barebones body.

**Architecture:** Keep CAM’s vault, ingest, retrieval, Ask, Keep, and backup substrate. Add a small **Direction profile store** in Core (file- or SQLite-backed, vault-rooted). Present a SwiftUI strip on `HomeView` without a fourth primary destination. Reuse the barebones single-Ask / citation policy for Talk about saved content; inject profile context into prompts without inventing Library facts.

**Tech stack:** Swift 6, SwiftUI, existing CAMAssistantCore storage patterns, Swift Testing / app tests, packaged proof scripts under `scripts/` and `Tests/ReleaseProofTests/`.

**Controlling docs:**

| Doc | Role |
|-----|------|
| `GOAL.md` | Sequenced Phase 1 / Phase 2 |
| `GOAL_BAREBONES.md` | N4 body; must stay green |
| `GOAL_DIRECTION.md` | N3 gates D1–D6 |
| `docs/plans/2026-08-09-n3-n4-pattern-a-positioning.md` | Needs lock |

**Build status:** **Paused for human review.** Do not implement until approved.

---

## Principles

1. **Body first on Home:** Save / Find / Ask / Keep remain below the strip; strip never replaces them.
2. **Three destinations only:** Home, Library, Settings.
3. **Not Meaning Preview:** Do not enable ADD2CAM specialist nav to ship N3.
4. **Cite-or-admit:** Talk must not invent keeps.
5. **Offline-first strip:** Profile CRUD works with zero model.
6. **One feature, one gate evidence** before the next UI expansion.
7. **Donor only:** MLX-SAGE stance/profile shape is conceptual; no Python merge.

---

## Current baseline (do not re-litigate)

| Item | State |
|------|--------|
| Barebones Gates 1–6 | Machine packaged evidence exists (`docs/evidence/barebones-packaged-journey.md`) |
| Barebones Gate 7 | Human pending |
| Home | `Sources/CAMAssistantApp/Views/HomeView.swift` — welcome, capture, ask, result, recent memories |
| Ask path | Single local Ask; model-free passages; no cloud fallback |
| Keep | Concise cited memory store; full-vault backup aware |

---

## Phase map

```text
DIR-001 store ──► DIR-002 strip ──► DIR-003 edit sheets
                      │
                      ▼
                 DIR-004 backup
                      │
            ┌─────────┴─────────┐
            ▼                   ▼
       DIR-005 offline Talk   DIR-006 cite-or-admit Talk
            └─────────┬─────────┘
                      ▼
                 DIR-007 packaged proof
                      ▼
                 DIR-008 human (parallel-ok with barebones G7)
```

---

### Task DIR-001: Direction profile store

**Files (proposed):**

- Create: `Sources/CAMAssistantCore/Direction/DirectionModels.swift`
- Create: `Sources/CAMAssistantCore/Direction/DirectionProfileStore.swift`
- Create: `Tests/CAMAssistantCoreTests/DirectionProfileStoreTests.swift`
- Modify: vault root / app support path wiring as existing stores do (match Keep / settings patterns—inspect neighboring stores before coding)

**Models (minimal):**

```swift
struct DirectionPerson: Equatable, Codable, Identifiable {
    var id: String
    var name: String
    var relation: String
    var notes: String
    // real humans only — enforced in UI + validation (reject empty name)
}

struct DirectionPromise: Equatable, Codable, Identifiable {
    var id: String
    var text: String
    var toward: String   // person name or "shared good"
    var createdAt: Date
    var isOpen: Bool
}

struct DirectionProfile: Equatable, Codable {
    var people: [DirectionPerson]
    var promises: [DirectionPromise]
    var northStar: String
    var updatedAt: Date
}
```

**Step 1:** Write failing tests: empty profile load; add person; add promise; toggle promise done; atomic write; corrupt file fails closed to empty or recoverable error (match project store conventions).

**Step 2:** Run tests — expect FAIL (types missing).

**Step 3:** Implement store under the app’s data root (same family as kept-memory / settings). No network.

**Step 4:** Run tests — expect PASS.

**Step 5:** Commit only after review approval to start Phase 2:  
`feat: add Direction profile store for Pattern A N3`

**Gate:** partial D2 (persistence without UI).

---

### Task DIR-002: Home Direction strip (read-only + empty invites)

**Files:**

- Create: `Sources/CAMAssistantApp/Presentation/DirectionPresentation.swift`
- Create: `Sources/CAMAssistantApp/Views/DirectionStripView.swift`
- Modify: `Sources/CAMAssistantApp/Views/HomeView.swift` — strip **above** capture/ask body
- Modify: `Sources/CAMAssistantApp/AppModel.swift` — load profile on appear; expose presentation
- Create/Modify: app tests for Home accessibility / primary structure if present (e.g. Home presentation tests)

**Copy rules:**

- Empty: “Who matters to you?” / “One small promise this week?” — not “create entities.”
- Populated: show up to ~3 names, first open promise or count, one-line north star.
- No hashes, paths, or model endpoint text on the strip.

**Step 1:** Failing UI/presentation test: Home hierarchy includes Direction region; production experience still only Home/Library/Settings destinations.

**Step 2:** Implement strip; wire load from store.

**Step 3:** Manual: launch app, see empty strip; capture still works.

**Step 4:** Commit: `feat: show Direction strip on Home`

**Gate:** D1 (with evidence note under `docs/evidence/direction-d1-strip.md` when run).

---

### Task DIR-003: Add / edit person and promise

**Files:**

- Create: `Sources/CAMAssistantApp/Views/DirectionEditSheets.swift` (or split)
- Modify: `DirectionStripView`, `AppModel` — add/update/remove actions
- Tests: store + AppModel direction actions

**Rules:**

- Person requires non-empty name; relation optional plain text.
- Promise requires non-empty text; toward defaults to “shared good” or picker of people.
- Mark promise done from strip or sheet.
- Edit north star in a simple sheet (multiline plain text).

**Step 1:** Failing tests for validation and persistence through AppModel API.

**Step 2:** Implement sheets from strip buttons.

**Step 3:** Restart app — data remains.

**Step 4:** Commit: `feat: edit people and promises from Direction strip`

**Gate:** D2 (UI + persistence).

---

### Task DIR-004: Backup and restore includes Direction profile

**Files:**

- Modify: full-vault backup/restore types (locate existing Keep inclusion—mirror that pattern)
- Tests: existing full-vault backup tests + Direction case

**Step 1:** Failing test: profile with one person survives backup → restore to fresh root.

**Step 2:** Include Direction profile file(s) in backup manifest/validation.

**Step 3:** Restored watched folders remain paused (barebones rule unchanged).

**Step 4:** Commit: `feat: backup and restore Direction profile`

**Gate:** D2 complete for recovery.

---

### Task DIR-005: Talk offline coach

**Files:**

- Create: `Sources/CAMAssistantApp/Views/DirectionTalkView.swift` (sheet or Home section)
- Modify: `AppModel` — `openDirectionTalk()`, offline path only first
- Presentation: ordinary language “Local AI is not ready” — no endpoint strings in primary copy (Advanced may still show tech detail if user opens Settings)

**Step 1:** With model unhealthy, Talk shows coach only; **zero** assistant prose that looks like a model answer.

**Step 2:** Test or packaged assertion: no inference client call on offline Talk open + send attempt.

**Step 3:** Commit: `feat: Direction Talk offline coach`

**Gate:** D3.

---

### Task DIR-006: Talk cite-or-admit (local model)

**Files:**

- Create: `Sources/CAMAssistantCore/Direction/DirectionTalkCoordinator.swift` (or app-layer coordinator mirroring single-Ask)
- Modify: reuse retrieval + citation validation from barebones Ask path
- Prompt builder: system = partner stance + refusals + profile JSON/text; user = question; evidence block = retrieved passages when query is about saved material

**Policy (hard):**

| User intent | Behavior |
|-------------|----------|
| About saved material / “what did I keep” | Retrieve first; model only with valid citations; else admit not enough |
| About people/promises only | May answer from profile without Library citations; must not invent Library items |
| Model fails / invalid citations | Fall back to passages or honest failure — **no** cloud/web/CAM/retry-other-provider |

**Step 1:** Unit tests: invented citation rejected; empty evidence → admit; profile-only question does not require passages.

**Step 2:** Implement coordinator; wire Talk send.

**Step 3:** Optional Keep: user may Keep a Talk answer via **existing** Keep flow only if citations valid (same as Ask). Do not invent a second durable transcript store.

**Step 4:** Commit: `feat: Direction Talk cite-or-admit with local model`

**Gate:** D4.

---

### Task DIR-007: Packaged non-regression + Direction proof

**Files:**

- Modify: `BarebonesPackagedProof` or add `DirectionPackagedProof` sibling
- Modify: `scripts/verify.sh` if needed for a `direction` or extended barebones target
- Create: `docs/evidence/direction-packaged-journey.md`

**Must prove:**

1. Barebones packaged journey still green (D5).
2. Strip visible; add person+promise; restart still shows them.
3. Offline Talk coach (no fabricated answer).
4. Optional: model path if proof environment has loopback model (document if skipped).

**Step 1:** Extend proof mode carefully—isolated Application Support root only.

**Step 2:** Run packaged proof; save evidence.

**Step 3:** Commit: `test: packaged Direction and barebones non-regression proof`

**Gate:** D5 (+ package D1–D4 as applicable).

---

### Task DIR-008: Human Direction gate

**Files:**

- Create: `docs/pilots/direction-general-user-protocol.md` (mirror barebones pilot tone)
- Evidence: human-filled notes only

**Cannot** be satisfied by agents or synthetic packaged-only runs.

**Gate:** D6.

---

## Explicit non-tasks (reject if suggested mid-build)

| Temptation | Response |
|------------|----------|
| Fourth sidebar item “Direction” | No — strip on Home only |
| Enable Meaning Preview by default | No — different product |
| Port full MLX-SAGE TUI | No — stance + schema only |
| Screen OCR hero | No — not this goal |
| Cloud Talk fallback | No — barebones Ask policy |
| Mock LLM for demos | No — without explicit human approval |

---

## Verification commands (run when implementing)

```bash
# Focused (adjust names to match final test targets)
cd CAM_Assistant
swift test --filter DirectionProfileStoreTests
# App / presentation tests as added

# Barebones non-regression (existing)
/bin/zsh scripts/verify.sh barebones-packaged

# Broader suite when touching shared types
# (use project’s established verify path; do not claim green without output)
```

Expected: all invoked proofs exit 0; evidence files updated; `TASK_QUEUE.md` statuses advanced only with evidence.

---

## Evidence index (create when gates pass)

```text
docs/evidence/
  direction-d1-strip.md
  direction-d2-profile-backup.md
  direction-d3-offline-talk.md
  direction-d4-cite-or-admit.md
  direction-packaged-journey.md
  direction-GATE_STATUS.md
```

---

## Risk register

| Risk | Mitigation |
|------|------------|
| AppModel growth / specialist bleed | Thin Direction API on AppModel; store in Core; no Research coupling |
| Talk becomes second Ask with weaker rules | Share citation validation with barebones Ask |
| Empty N3 theater | Empty strip is optional invites; never block N4 |
| Gate 7 pilot confusion | Direction pilot separate protocol; optional freeze UI for barebones human run |
| Scope creep to “full sage” | GOAL_DIRECTION stop rules; checklist only |

---

## Approval checklist (human)

Before any Phase 2 code:

- [ ] `GOAL_DIRECTION.md` accepted
- [ ] This plan accepted (or amended in writing)
- [ ] Confirm: Direction is **not** Meaning Preview
- [ ] Confirm: no ScreenSage/ZoomIt work in this phase
- [ ] Confirm: barebones Gate 7 may remain parallel/open
- [ ] Explicit “start DIR-001” message to implementers

**Until then: documentation only.**

---

## Document control

| Field | Value |
|-------|--------|
| Created | 2026-08-09 |
| Status | Awaiting human review |
| Supersedes for spine | ScreenSage primary implementation roadmap |
