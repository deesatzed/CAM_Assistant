# Meaning Preview Evaluation V1

This directory is the pre-observation, synthetic Meaning Preview evaluation.
It is a product-contract fixture, not human-pilot evidence and not evidence
that a model or MeaningCore solves a human need.

`manifest.json` freezes:

- 22 cases covering practical distinctions, explicit silence, correction,
  wrong timing, pressure, and faux-self-help behavior;
- evidence and counterevidence for every case;
- exact expected decisions and required evidence selections;
- prohibited moral, diagnostic, destiny, ideal-self, motive, productivity,
  debt, pressure, engagement, and abandonment language;
- six thresholds, all fixed at `1.0` before any named-model observation.

The offline deterministic replay is deliberately self-consistency proof. It
shows that the schema, labels, evidence roles, prohibited-language scanner,
metrics, reporting, and exit-code boundary work. It does not measure model
quality. ADD2CAM-40 may evaluate a named loopback-only model against this exact
fixture, but must not edit V1 after observing output.

Run:

```zsh
/bin/zsh scripts/verify.sh meaning-preview
shasum -a 256 Tests/Fixtures/MeaningPreview/v1/manifest.json
```

The canonical digest is recorded in
`docs/evidence/add2cam-08-reflective-evaluation.md` after green verification.
