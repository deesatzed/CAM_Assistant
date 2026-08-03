# Error Reference Report

**Date:** 2026-08-03  
**Mode:** governance --mode=errors (report)  
**Project:** CAM_Assistant  
**Sources:** evidence docs, PROGRESS, ADD2CAM handoffs, code signatures, Stage 3 chain

## Top recurrent / systemic

| ID | Signature | Occurrences | Status | Last seen | Mitigation summary |
|---|---|---|---|---|---|
| E-0001 | Nested `sandbox-exec` denied under outer managed sandbox (exit 71) | ≥2 (CAM closed tool, module lifecycle harness) | mitigated (env-classified) | 2026-07-30 | Run product sandbox proofs at normal macOS privilege; retain product sandbox; classify harness false-red |
| E-0002 | Generated-answer latency gate fail (Gemma p95 ~2010 ms &gt; 500 ms) | Multiple named-model runs | open | task-13 reports | Do not relax quality; design versioned latency contract separately |
| E-0003 | Repository semantic V3 named-model quality fail | Gemma + others | open | task-15-*-failed*.json | Preserve fail reports; hunt models; no corpus edits |
| E-0004 | Meaning Preview reflection disabled: selected_model_unavailable | 1+ report cycle | open (expected) | add2cam-09-named-model-report.json | Practical path remains; reflection requires admitted named-model report |
| E-0005 | ADD2CAM-50 packaged AX: enable→grant journey red | Multiple GUI attempts | open | STATUS_20260802_PACKAGED_PILOT.md | Separate enable/grant phases; fix AX timing; do not accept Goal 50 |
| E-0006 | Watched capture failure swallowed (`catch {}`) | code defect, latent | open | AppModel.swift ~L3060 | Surface captureMessage / Activity error; never silent |
| E-0007 | Fresh-clone verify side-effect dirty: `task-18-release-privacy-scan.json` | observed 2026-08-03 verify | open | verify.sh run | Privacy scan must not mutate tracked evidence mid-clone; write to temp receipt only |
| E-0008 | Interrupted closed CAM run: fail-closed journal, no resume | by design | mitigated (design) | task-16 journal | Never auto-resume; operator recovery tool needs separate design |

## New errors (this Stage 3 session)

| ID | Signature | Root cause (hypothesized) | Mitigation |
|---|---|---|---|
| E-0007 | Tracked privacy-scan JSON modified during fresh-clone verify | Scanner/writer uses repo path for receipt | Write receipts under temp root; assert clean tree after fresh-clone |

## Mitigated & holding

| ID | Verification |
|---|---|
| E-0001 nested sandbox | Documented; normal-macOS proof path for closed CAM stats exists |
| E-0008 interrupt journal | Focused CAM adapter tests for `interrupted_previous_run` |

## Recurrent despite mitigation (escalation)

None newly escalated this session. E-0002 and E-0003 remain product-blocking open gates (not regressions of a “fixed” mitigation).

## Error → mitigation pairing rule

- Never mark mitigated without a stored verification command.  
- Preserve every failed named-model report (nonzero CLI exit).  
- Silent catch blocks are always open until user-visible status exists.

## Storage note

Project overlay should live at `.governance/errors.json` on a future write pass. This report is the Stage 3 durable artifact under `docs/build-reports/`.
