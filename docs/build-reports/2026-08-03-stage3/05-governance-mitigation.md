# Mitigation Roadmap

**Report sources:** Stage 3 UX audit, forensics, deep critique, error report, gate map, TASK_QUEUE  
**Date:** 2026-08-03

## 1. Executive remediation summary

| Metric | Value |
|---|---|
| Critical findings (🔴) | 5 |
| High (🟡 P1) | ~12 |
| Missing finish gates | 3 |
| Partial finish gates | 28 |
| Product status | incomplete — not release-ready |

Scope priorities: (1) Security/mutation authority (2) Reliability/proof automation (3) Performance honesty (4) Maintainability.

## 2. Prioritization matrix

| Finding | Sev | Effort | Risk-if-deferred | Pri |
|---|---|---|---|---|
| F03 Mac Care incomplete move executor | Critical | Med | Silent mutation / false undo promise | **P0** |
| E-0006 Silent watched capture errors | High | Low | Lost user data events | **P0** |
| F01 Latency contract vs Gemma quality | Critical | Med | Ship lies / endless false reds | **P0** |
| Approvals workspace / card dead-end | High | Med | Authority UX failure | **P0** |
| F05 Packaged GUI harness | Critical | High | No regression safety | **P0** |
| F02 V3 named model | Critical | High/unk | Fake intelligence promotion | **P1** |
| F04 Real CAM mine | Critical | High | Scope explosion if rushed | **P1** |
| ADD2CAM-50 Enable→Grant | High | Med | Blocks human pilot | **P1** |
| F06 AppModel decomposition | Medium | High | Multi-agent thrash | **P2** |
| VO/visual a11y matrix | Medium | High | After automated AX | **P2** |

## 3. Atomic mitigation tasks

### Task T-0001: Close incomplete Mac Care organization mutation surface

- **Maps to:** “`MacCareOrganizationExecutor` moves files after exact approval but has no undo, receipt store, cancellation, or postcondition receipt”
- **Scope:** `Sources/CAMAssistantCore/MacCare/MacCareOrganizationAction.swift`, tests, design plan Tasks 3–5
- **Preconditions:** No AppModel/UI wiring until undo + receipts green
- **Steps:**
  1. Either implement verified undo + durable status-only receipts + postcondition checks per plan, **or** compile-gate/remove public executor until complete.
  2. Harden path resolution: reject `..`, absolute, symlink escape on **execute**, not only planner.
  3. Align `Modules/Core/mac-care.json` capabilities with actual runtime authority.
- **Acceptance:** Unit tests cover undo success/stale-refusal; no UI entry points until green; gate `mac-care.closed-actions` path defined.
- **Verification:** `swift test --disable-sandbox --filter MacCare`
- **Rollback:** Revert executor commit; keep assess-only UI.
- **Agent hints:** Read `docs/plans/2026-07-30-mac-care-reversible-organization-action.md` first.

### Task T-0002: Unsilence watched capture failures

- **Maps to:** “Watched capture failures are swallowed (`catch {}`)”
- **Scope:** `AppModel.makeWatchedSourceService` ~L3059–3060; Activity error surfaces
- **Steps:**
  1. Capture typed error into `@Published` watched/activity status.
  2. Never empty-catch; log status-only audit if policy requires.
  3. AppModel test: injected capture failure surfaces message.
- **Acceptance:** User-visible non-empty error; no silent success.
- **Verification:** `swift test --filter WatchedSource`

### Task T-0003: Versioned generated-answer latency contract

- **Maps to:** “Gemma passes quality; p95 2010 ms fails &lt;500 ms”
- **Scope:** evaluator, fixtures, docs — **not** quality claim edits
- **Steps:**
  1. Keep generated-v1 immutable baseline.
  2. Design generated-v2: split retrieval vs generation p95; document environment (Metal/CPU).
  3. Wire CLI report fields; preserve fail reports.
- **Acceptance:** Document + tests for v2; v1 still runs and can fail latency honestly.
- **Verification:** `./scripts/verify.sh generated`

### Task T-0004: Approvals surface

- **Maps to:** “Action card shown without approve/reject; Approvals workspace missing”
- **Scope:** `ActionCardView`, `ActivityView`, `ResearchView`, `AssistantSection`, AppModel pending cards
- **Steps:**
  1. Add Approvals section **or** make ActionCardView the sole approve/cancel dispatcher.
  2. Remove dead-end “No action is dispatched from this card” without navigation.
  3. Accessibility identifiers for approve/cancel.
- **Acceptance:** Packaged journey: prepare research → approve from Approvals/Activity without Research-only trap.
- **Verification:** AppModel + accessibility contract tests

### Task T-0005: Repo-owned packaged GUI harness skeleton

- **Maps to:** “`verify.sh all` omits packaged GUI journeys”
- **Scope:** `Tests/ReleaseProofTests/`, accessibility IDs, disposable Application Support root
- **Steps:**
  1. Skeleton driver for hotkey/capture empty-state + one Approvals path when T-0004 lands.
  2. Fail closed on missing AX id; classify TCC denials.
  3. Optional opt-in target in `verify.sh` (not blocking CI until green).
- **Acceptance:** One deterministic disposable-root journey exit 0 on clean machine.
- **Verification:** harness script + `CAM_ASSISTANT_APPLICATION_SUPPORT_ROOT`

### Task T-0006: Fresh-clone privacy-scan dirty-tree fix

- **Maps to:** E-0007 “fresh-clone verification changed tracked repository files”
- **Scope:** privacy scan script, verify-fresh-clone
- **Steps:** Write scan receipt only under temp clone artifacts dir or `/tmp`; never mutate committed evidence path during verify.
- **Acceptance:** fresh-clone ends with clean `git status` in temp clone and no unexpected writes to source tree.
- **Verification:** `./scripts/verify.sh fresh-clone`

### Task T-0007: ADD2CAM-50 Enable→Grant green (integration track)

- **Maps to:** STATUS packaged pilot red
- **Scope:** Goal 50 worktree / Meaning Preview AX phases
- **Preconditions:** Do not claim human-pilot ready; do not start ADD2CAM-60
- **Steps:** Follow STATUS recovery; separate enable/grant phases; green disposable packaged journey + containment report.
- **Acceptance:** Explicit Enable → zero permissions → Grant → request green with status-only audit.
- **Verification:** Goal 50 packaged harness commands in handoff

### Task T-0008: Named-model V3 hunt (no corpus mutation)

- **Maps to:** F02 / CAM-015
- **Steps:** Run frozen V3 against additional user-selected named models; preserve every fail JSON; only then package live journey.
- **Acceptance:** Either one named pass + packaged proof, or documented inventory of fails with no gate greenwash.
- **Verification:** `./scripts/verify.sh repository-semantic` + evaluate CLI

## 4. Master verification suite

```bash
#!/usr/bin/env bash
set -euo pipefail
cd /Volumes/WS4TB/waswiki/CAM_Assistant

echo "== Portability =="
./scripts/verify.sh portability

echo "== Goal map honesty =="
./scripts/verify.sh goal-map

echo "== Focused Mac Care =="
swift test --disable-sandbox --scratch-path .swift-build --filter MacCare

echo "== Focused CAM =="
./scripts/verify.sh cam

echo "== Aggregate =="
./scripts/verify.sh all

echo "== Generated (may fail latency gate honestly) =="
./scripts/verify.sh generated || true

echo "Mitigation suite complete — inspect honest fails above"
```

## 5. GitOps

- Branch naming: `mitigate/T-XXXX-short-slug`  
- Commit: `fix(T-XXXX): …` or `feat(T-XXXX): …`  
- Do not weaken tests or gates to greenwash  
- Merge gate: relevant focused suite + no new silent catches  
