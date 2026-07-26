# CAM-006 Retrieval Evaluation Methodology (v2)

## What was measured

The local evaluator runs the frozen v2 corpus at
`Tests/Fixtures/Retrieval/v2/manifest.json`:

- SHA-256: `3172ab92fd1f2122de14f00bfb604d76eeaf11a04319b020c05c69ee5a32ffcb`
- 30 chunked passages across text, Markdown, code, configuration, transcript,
  PDF, image, and audio-derived text
- 10 passage-level queries with frozen relevance and exact
  claim/citation/quote expectations
- 3 unmeasured warm-up runs and 5 measured runs per query (50 latency samples)
- operation timed: `retrieve+context+exact-citation-availability`

The evaluator creates a temporary local SQLite FTS5 index, runs deterministic
hybrid retrieval, serializes budgeted context including citation metadata, and
checks whether every expected quote is present in its cited retrieved passage.
It neither reads a vault nor uses the network, CAM, cloud models, credentials,
or a live database.

Run it through the project-local verifier:

```text
/bin/zsh scripts/verify.sh retrieval
/bin/zsh scripts/verify.sh retrieval-report
```

The current machine-specific receipt is
`task-06-retrieval-v2-report.json`. It records the exact index fingerprint,
runtime identity, warm-up/repetition counts, latency distribution, per-query
results, no-result queries, no-relevant-hit queries, and per-modality failures.

## Interpretation

`citedClaimQuoteSupport` means **exact citation availability**. It proves that
an expected quote appeared in the retrieved source and passage; it does not
prove that arbitrary generated language is semantically entailed by that quote.
The local generation/chat layer must preserve this distinction and must not
promote this measure to a general factuality claim.

The result is a deterministic synthetic-fixture regression result, not a
personal-vault, real-repository, semantic-retrieval, model-answer, or “SOTA”
claim. A larger separately approved and frozen corpus, user-study evidence,
and model-answer evaluation remain required before making those claims.

The prior `task-06-retrieval-report.json` is retained as historical recovered
scaffolding. It used the v1 one-passage corpus and tautological source
provenance, so it is not current CAM-006 proof.
