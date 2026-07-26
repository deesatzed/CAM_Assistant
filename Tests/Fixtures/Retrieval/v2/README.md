# Retrieval Golden Corpus v2

This is the frozen, synthetic mixed-modality contract for CAM-006. It is
designed to test deterministic retrieval behavior without reading personal
data, a live vault, CAM, or the network.

## Freeze record

- Manifest: `manifest.json`
- Schema version: `2`
- Frozen at: `2026-07-25`
- SHA-256: `3172ab92fd1f2122de14f00bfb604d76eeaf11a04319b020c05c69ee5a32ffcb`
- Labels: passage-level relevance plus expected claim/citation/quote pairs
- Status: frozen before running the v2 evaluator

Do not change this manifest, its labels, or its hash after observing evaluator
results. Create a new versioned corpus when the fixture contract must change.

## Corpus rationale

The corpus covers text, Markdown, code, configuration, transcript, PDF, image,
and audio-derived text. Each source has two explicit chunks. Queries include
paraphrases, a multi-passage Atlas answer, a Cedar contradiction that must
retain both dates, and plausible distractors for Atlas, archive, local-model,
and recording questions.

The expected claims are not generated answers. They are frozen assertion
targets, and each one must cite the exact source and passage containing its
quoted support. The evaluator therefore measures citation availability in the
retrieved context separately from passage ranking.

## Limits

This fixture verifies deterministic behavior and regression safety only. It
does not establish real-vault quality, semantic entailment, model-answer
faithfulness, accessibility, or personal usability. Those require separate,
approved evaluation plans and evidence.

The prior v1 `../manifest.json` and its report are retained as recovered
historical scaffolding. They are not current CAM-006 evidence because they had
one short passage per source and reported tautological source provenance rather
than expected-claim support.
