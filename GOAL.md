# CAM Assistant Goal

## Active Goal (sequenced)

### Phase 1 — Barebones memory inbox (N4 body) — controlling until complete

Complete the user-first private memory inbox defined by
[`GOAL_BAREBONES.md`](GOAL_BAREBONES.md).

**Status (2026-08-06 evidence):** Machine packaged proof for Gates 1–6 is
recorded; **Gate 7 (human) remains open**. Phase 1 is not complete until
Gate 7 has authentic human evidence or an explicit human waiver.

### Phase 2 — Direction strip + Talk (N3 face) — authorized, build paused for review

After barebones machine Gates 1–6, the ordinary product is **authorized** to
add Pattern A Direction (people, promises, north star, optional Talk) under
[`GOAL_DIRECTION.md`](GOAL_DIRECTION.md).

**Needs lock:** N3 + N4, Pattern A (memory body, direction strip face).  
**Positioning:** [`docs/plans/2026-08-09-n3-n4-pattern-a-positioning.md`](docs/plans/2026-08-09-n3-n4-pattern-a-positioning.md)  
**Implementation plan (review before code):**  
[`docs/plans/2026-08-09-pattern-a-direction-implementation.md`](docs/plans/2026-08-09-pattern-a-direction-implementation.md)

**Build rule:** No Phase 2 implementation until the human approves that plan.
Phase 2 must not regress Phase 1 gates.

### Historical / not active product queue

[`GOAL_FINISH_WIKI.md`](GOAL_FINISH_WIKI.md) and specialist ADD2CAM / wiki
scope remain historical or parked. They do not authorize expanding default
navigation. Meaning Preview is not the Direction product.

ScreenSage / ZoomIt-shell-first plans are **not** the active spine (see
workspace positioning doc).

---

## Primary Objectives

1. Ship a launchable native SwiftUI macOS app that remains useful offline.
2. Provide automatic, idempotent clipboard and watched-folder capture.
3. Build stable local memory, exact sourced retrieval, and explicit Keep.
4. Hide specialist systems from default navigation while preserving their code
   and tests.
5. Prove each barebones feature through an independent packaged journey before
   advancing.
6. Meet a general iPhone user's expectations for language, accessibility,
   defaults, recovery, and progressive disclosure.
7. **(Phase 2)** Surface private continuity—people, promises, light direction—
   on Home without a fourth primary destination or companion-bot framing.
8. **(Phase 2)** Offer optional Talk that cites Library material or admits
   absence; never invents keeps.

## User Value

One quiet app captures and retrieves personal material without forcing the user
to maintain a taxonomy—and keeps visible continuity with who matters and what
they promised, privately.

## In Scope

- This repository and its local test artifacts.
- Narrow, explicit adapters to existing local runtimes.
- Synthetic and approved evaluation fixtures.
- Local packaging without signing, notarization, or deployment.
- Phase 2: local Direction profile store, Home strip UI, Talk cite-or-admit
  policy (after plan approval).

## Out of Scope

- Broad donor-repo rewrites or merges (MLX-SAGE remains concept donor for
  stance and profile shape unless a later goal says otherwise).
- Mutating live CAM databases during read-only operations.
- Production deployment, code signing, or notarization.
- Autonomous clinical, legal, financial, or destructive decisions.
- Screen-region OCR / ZoomIt as product identity.
- Agent supervision rails as product face.
- Reopening parked specialist workspaces to ship Direction.

## Assumptions

- This repository is **standalone**: clone from
  `https://github.com/deesatzed/CAM_Assistant.git` and build with SwiftPM only.
- Apple Silicon and Swift 6.2+ are available (package requires macOS 15).
- CAM_Codx and CAM_CAM remain separately owned repositories and are **not**
  required to build or run ordinary barebones / Direction product surfaces.
- Local inference is exposed through an OpenAI-compatible local endpoint or a
  future native MLX adapter.
- MeaningCore is a pinned Swift package dependency (opt-in specialist pilot
  paths); ordinary Home/Library/Settings do not require enabling it.
- Donor repos remain read-only unless a separate approved goal changes scope.

## Non-Goals

- Reproducing every donor feature.
- Training a foundation model.
- Making the app dependent on network, Docker, PostgreSQL, or a hosted account.
- Romantic or parasocial companion product behavior.

## Completion

| Milestone | Done when |
|-----------|-----------|
| Phase 1 barebones | Every gate in `GOAL_BAREBONES.md` has required evidence |
| Phase 2 Direction | Every gate in `GOAL_DIRECTION.md` has required evidence |
| Pattern A product (N3+N4) | Phase 1 **and** Phase 2 complete (explicit waivers allowed only by human) |
