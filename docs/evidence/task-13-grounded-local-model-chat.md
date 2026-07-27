# CAM-013 Grounded Selected Local-Model Chat Receipt

**Date:** 2026-07-27
**Status:** Adapter and native interaction verified; live model and generated-claim evaluation remain open.

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
| `CAM_ASSISTANT_SKIP_FRESH_CLONE=1 /bin/zsh scripts/verify.sh all` | PASS — 165 tests; native app and CLI release builds |
| `/bin/zsh scripts/verify.sh package` | PASS — production app built and `Info.plist` validated |
| `/bin/zsh scripts/verify.sh smoke` | PASS — packaged native offline smoke |
| `git diff --check` | PASS |

The focused tests cover selected-model health identity, exact request shape,
exact citation binding, absent/unknown evidence refusal, HTTP failure, model
identity drift, redirect refusal, and conversion to an identified ephemeral
conversation response.

## Honest remaining boundary

`cam-assistant models current` reported no active local model profile, and no
compatible model service was listening at the candidate local ports during
this verification. Therefore this receipt does **not** claim:

- a real-model answer;
- generated-claim faithfulness or semantic entailment;
- warm end-to-end generation latency;
- packaged GUI interaction with a live selected model; or
- support for every vendor-specific local-model API.

Those are remaining CAM-013 proof gates. Their absence does not disable the
verified offline capture, retrieval, extractive chat, Library, or other local
foundation.
