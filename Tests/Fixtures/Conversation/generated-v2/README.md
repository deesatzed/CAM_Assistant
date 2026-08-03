# Generated Answer Evaluation v2

Version 2 reuses the same approved product-contract cases as v1. It does **not**
relax quality, citation, or abstention rules.

## What changed

- Latency contract is **split**: warm **retrieval** p95 and warm **generation**
  p95 are gated separately.
- Reports record `latencyContract`, `environmentClass`, and separate retrieval /
  generation latency distributions.
- Warm end-to-end p95 is still measured and reported, but is **not** the v2
  latency gate (v1 remains the e2e baseline).

## Frozen thresholds

| Gate | Threshold |
|---|---|
| Recall@10 | ≥ 0.85 |
| MRR | ≥ 0.70 |
| Cited-claim support | ≥ 0.95 |
| Abstention accuracy | = 1.0 |
| Warm retrieval p95 | < 50 ms |
| Warm generation p95 | < 2500 ms |

Frozen manifest SHA-256:
`a5be6bef00b6b5f796608979c78b994fa5ad9fdcbee4707531e20b2d044de0fc`.

## Non-claims

- Does not replace or rewrite generated-v1.
- Does not prove personal-vault quality.
- Does not prove Metal vs CPU beyond the recorded `environmentClass` string.
- Generation budget of 2500 ms is an honest local-model product threshold for
  this corpus, not a claim that every machine will hit it.

Do not alter this manifest after observing model results. Create a new version
instead.
