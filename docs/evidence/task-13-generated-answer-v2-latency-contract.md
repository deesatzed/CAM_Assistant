# Generated-Answer v2 Split Latency Contract

**Date:** 2026-08-03  
**Branch:** `agent/add2cam-integration-20260731`  
**Slice:** Finish-wiki Phase B (single active wiki slice after ADD2CAM-50)

## Decision

Per DECISIONS 2026-08-03: generated-v1 remains immutable; generated-v2 splits
warm retrieval p95 from warm generation p95 and records environment class.
Quality/abstention/citation gates are not relaxed.

## Frozen fixture

| Item | Value |
|---|---|
| Path | `Tests/Fixtures/Conversation/generated-v2/manifest.json` |
| SHA-256 | `a5be6bef00b6b5f796608979c78b994fa5ad9fdcbee4707531e20b2d044de0fc` |
| Cases | Same 7 product-contract cases as v1 |
| Quality bars | Unchanged from v1 (R@10 0.85, MRR 0.70, claim 0.95, abstention 1.0) |
| Retrieval p95 | < 50 ms |
| Generation p95 | < 2500 ms |

## Evaluator behavior

- `GeneratedAnswerEvaluator` measures retrieval and generation durations separately.
- Reports include:
  - `latencyContract` (`end-to-end-v1` | `split-v2`)
  - `environmentClass` (e.g. `apple-silicon-Ncpu`)
  - `meetsQualityThresholds`, `meetsLatencyThresholds`, `meetsFrozenThresholds`
  - retrieval and generation latency distributions
- v1 manifests still gate on warm end-to-end p95 only.
- v2 manifests gate on quality + retrieval p95 + generation p95 (not e2e).

## Verification

```text
swift test --filter GeneratedAnswerEvaluationTests
# 6 tests pass (v1 frozen + v1 evaluator + failed exit + v2 fixture + v2 evaluator + CLI parse)
```

## Non-claims

- No live named-model re-run was performed in this slice (model lists still
  user-owned; Decision 4).
- v2 does not declare CAM-013 complete; it enables honest latency product
  progress without rewriting failed v1 reports.
- 2500 ms generation budget is a product threshold for this frozen corpus, not
  a metal-vs-cpu performance claim.
