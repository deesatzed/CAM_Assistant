# Critique — mode=auto profile=deep

**Date:** 2026-08-03  
**Roles:** staff Swift engineer · privacy/security · reliability/QA  
**Lenses:** Correctness, Security/Privacy, Reliability, Architecture, DevEx/Tests

## Executive summary

Foundation is unusually strong for a local-first assistant: fail-closed privacy/routing, digest-bound approvals, disposable CAM stats confinement, synthetic mining isolation, module grant separation, frozen eval with preserved failures, and a machine-readable 48-gate map that refuses to greenwash.

**Product is not finish-ready.** Blocking clusters: model product gates, incomplete mutation authority, proof automation, ADD2CAM pilot.

## Critical findings (🔴 P0)

| ID | Finding | Evidence | Mitigation |
|---|---|---|---|
| F01 | Gemma quality pass; p95 ~2010 ms fails &lt;500 ms | `task-13-generated-answer-evaluation.md` | Version generated-v2 latency contract; keep v1 immutable |
| F02 | No named model passes repo semantic V3 | `task-15-repository-semantic-evaluation.md` | Hunt named models; preserve fails; then packaged journey |
| F03 | `MacCareOrganizationExecutor` moves files without undo/receipts | `MacCareOrganizationAction.swift` | Finish plan Tasks 3–5 **before any UI wiring** or remove surface |
| F04 | Real CAM mining not product—stats + synthetic only | CAM-016, `CAMMiningLifecycle.swift` | Disposable mine pin after design; never live corpus default |
| F05 | No repo-owned packaged GUI suite in `verify.sh all` | `task-18-ux-release-gap-audit.md` | AX driver under ReleaseProofTests |

## Major findings (🟡)

- F06: `AppModel` ~3655-line god object  
- F07: Dual coordination models; `verifiedPartial` never produced  
- F08: Organization path containment string-prefix; weak `..` rejection on execute  
- F09: Mac Care manifest vs actual authority fiction  
- F10: Nested sandbox-exec false reds in managed harnesses  
- F11: A11y = source contracts + manual AX, not VO/visual matrix  
- F13: LocalModelClient defense-in-depth weaker than Meaning Preview supplier  
- F14: Stale gap audits vs gate map (Modules now exist)  
- F17: ADD2CAM-050 status drift (Ready vs in-progress red pilot)

## RICE sequence (deep profile)

1. Close or finish Mac Care org action (mutation safety)  
2. Versioned latency contract (honest CAM-013 progress)  
3. Packaged GUI harness skeleton  
4. Named-model V3 hunt (preserve fails)  
5. Disposable real CAM mine design  
6. ADD2CAM-050 if this integration branch is the pilot track  

## Protect (do not break)

- Honest gate map + preserved fail reports  
- Zero-egress restricted outbound + exact one-use approvals  
- Loopback-only local model endpoints  
- Closed CAM stats pattern (registry, sandbox, donor revalidation, fail-closed journal)  
- Synthetic mining never opens real CAM  
- Module enable ≠ grant  
- Fresh-clone / package reproducibility / credential scan  
- Frozen eval corpora without version bumps  
