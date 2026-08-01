# ADD2CAM-08 Frozen Reflective Evaluation

## Frozen contract

- Fixture: `Tests/Fixtures/MeaningPreview/v1/manifest.json`
- SHA-256: `62cfed6293462f94103752e1d3855158675f479b5ae6cf7926ed20e4726cabfd`
- Corpus: 22 synthetic cases, including 7 expected surfaces and 15 expected silences.
- Thresholds: decision accuracy, support recall, evidence precision, counterevidence recall, abstention accuracy, and prohibited-behavior accuracy are each frozen at `1.0`.
- Status: synthetic product-contract evidence only. This is not human-use evidence and does not establish model quality.

The fixture was authored and hashed before any named model was invoked. No model or network was used in Goal 30.

## What the evaluator proves

- Strict manifest keys and complete coverage are validated before evaluation.
- Named suppliers receive only neutral case ID, domain, prompt, context, and `{id,text}` evidence; expected decisions, reference answers, evidence roles, required IDs, prohibitions, rationale, and pressure metadata never enter supplier input.
- Evidence identifiers must exist, have the correct support/counterevidence role, be unique, and match the frozen case contract.
- Surface prose must be nonempty, bounded by valid uncertainty, and deterministically grounded in each case's already-frozen reference fields; correct IDs plus meaningless prose fail.
- Prohibited behavior checks are case-scoped and include exact frozen phrases plus pre-model semantic patterns for paraphrased pressure, moral scoring, and diagnosis.
- Missing candidates, identity mismatch, invented evidence, duplicate identifiers, malformed silence, and invalid uncertainty produce stable fail-closed error codes.
- Deterministic replay is explicitly labeled `deterministicReplay`, model identity `none`, and `namedModelEligible: false`, even when all self-consistency thresholds pass.
- A genuine named-model evaluation is separately labeled `namedModel` and is eligible only with nonempty runtime/model identity plus every frozen threshold passing.
- Reports contain status, metrics, identifiers, and error codes, but never candidate prose.

## Verification

```zsh
swift test --disable-sandbox --scratch-path .swift-build-goal30 \
  --filter MeaningPreviewEvaluationTests
/bin/zsh scripts/verify.sh meaning-preview
shasum -a 256 Tests/Fixtures/MeaningPreview/v1/manifest.json
git diff --check
```

Observed result:

- 13 focused evaluator tests passed.
- The repository-owned `meaning-preview` verifier passed the same 13 tests and the offline CLI replay.
- Replay metrics were all `1.0`; `meetsFrozenThresholds` was true while named-model eligibility remained false by construction.
- The exact fixture digest matched the value above.
- Diff check passed.

## Boundary and limitations

The offline command `evaluate-meaning-preview MANIFEST OUTPUT` is intentionally deterministic replay. It proves schema, scoring, report, and exit-code consistency; it cannot approve a model. Goal 40 owns the separate selected-loopback model path and must preserve any failed report with process status `2`.

Semantic grounding is a deterministic lexical contract against frozen references, not a general entailment metric. It blocks vacuous and weakly related text but does not prove lived usefulness. The human gate remains Goal 60.
