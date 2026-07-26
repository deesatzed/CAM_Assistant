# CAM-006 Retrieval Evidence Receipt

## Result

**Verified for its bounded synthetic-fixture acceptance gate.** This is not a
claim that the complete CAM Assistant or the full GOAL_3Layer product is done.

## Current evidence

- Frozen fixture: `Tests/Fixtures/Retrieval/v2/manifest.json`
- Fixture SHA-256: `3172ab92fd1f2122de14f00bfb604d76eeaf11a04319b020c05c69ee5a32ffcb`
- Current report: `docs/evidence/task-06-retrieval-v2-report.json`
- Methodology: `docs/evidence/task-06-retrieval-methodology.md`
- Branch/HEAD at verification: `feat/cam-assistant-foundation` /
  `7f80d29` with intentional in-progress Task 6 changes present

| Gate | Evidence |
|---|---|
| Versioned mixed-modality chunks and frozen labels | v2 manifest and its hash test |
| Deterministic source-only retrieval | full-text and hybrid tests |
| Recall@10/MRR/exact quote availability | v2 report: `1.0` / `1.0` / `1.0` |
| Warm local operation p95 | v2 report: `0.100042 ms`, 50 measured samples |
| Citation/context accounting | expected-quote and serialized-context tests |
| Derived index safety | isolated typed generation, failed rebuild, restart, and ingestion bridge tests |
| Regression and release build | `scripts/verify.sh all`: 41 tests and release build |

## Commands

```text
/bin/zsh scripts/verify.sh retrieval
/bin/zsh scripts/verify.sh retrieval-report
/bin/zsh scripts/verify.sh all
git diff --check
```

## Honest limits and remaining work

- The corpus is synthetic (30 passages, 10 queries). It is not evidence of
  personal-vault or broad real-repository retrieval quality.
- Quote availability is not semantic claim entailment or model-answer
  faithfulness.
- Semantic and entity lanes are protocol boundaries; no embedding or graph
  implementation is claimed.
- CAM-007 model routing and CAM-008 privacy/action cards remain prerequisites
  for cloud context, CAM mining, and mutating workflows.
- The untracked historic v1 report is preserved as recovered invalid
  scaffolding; it is not current retrieval proof.
