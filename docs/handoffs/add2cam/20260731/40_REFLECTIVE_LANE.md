# ADD2CAM-40 Reflective Lane Handoff

## Identity

- Prerequisite integration commit: `c0dbe01`
- Branch: `agent/add2cam-40-reflective-lane`
- Worktree: `/private/tmp/cam-add2cam-20260731/reflective-lane`
- Implementation commits: `f1014da`, `8ae9eff`, `c18936d`, `79cb78f`
- Final hardening commits: `0f27802`, `78c126c`, `843edbb`, `f6f5292`
- Frozen manifest SHA-256: `62cfed6293462f94103752e1d3855158675f479b5ae6cf7926ed20e4726cabfd`

## Delivered boundary

- `evaluate-meaning-preview-model MANIFEST OUTPUT` is a distinct named-model
  path. The offline `evaluate-meaning-preview` replay remains ineligible for
  named-model admission.
- A selected `ModelAssignment` must identify an exact OpenAI-compatible
  loopback origin. The feature-local transport disables proxies, cookies,
  caches, credentials, authorization, and redirects.
- One cached `GET /models` verifies the selected identity before candidate
  requests. Completion identity, assistant-message shape, domain, candidate
  keys, selected IDs, and output bounds are strict and fail closed.
- Native reflection is an explicit user-pull operation over two to eight
  explicitly selected, current, permitted contexts. A single item abstains;
  restricted or secret-like context blocks before transport.
- The named report, canonical digest, evaluator result, current assignment,
  endpoint identity, and report age form one typed admission. Missing, stale,
  failed, or mismatched evidence leaves reflection unavailable.
- CAM-owned grounding and prohibited-behavior checks run before MeaningCore.
  MeaningCore makes the final deterministic admission decision. Candidate
  prose is ephemeral and never advances or persists practical Preview state.
- Disable, permission revocation, cancellation, and selection changes invalidate
  in-flight reflective results. A model failure disables only reflection;
  deterministic practical Preview remains available without fallback.

## TDD and review corrections

The initial RED suite failed because the supplier, coordinator reflection API,
named-model request/report, and native runtime seam did not exist. Subsequent
adversarial review rejected the first pass until it added:

- explicit no-proxy/cookie/cache/credential transport policy;
- canonical frozen-byte validation before transport and swap-race protection;
- exact domain, assignment, runtime, report-age, and 22-case admission binding;
- permission-first lazy resolution with post-await lease/generation checks;
- nonempty, known, unique, disjoint support and counterevidence;
- runtime grounding, polarity, pressure, diagnostic, moral, destiny, motive,
  faux-self-help, and imperative rejection;
- honest `verified_partial` behavior when no admitted model is available.
- executable transport-policy proof and an executable SHA-256 binding from the
  exact report bytes to a separately trusted build-time digest. A changed or
  fabricated report now fails before source resolution or transport.

All accepted findings were implemented. No donor, MeaningCore, frozen fixture,
threshold, module manifest, package script, or unrelated model route was
modified.

## Named-model evidence

Command:

```zsh
./.swift-build/debug/cam-assistant \
  evaluate-meaning-preview-model \
  Tests/Fixtures/MeaningPreview/v1/manifest.json \
  docs/evidence/add2cam-09-named-model-report.json
```

Observed report:

- `manifestHash`: canonical frozen digest above
- `runtimeAvailable`: `false`
- `reflectionEnabled`: `false`
- `modelID`: `none`
- `runtimeIdentity`: `none`
- `errorCode`: `selected_model_unavailable`
- deterministic replay was not substituted
- process exit status: `2`

This is honest failing evidence, not a quality result. No model or network was
invoked by this run. The controlling goal therefore permits only the practical
pilot lane.

## Verification surface

Focused proof commands:

```zsh
swift test --disable-sandbox --scratch-path .swift-build \
  --filter MeaningPreviewReflectionTests
swift test --disable-sandbox --scratch-path .swift-build \
  --filter MeaningPreviewAppModelTests
swift test --disable-sandbox --scratch-path .swift-build \
  --filter MeaningPreviewEvaluationTests
/bin/zsh scripts/verify.sh privacy
/bin/zsh scripts/verify.sh meaning-preview
git diff --check
```

The core focused suite proves the canonical 1 GET + 22 POST named evaluation,
strict schema/identity/domain behavior, digest swap resistance, exact admission,
grounding/prohibition, abstention, no persistence, and no fallback. The app
suite proves explicit selection, practical isolation, no-read-before-access,
cancellation, and disable/revocation suppression.

Fresh final results on 2026-08-02:

- `MeaningPreviewReflectionTests`: 16 passed
- `MeaningPreviewAppModelTests`: 36 passed
- `MeaningPreviewEvaluationTests`: 13 passed
- `scripts/verify.sh app`: 66 passed
- `scripts/verify.sh privacy`: 11 passed across privacy and audit suites
- `scripts/verify.sh meaning-preview`: 13 passed; frozen gates passed with all
  six reported deterministic metrics equal to `1.0`
- `git diff --check`: passed

## Limitations and terminal status

- No current selected loopback assignment was available for a genuine named
  model run, so model quality and latency are not established.
- Reflection remains disabled. It must not be enabled from deterministic replay
  or by manually editing the report.
- Packaging of the report resource and packaged GUI journey belong to Goal 50.
- Synthetic automation is not lived-use or human evidence; Goal 60 remains
  pending human.

Terminal status: `verified_partial`. Practical Meaning Preview may continue to
Goal 50; reflective Meaning Preview is unavailable.
