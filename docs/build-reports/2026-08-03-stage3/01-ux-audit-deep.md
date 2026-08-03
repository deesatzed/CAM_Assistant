# UX Audit — mode=deep

**Date:** 2026-08-03  
**Branch:** `agent/add2cam-integration-20260731`  
**Role:** SWE  
**Scope:** `Sources/CAMAssistantApp/`, AppModel, hotkeys/capture, packaged UX evidence

## UX Executive Summary

CAM Assistant feels like a dense, honest local-first operator console—not a consumer chat app. Copy relentlessly states boundaries (local-only, explicit Keep, no auto cloud/CAM mining). The default Assistant path is usable; secondary workspaces (Repositories, CAM, Research, Meaning Preview) are expert-grade and cognitively heavy.

**Maturity:** Advanced prototype / pre-release local tool. Vertical slices have unit and packaged proof; product-level UX (Approvals workspace, unified recovery journey, VoiceOver matrix, Meaning Preview packaged pilot) is incomplete. **Not ship-complete.**

### Top 5 frictions

1. **Approvals split-brain** — Action cards in Activity are read-only; approve lives only on Research.
2. **Meaning Preview Enable→Grant packaged pilot still red** (`STATUS_20260802_PACKAGED_PILOT.md`).
3. **No Approvals workspace** despite finish-wiki requirement (`ux.workspace-set` partial).
4. **Unified fresh-user / whole-product restart journey missing** (`ux.fresh-restart-journeys` = missing).
5. **Watched capture errors silently swallowed** (`AppModel.swift` empty `catch {}`).

### Top 5 delights

1. Authority-visible chrome (disabled states explain *why*).
2. Capture → Activity cancel/resume → restart packaged journey is real.
3. Hotkeys + watched folders with pause-by-default and Library refresh.
4. Citation → Open in Library closes the grounded-answer loop.
5. Backup never overwrites live vault (restore only to a new root).

## Core journeys

| Journey | Evidence |
|---|---|
| Capture → Library → local ask → Keep / task | `ConversationView.swift`, `LibraryView.swift`, `task-13-*` |
| Hotkeys + watched sources restart | `HotkeySettingsView`, `CaptureSourcesView`, `task-13-packaged-hotkey-journey.md` |
| Research exact public-document acquisition | `ResearchView` Approve & Acquire; `ActionCardView` read-only mirror |

## Friction inventory (selected)

| Friction | Sev | Evidence | Fix |
|---|---|---|---|
| Action card without approve | P0 | `ActionCardView.swift`, `ActivityView.swift` | Approvals workspace or dispatch on card |
| Approvals workspace missing | P0 | `AssistantSection` / gate map | Wire durable approval store |
| Meaning Preview packaged red | P0 | `STATUS_20260802_PACKAGED_PILOT.md` | Green Enable→Grant→request |
| Silent watched capture errors | P0 | `AppModel.swift` ~L3060 | Surface status/Activity error |
| Mac Care “needs approval” vs hard-unavailable | P1 | `MacCareView.swift` | Say mutations unavailable this milestone |
| Gate says CAM status-only; UI is interactive | P1 | `CAMStatusView.swift` | Update gates; publish pin into health |
| Library no ScrollView | P1 | `LibraryView.swift` | Scroll + stable a11y names |
| VO / contrast / large-data unproven | P1 | `task-18-ux-release-gap-audit.md` | Expand matrix; keep contracts separate |

## Expectation vs reality gaps (9)

- Action card implies approval → no dispatch from Activity.
- Mac Care empty copy implies approval-gated maintenance → apply/undo always unavailable.
- Hotkeys “session-only” → config persists and re-registers.
- Older audit: no Modules/Backup → both exist now.
- Health CAM unavailable text independent of successful pin session.

## AI surface review

| Surface | Class | Gap |
|---|---|---|
| Local retrieval chat | Live | Error collapse to “Enter a question…” |
| Selected local model | Hybrid | Latency gate red for Gemma |
| Repo semantic V3 | Hybrid | No named model passes |
| Research public doc | Live | Action-card dual display |
| Meaning Preview practical | Hybrid | Packaged pilot red |
| Meaning Preview reflect | Gated off | No named-model admission |
| CAM stats tools | Live (closed) | Not mining |
| Modules “Summarize” | Live non-LLM | Word/char count only |

## Accessibility

**Strengths:** `.accessibilityElement(children: .contain)` on primary workspaces; empty-state labels; no app-authored motion APIs; Meaning Preview stable identifiers.

**Weaknesses:** Source-contract tests ≠ VoiceOver speech; tab order FKA-dependent; opaque Library source IDs; populated/error/large-data matrix missing; contrast/dynamic type unmeasured.

## Prioritized action plan

**P0:** Approvals surface; unsilence watched errors; Meaning Preview packaged Enable→Grant; scripted fresh-user/restart journey; retire dead empty-state copy.  
**P1:** Scroll/large-data layouts; CAM health honesty; Mac Care copy; accurate throw messages; a11y beyond source contracts; cancel in-flight generation.  
**P2:** Activity cancel on retrying; Modules pilot framing; backup picker polish.

```json
{
  "mode": "deep",
  "journeys_analyzed": 3,
  "friction_count": {"P0": 5, "P1": 12, "P2": 5},
  "ai_touchpoints": 9,
  "expectation_reality_gaps": 9,
  "accessibility_flags": 9,
  "confidence": "high"
}
```
