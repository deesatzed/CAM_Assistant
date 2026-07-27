# Agno Adaptation Risk Notes

## Bottom Line

Agno has useful patterns, but it should not become CAM Assistant's core,
required runtime, storage authority, or wiki owner. CAM already has the safer
native foundations Agno would otherwise supply: immutable local source
storage, explicit promotion, exact approvals, module permissions, append-only
orchestration events, snapshots, leases, citations, and fail-closed routing.

The best path is concept mining first, followed by small Swift-native additions
behind existing CAM contracts. An optional isolated Python adapter may be
considered later for experiments, never for the default offline product.

## Ranked Adaptation Shortlist

| Rank | Agno concept | CAM value | Recommended adaptation |
|---:|---|---|---|
| 1 | Eval cases plus expected tool calls, JSON reports, and CI exit codes | High | Extend CAM's frozen eval receipts to assert route/tool/action trajectories and unanswered cases |
| 2 | Tool-batch checkpoint and safe-boundary fork/resume | High | Add typed executor checkpoint events and non-destructive branch lineage to the existing orchestration event log |
| 3 | Approval lifecycle with `expected_status` resolution guard | High | Extend exact approvals with pending/approved/rejected/expired/cancelled state and atomic single-resolution proof |
| 4 | Ordered tool hooks | High | Add a closed Swift middleware chain: privacy -> authority -> audit -> execute -> verify -> receipt |
| 5 | Durable namespaced working records with quotas and no silent eviction | Medium-high | Add bounded coordinator/module scratch state distinct from source, knowledge, and user memory |
| 6 | Decision plus later outcome record | Medium | Let explicitly kept repository ideas/tasks link to measured outcomes; never let model output promote itself |
| 7 | Step/condition/loop/router/parallel vocabulary | Medium | Use only after CAM-016 has a closed typed executor; keep limits, budgets, cancellation, and deterministic reducers authoritative |
| 8 | Read/write-separated wiki provider | Low-medium | Preserve separate query and proposed-update interfaces, but keep immutable vault plus explicit user promotion |

## Explicit Rejections

- Do not replace the native Swift app with AgentOS, FastAPI, Postgres, or a
  required Python sidecar.
- Do not enable automatic model fallback; it conflicts with CAM's explicit
  route grammar and no-substitution rule.
- Do not enable automatic/agentic memory or learning retention; answers remain
  ephemeral until Keep.
- Do not adopt the Git wiki's automatic stage/commit/rebase/push behavior.
- Do not let a model-authored workflow, tool result, decision, or configuration
  grant its own permissions.
- Do not infer that an example is production-ready from its presence in
  `agnocook.txt`; saved logs include unrun checkpoint examples and multiple
  approval/workflow failures.

## Risks

| Risk | Severity | Why It Matters | Mitigation |
|---|---|---|---|
| Python runtime becomes mandatory | High | Breaks fully native/offline packaging and expands maintenance | Swift-native concepts; optional adapter only |
| Second storage authority | High | Can split vault truth, retention, audit, and recovery | CAM Layer 1 remains sole source of truth |
| Silent provider/model fallback | High | Violates explicit routing and privacy expectations | Reject fallback APIs; fail visibly |
| Agent-controlled writes or learning | High | Bypasses Keep and exact approval | Proposal-only outputs plus existing promotion gates |
| Auto Git mutation | High | Can push wrong content or secrets | Read-only repository intake; separate exact-approved publish action |
| Cookbook/runtime drift | Medium-high | Snapshot has no commit and may exceed wheel `2.8.5` | Pin any experiment and run isolated compatibility tests |
| Weak evidence | Medium-high | Some logs are syntax-only or red | Port concepts only after CAM-native TDD and frozen evals |
| License/attribution drift | Medium | Source copying creates obligations and provenance work | Prefer clean concept reimplementation; review notices before copying |
| Framework-style workflow explosion | Medium | Adds complexity before a safe executor exists | Sequence behind CAM-016; start with one bounded loop |

## Three Approaches

1. **Swift-native pattern mining — recommended.** Adapt the top four concepts
   directly into existing CAM types and verification. Lowest architectural and
   privacy risk; preserves the native product.
2. **Optional isolated Agno experiment adapter.** A disabled module could run
   selected public/synthetic experiments through typed JSON IPC. Useful for
   comparative research, but adds Python packaging and a second failure domain.
3. **Agno-centered orchestration or wiki.** Fastest way to demo many features,
   but contradicts the approved architecture and duplicates weaker versions of
   existing trust/storage boundaries. Do not pursue.

## Safe Next Step

Choose one narrow design target. The recommended first target is a CAM-native
trajectory eval contract: frozen cases assert selected route, expected
retrieval/model/tool/action sequence, citation support, terminal state, latency,
and a machine-readable receipt. It improves every future module without adding
runtime authority.
