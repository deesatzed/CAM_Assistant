# Task 13 Generated-Answer Evaluation

**Date:** 2026-07-28
**Status:** Best installed model passes every frozen quality and abstention
check; the product gate remains red on latency only.

## Contract

`Tests/Fixtures/Conversation/generated-v1/manifest.json` was frozen before any
listed model saw its questions. Its SHA-256 is
`5eff382987e236994bc755c9107c169fda1896c99cbb4c353dad64ad1e8006ae`.
It contains seven approved product-contract passages, six answer cases, and one
unsupported hardware case.

The measured operation is retrieval, bounded context assembly, selected
loopback-model generation, exact context-citation validation, and deterministic
claim checking. Frozen gates are:

- Recall@10 at least `0.85`
- MRR at least `0.70`
- cited-claim support at least `0.95`
- abstention accuracy exactly `1.0`
- warm end-to-end p95 below `500 ms`
- no failed case

Claim checking requires at least 50% normalized expected-claim token coverage
and every frozen expected passage ID. This is a deterministic regression rule,
not semantic entailment and not an LLM judge.

## Live results

All valid live runs used an OpenAI-compatible service bound to loopback. No
authorization header, cloud provider, web service, personal vault content, or
donor-repository content was used.

| Run | Recall@10 | MRR | Claim support | Abstention | p95 ms | Gate |
|---|---:|---:|---:|---:|---:|---|
| Ollama `llama3.2:1b`, baseline structured prompt | 1.00 | 1.00 | 0.00 | 0.00 | 612.40 | Fail |
| Ollama `llama3.2:1b`, JSON Schema | 1.00 | 1.00 | 0.3333 | 0.00 | 667.96 | Fail |
| Ollama `llama3.2:1b`, JSON Schema plus exact passage-ID enum | 1.00 | 1.00 | 0.3333 | 0.00 | 619.73 | Fail |
| Ollama `ornith:9b`, baseline structured prompt | 1.00 | 1.00 | 0.00 | 1.00 | 60,614.74 | Fail |
| LM Studio MLX `vibethinker-3b-optiq-5bpw-mlx`, exact-ID schema | 1.00 | 1.00 | 0.1667 | 1.00 | 1,393.37 | Fail |
| LM Studio `gemma-4-12b-it-optiq`, exact-ID schema | 1.00 | 1.00 | 1.00 | 1.00 | 2,010.38 | Fail: latency |

The saved machine-readable reports contain case-level answers, cited passage
IDs, failures, runtime/model/endpoint identity, latency distributions, and
frozen thresholds. They were preserved exactly as generated before the
serialized `meetsFrozenThresholds` field was added; every archived result is a
failure when evaluated against its embedded thresholds and non-empty failure
list. New reports serialize that verdict directly.

The first `llama3.2:1b` report was generated while the Ollama process was inside
the managed sandbox. Metal command-queue creation failed and every generation
returned HTTP 500. It is retained as a separate invalid-environment receipt and
is excluded from the model comparison above.

Archived report SHA-256 values:

| Report suffix | SHA-256 |
|---|---|
| `llama3.2-1b-report.json` | `cf765aad7111120669db44ac821ee87fac0d888e8acab2350f3b74e44efe2722` |
| `llama3.2-1b-metal-report.json` | `8ca39ae0a5bd36490e599d4210d9c0fd5a6709279b35f230d6c4eeddf4e62493` |
| `llama3.2-1b-json-schema-report.json` | `87e9b1fe0b2cf6ed021c6bab0d7086d7766a69f9093cffe8412072aa3c8d49a4` |
| `llama3.2-1b-exact-id-report.json` | `08f04bee90c0e90437a7d99fd398f4cb611f9ed4bc978c7c6dab4a55cdd121ba` |
| `ornith-9b-metal-report.json` | `cbf0e96b7b3aa75dab0554c867a5006efa77fb9edc95ea17cdbdcf12a52b227c` |
| `vibethinker-3b-mlx-report.json` | `d934ca4e1d5f746e268a1f6611f1ecd233a79741165ec332a3f504d266944a78` |
| `gemma-4-12b-optiq-report.json` | `fd18e613f1dc0e2d87cdaf9b85302e1198150a9c43258605f9dfb70f1b81db4a` |

## Implementation outcome

- Generated-answer requests now use a JSON Schema with exactly `answer` and
  `passage_ids`, reject extra properties, constrain passage IDs to the current
  context, cap output at 256 tokens, and use deterministic seed/temperature
  settings.
- Only an empty answer with an empty citation list is an explicit abstention.
  Mixed empty/non-empty states fail closed.
- Explicit abstention remains low-confidence, identified by model and endpoint,
  ephemeral, uncited, and ineligible for task promotion.
- `cam-assistant evaluate-generated` writes the full report even when a valid
  run fails quality gates. `scripts/verify.sh generated` reproduces the
  deterministic contract tests without requiring a model service.

Example live invocation:

```sh
swift run --scratch-path .swift-build cam-assistant evaluate-generated \
  Tests/Fixtures/Conversation/generated-v1/manifest.json \
  docs/evidence/generated-report.json \
  MODEL_ID \
  http://127.0.0.1:PORT/v1 \
  --warmup 1 \
  --measured 3
```

## Limitations and next decision

The current deterministic retriever passes this narrow corpus, but no tested
model meets the complete generated-answer gate. The 12B Gemma candidate is the
first tested model to pass all six answer cases, the unsupported-case
abstention, exact citations, and deterministic claim support across 21 measured
samples. Its `2,010.38 ms` p95 is about four times the frozen `<500 ms` limit,
so it is usable for the packaged local-chat workflow but cannot close the
frozen performance gate.

CAM-013 therefore remains in progress. Preserve v1 unchanged. The next safe
model track is a versioned v2 experiment that separates human-usable response
latency from a fast deterministic retrieval gate, or tests a constrained
evidence-composition strategy without weakening the existing receipt.
