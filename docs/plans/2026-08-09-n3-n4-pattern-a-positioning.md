# Needs & Positioning — N3 + N4, Pattern A

**Date:** 2026-08-09  
**Status:** Locked (user confirmed Pattern A)  
**Supersedes as primary product spine:** ScreenSage / ZoomIt-shell-first design (`ScreenSage/docs/plans/2026-08-09-screensage-design.md`)  
**Does not delete:** ScreenSage docs remain historical; glass/OCR may return later as a **capture channel**, not identity.

---

## 1. Needs locked

| Code | User statement | Product language |
|------|----------------|------------------|
| **N3** | “I drift; I need continuity with people/promises, privately.” | Who matters, what I promised, where I’m aimed — private partner continuity |
| **N4** | “I capture everything and can’t find or trust it later.” | Captures are findable, sourced, deliberately Kept — private memory trust |

### Spine sentence

> A **private place that remembers what I kept and who I’m responsible to**, so when I drift or drown in captures I can **find the real thing** and **act toward real people**—not restart from a blank chat.

---

## 2. Pattern A (locked)

**Memory is the body; Direction is the face (thin strip).**

| Layer | Role | Need |
|-------|------|------|
| **Body (default daily use)** | Capture → find → ask-with-sources → Keep/discard | **N4** |
| **Face (always visible, light)** | People, open promises, north star; short partner talk when invited | **N3** |
| **Rule** | Partner may use Library + profile; must **cite or admit absence** — no invented sources | both |

### Why A (not B or C)

- Capture frequency > existential check-ins → habit forms on **N4**.
- Empty backpack makes partner generic → **N4 first** feeds **N3**.
- Dual equal homes (C) feels like two apps; partner-first (B) underweights the “I capture everything” pain.

### Explicit non-spine

| Not primary | Notes |
|-------------|--------|
| Screen region OCR / ZoomIt shell | N1 — optional intake later |
| Agent Rails / WattOS face | N7 — separate tribe |
| Enterprise graph platform | Semantica-scale — ideas only |
| Romantic companion | Refused |

---

## 3. Product promise

> A private Mac companion that **quietly keeps what you capture** so you can find and trust it later, and **holds continuity** with the people and promises that keep you from drifting—local by default, **partner not servant**.

**Friendly version of:**

| Powerful / existing | Friendly gap this product fills |
|---------------------|----------------------------------|
| Personal RAG / wiki / KG stacks | Inbox UX, citations, Keep — no ontology job |
| MLX-SAGE / sage partner (TUI) | Same stance + people/promises — native, guided, non-terminal |
| ChatGPT Memory | Local, inspectable, **commitment-oriented**, not engagement-max |

---

## 4. Ordinary destinations (UX spine)

Designed for low jargon (CAM barebones discipline).

| Destination | Purpose |
|-------------|---------|
| **Home** | Capture status, Ask (grounded), Keep/discard; **Direction strip** always present (people / open promises / one-line north star) |
| **Library** | Browse, search, open sources, citations, hide/restore |
| **Settings** | Capture sources, Local AI, Backup & Restore; Advanced collapsed |

**Direction is not a fourth dungeon.** It is a **Home card / strip** plus optional “Talk” that opens partner dialogue. Deep edit of people/promises can be a sheet from the strip.

### Home layout (conceptual)

```text
┌─────────────────────────────────────────────┐
│ DIRECTION STRIP (N3)                        │
│ People: …  ·  Open: …  ·  Direction: …      │
│ [Talk]  [Add promise]                       │
├─────────────────────────────────────────────┤
│ CAPTURE / ASK (N4 body)                     │
│ Recent saves · Find · Ask · Keep/Discard    │
└─────────────────────────────────────────────┘
```

---

## 5. Capability rules (needs filter)

### Must have (v1 intent)

| Capability | Need | Rule |
|------------|------|------|
| Clipboard + one watched-folder capture | N4 | Auto, idempotent, plain success/fail; survives restart |
| Library + exact find **without** model | N4 | Offline; recognizable source names |
| Ask with citations → Library item | N4 | No silent ungrounded claims about “your stuff” |
| Answers ephemeral until **Keep** | N4 | Landfill control |
| People (real humans only) | N3 | No AI “friends” as people |
| Commitments / promises | N3 | Toward person or shared good |
| North star / direction (light) | N3 | Human-owned |
| Partner Talk (local when available) | N3 | Partner stance; refusals (no romance; no “you don’t need people”) |
| Local authoritative store | both | Backup/restore; no silent cloud |
| Progressive disclosure | both | No embeddings/index jargon on happy path |

### Graceful degradation

| Situation | Behavior |
|-----------|----------|
| No local model | Find + Library + capture + profile edit still work; Talk shows honest coach |
| Empty Library | Ask admits no sources; Direction still usable |
| Empty Direction | Capture/Find still work; strip invites one person + one promise without blocking capture |

### Out of v1 face

- Region-OCR as hero loop  
- Coding agent supervision UI  
- Full graph compile server  
- Always-on screen recording memory  
- Multimodal-everything  

---

## 6. Data objects (minimal)

```text
Capture / Source   → bytes + provenance (N4 authority)
Keep               → deliberate retain of answer or item
Person             → real human, relation, optional need notes (N3)
Commitment         → text, toward person | shared_good, open/done (N3)
Direction          → north_star text, updated (N3)
Talk turn          → optional; may reference cite IDs (N3+N4)
```

**Authority:** Source bytes and provenance win over derived indexes (CAM rule).  
**Partner:** Does not own consequential decisions; human does (MLX-SAGE rule).

---

## 7. Relationship to existing repos

| Repo | Role under this spine |
|------|------------------------|
| **CAM_Assistant** | Primary **N4 body** candidate — barebones Home/Library/Settings already match Pattern A body |
| **MLX-SAGE** | Primary **N3 soul** donor — people, commitments, stance, refusals; port concepts into native Direction strip + Talk |
| **sage-wiki** | Later compile/graph — not day-one shell |
| **semantica** | Provenance/decision ideas only |
| **ZoomitForMac** | Optional future capture channel |
| **ScreenSage plans** | Historical glass-first path; **not** current primary |
| **prime-agent** | Out of product face |

### Build sequencing principle

Prefer **extend the N4 body (CAM barebones) with N3 Direction strip + Talk** over greenfield “third religion,” unless CAM’s active goal forbids expansion—in that case: finish CAM N4 gates first, then a **separate approved goal** adds N3.

**Honesty:** `CAM_Assistant/GOAL.md` currently prioritizes barebones N4 only. Adding N3 requires **explicit goal amendment** before implementation—not silent scope creep.

---

## 8. Success signals (needs, not marketing)

| Signal | Need |
|--------|------|
| Capture offline; restart-safe | N4 |
| Find returns recognizable passage + opens source | N4 |
| Exact find works with zero model | N4 |
| Keep/discard used on purpose | N4 |
| People + ≥1 open promise visible on Home without terminal | N3 |
| Talk cites Library or admits “not in your keeps” | N3+N4 |
| After a week, strip still shows *your* data | N3 |
| No romantic behavior; no silent cloud | both |

---

## 9. What we will not claim

- That ScreenSage glass-first is the active product spine  
- That N3 is done because MLX-SAGE exists in Python  
- That N4 is done because CAM has code without barebones gate evidence  
- Production-ready / complete while gates remain open  
- Time, cost, or revenue estimates  

---

## 10. Decisions locked (2026-08-09)

1. Primary needs: **N3 + N4** only for this product spine  
2. Architecture of experience: **Pattern A** — memory body, direction strip face  
3. Friendly version of: personal memory inbox + sage partner continuity  
4. Glass/ZoomIt/ScreenSage: **not** primary; capture channel at most later  
5. Implementation vehicle: **prefer CAM body + sage N3**, subject to explicit CAM goal amendment  
6. No mocks / fake grounded answers  

---

## 11. Next steps (docs / process only until build approved)

1. ~~Amend CAM goal for Pattern A N3~~ **Done** — `CAM_Assistant/GOAL.md` + `GOAL_DIRECTION.md`  
2. ~~Implementation plan~~ **Done** — `CAM_Assistant/docs/plans/2026-08-09-pattern-a-direction-implementation.md`  
3. **Human review** of goal + plan; then explicit “start DIR-001” before code  
4. **Do not** resume ScreenSage P0 shell as the mainline build  

---

## Document control

| Field | Value |
|-------|--------|
| Locked pattern | A |
| Needs | N3, N4 |
| Canonical path | `docs/plans/2026-08-09-n3-n4-pattern-a-positioning.md` |
| Related | `CAM_Assistant/GOAL_BAREBONES.md`, `CAM_Assistant/GOAL_DIRECTION.md`, `CAM_Assistant/docs/plans/2026-08-09-pattern-a-direction-implementation.md`, `MLX-SAGE` partner stance, `ScreenSage` historical plans |
