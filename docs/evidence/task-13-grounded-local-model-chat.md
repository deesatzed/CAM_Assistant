# CAM-013 Grounded Selected Local-Model Chat Receipt

**Date:** 2026-07-28
**Status:** Live packaged selected-model interaction verified; the frozen
generated-answer gate remains red on latency.

## Implemented boundary

- The selected assignment must be local and must use `localhost`,
  `127.0.0.1`, or `::1`; credentials, query strings, and fragments are
  rejected.
- Health uses `GET /models` and succeeds only when the selected model identity
  is present.
- Generation uses `POST /chat/completions`, sends no authorization header,
  disables streaming and sampling, and rejects every redirect.
- The response model must exactly match the selected model.
- Generated output must contain a non-empty answer and unique passage IDs that
  exactly match the current bounded local retrieval context. Unknown or absent
  evidence fails closed.
- The native chat surface requires a successful selected-model health check,
  displays route/model/endpoint identity, and offers no automatic cloud, web,
  CAM, or alternate-model fallback.
- Accepted output is ephemeral until an existing explicit promotion action.

## Verification

| Command | Result |
|---|---|
| `/bin/zsh scripts/verify.sh models` | PASS — 6 focused local-inference tests |
| `CAM_ASSISTANT_SKIP_FRESH_CLONE=1 /bin/zsh scripts/verify.sh all` | PASS — 189 tests; native app and CLI release builds |
| `/bin/zsh scripts/verify.sh package` | PASS — production app built and `Info.plist` validated |
| `/bin/zsh scripts/verify.sh smoke` | PASS — packaged native offline smoke |
| `git diff --check` | PASS |

The focused tests cover selected-model health identity, exact request shape,
exact citation binding, absent/unknown evidence refusal, HTTP failure, model
identity drift, redirect refusal, and conversion to an identified ephemeral
conversation response.

## Live packaged proof

- An isolated application-support root selected profile `gemma-local` revision
  1 with model `gemma-4-12b-it-optiq` at
  `http://127.0.0.1:1234/v1`.
- Native Settings explicitly health-checked the loopback identity and reported
  local answers ready while CAM and cloud roles remained unavailable.
- A harmless synthetic clipboard source completed ingestion and appeared as
  one active Library source.
- The first packaged attempt exposed a real integration defect: live chat used
  an all-question-token substring filter instead of the verified retrieval
  generation. The TDD regression failed on empty context and the absent
  `active-generation.json` receipt.
- The corrected database-backed chat path rebuilt/opened the persistent
  `RetrievalIndexBuilder` generation and ranked through `HybridRetriever`.
  The rebuilt package answered, “Yes, CAM Assistant keeps raw vault material
  and secrets local,” with supported confidence, exact `source#0` citation,
  model identity, and endpoint identity.
- `Open in Library` navigated from the generated citation to the one active
  isolated source. The answer remained ephemeral; Keep was available but was
  not invoked.
- The normal vault was not used or modified by this valid journey. No cloud,
  web, CAM, authorization header, credential, or personal content was used.

## Honest remaining boundary

The packaged selected-model journey is closed for the tested LM Studio
OpenAI-compatible loopback adapter. The separately frozen v1 evaluator records
perfect retrieval, claim support, and abstention for this model, but p95 is
`2,010.38 ms`, above the `<500 ms` gate. This receipt therefore does not claim
the frozen performance threshold, arbitrary semantic entailment, support for
every local-model API, or a native in-process MLX runtime.

Those remaining boundaries do not disable the now-verified packaged local
capture, retrieval-generation, selected-model answer, exact citation, and
Library navigation workflow.
