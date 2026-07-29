# Task 15 Repository Semantic Evaluation Evidence

**Date:** 2026-07-28
**Scope:** Frozen evidence/counterevidence/abstention evaluation and explicit
loopback local-model candidate generation
**Status:** Passing bounded contract; live-model and native-repository journey
remain

## Proven behavior

- The synthetic `semantic-v1` corpus remains preserved. Independent review
  required a separately frozen `semantic-v2` before any live-model run. Its
  SHA-256 is
  `5fe3b45ab5bbfdabd08eadf0871348a5830a5d4cd6c2213350be493293f64b25`.
- Four cases contain two cross-file semantic observation contracts and two
  required abstentions. V2 adds four same-role distractors, including
  misleading lexical matches. Every record has an exact synthetic commit,
  file, line, symbol, role, and excerpt; no donor or personal source is
  present.
- Manifest validation rejects unsupported versions, duplicate cases,
  malformed commit/path/line evidence, role mismatches, invalid thresholds,
  and observation/abstention label inconsistencies.
- Candidate validation requires the exact snapshot, finite confidence,
  ephemeral retention, known non-duplicated support and counterevidence,
  required concept groups, and explicit citation-free abstention.
- The evaluator reports observation recall, evidence precision,
  counterevidence recall, abstention accuracy, failed cases, unanswered cases,
  model/runtime identity, per-case status, manifest hash, and a frozen
  threshold verdict in sorted case order. A failed threshold report maps to
  CLI exit status `2` after the report is saved.
- A perfect scripted contract run reaches `1.0` on all four metrics. A
  contaminated run records unknown evidence and an unanswered observation
  separately and cannot pass.
- `RepositorySemanticLocalGenerator` accepts only a local `ModelAssignment`,
  revalidates decoded and construction-time loopback endpoints, requires a
  successful selected-model health check, bounds evidence/request/response
  size, sends no authorization header, requests a strict JSON schema, rejects
  unknown response keys, preserves explicit abstention and cancellation, and
  rejects model drift and unknown evidence.
- The CLI command
  `cam-assistant evaluate-repository-semantic MANIFEST OUTPUT MODEL LOOPBACK_ENDPOINT`
  runs the frozen corpus against one explicitly named loopback model and writes
  an atomic sorted JSON report.
- Only a deterministically validated non-abstaining candidate can form an
  evidence-complete ephemeral idea card. The card binds license provenance
  directly from the validated case and preserves the semantic rationale,
  exact support and counterevidence citations, confidence, rejected
  alternatives, and smallest validation experiment. It is not kept, promoted,
  or executed automatically.
- Existing retained cards remain decode-compatible; newly added semantic
  fields default empty only when decoding legacy records.

## TDD and verification receipts

The required RED runs failed for the absent manifest API, candidate validator,
evaluator/generator protocol, loopback generator, evidence-complete card
conversion, and CLI request parser before each minimal implementation.

Final focused command:

```text
./scripts/verify.sh repository-semantic
```

Result:

```text
50 repository tests passed
```

Read-only endpoint checks:

```text
curl --max-time 3 http://127.0.0.1:1234/v1/models
curl --max-time 3 http://127.0.0.1:11434/v1/models
```

Both previously evidenced local endpoints refused the connection during the
2026-07-28 checkpoint. No live model report was fabricated or relabelled as
passing.

## Named local-model runs — 2026-07-29

LM Studio was started on loopback only at
`http://127.0.0.1:1234/v1`. No authorization header, cloud route, web route,
CAM route, personal data, donor source, or network bind was used.

The frozen v2 manifest remained byte-identical at SHA-256
`5fe3b45ab5bbfdabd08eadf0871348a5830a5d4cd6c2213350be493293f64b25`.
The existing release CLI ran it without code or label changes against:

| Model | Result | Metrics | Receipt SHA-256 |
|---|---|---|---|
| `vibethinker-3b-optiq-5bpw-mlx` | Fail, exit `2` | observation `0`; precision `0`; counterevidence `0`; abstention `0` | `a54184cfdd947c81dfb95bb687449c21bf5536d555aace6bad239bf448bf20c2` |
| `gemma-4-12b-it-optiq` | Fail, exit `2` | observation `0`; precision `0`; counterevidence `0`; abstention `0` | `de721c4c7456cb5a21137b0d6d5714261e5b2566e979491b29aef50878b5216e` |

Saved receipts:

- `task-15-repository-semantic-vibethinker-failed.json`;
- `task-15-repository-semantic-gemma-failed.json`.

The first Vibethinker attempt used a host-only endpoint and failed health
decoding because the CLI correctly treats its argument as the OpenAI-compatible
base URL and therefore requires `/v1`. A loopback diagnostic proxy reproduced
`GET /models`; rerunning with `/v1` completed the evaluator. That invalid
invocation was not saved as a model-quality receipt.

The completed receipts exposed two evaluator/model-contract limitations:

1. For an abstention case with no allowed support or counterevidence IDs, the
   generated JSON Schema contains `enum: []`. LM Studio rejects that schema
   before inference, so both models record `generator_error` rather than a
   valid abstention.
2. Gemma returned the exact required evidence IDs and a semantically correct
   actor/cache limitation, but the frozen deterministic concept matcher
   rejected “Cache actor ensures thread-safe…” because it did not contain the
   literal accepted phrase `actor-isolated` or `actor isolated`.

These observations do not authorize changing v2 after seeing outputs. V2
remains frozen and both reports remain failures. A future separately
pre-registered version may repair empty-ID structured output and measure
semantic claim support without tuning labels to these responses.

After the runs, both models were unloaded and the LM Studio API server was
stopped. No model remained resident.

## Authority and privacy boundary

Deterministic clean-commit evidence remains authoritative. Model output is an
ephemeral candidate. The generator has no cloud fallback, web route, CAM
route, repository mutation, retention, task creation, code-copy, or execution
authority. Reports contain status, identities, metrics, and evidence IDs; the
checked-in fixture contains synthetic excerpts only.

## Non-claims and remaining proof

This does not prove arbitrary semantic correctness, personal-vault quality,
SOTA repository reasoning, license compatibility, or useful results from a
real selected model. The repository semantic gate remains partial until:

1. a named selected loopback model produces a saved frozen report that passes
   a valid pre-registered evidence/counterevidence/abstention contract;
2. the structured-output contract supports valid citation-free abstention;
3. a native clean-repository journey builds bounded exact evidence, presents
   accepted/abstained/failed candidates, and requires explicit Keep or
   promotion;
4. donor bytes and Git status are saved unchanged across that journey.
