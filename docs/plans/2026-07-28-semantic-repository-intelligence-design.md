# Semantic Repository Intelligence Design

**Approved:** 2026-07-28

## Outcome

CAM Assistant may propose useful semantic observations and repository ideas
from an explicitly selected, clean, commit-addressed repository without
turning model prose into truth. Every accepted observation remains a
snapshot-bound candidate with exact supporting and counterevidence citations,
confidence, license context, and an explicit abstention path.

This closes the gap between the existing literal marker/symbol/import
extractors and the user's desired repository-and-idea mining capability while
preserving the local vault, repository non-mutation, and explicit-promotion
boundaries.

## Alternatives considered

1. **Deterministic extraction only.** Keep adding regexes and syntax patterns.
   This is reproducible and safe but cannot form cross-file behavioral or
   design hypotheses. It remains the authoritative evidence substrate, not
   the complete semantic capability.
2. **Model output or model-as-judge.** Ask a model to describe a repository and
   score its own work. This is flexible but too easy to hallucinate, omit
   counterevidence, drift between runs, or produce persuasive unsupported
   prose. It is rejected as an authority path.
3. **Evidence-first hybrid — approved.** Deterministic code selects immutable
   commit-cited evidence. An explicitly selected loopback local model may
   propose a structured candidate. A deterministic validator accepts only
   candidates whose citations, counterevidence, snapshot identity, source
   excerpts, confidence, and abstention behavior satisfy a frozen contract.

## Architecture

### Frozen evaluation contract

`Tests/Fixtures/Repositories/semantic-v1/manifest.json` is frozen before an
analyzer is implemented or a model is asked its cases. Each case contains:

- one synthetic clean snapshot identity;
- exact source records with stable evidence IDs, commit, path, line, symbol,
  role, and source excerpt;
- an observation prompt;
- either an expected observation contract or required abstention;
- required semantic concepts rather than one exact prose rendering;
- required supporting and counterevidence IDs;
- thresholds for observation recall, citation precision, counterevidence
  coverage, abstention accuracy, and invalid-candidate rejection.

The fixture contains no personal vault content, donor source, credentials, or
network-acquired material. Changing observed labels requires a new version.

### Candidate generation

A `RepositorySemanticCandidateGenerator` receives only the bounded evidence
bundle for one case. Its output is one of:

- a structured candidate with statement, support IDs, counterevidence IDs,
  confidence, model/runtime identity, and ephemeral retention; or
- an explicit abstention with empty statement and no citations.

The production generator uses only an explicitly configured loopback local
model and performs a separate model health/identity check. It sends no
authorization header, follows no redirects, and never falls back to cloud,
web, CAM, or another model. A deterministic scripted generator is used only
to prove the evaluator contract.

### Deterministic validation

The validator, not the model, decides whether a candidate is eligible:

1. snapshot commit must match the frozen/selected snapshot;
2. every cited ID must exist and have the correct support or counterevidence
   role;
3. each citation must preserve exact commit, file, line, symbol, and excerpt;
4. observation text must cover the case's frozen required concept groups;
5. all required supporting and counterevidence IDs must be present;
6. confidence must be finite and between zero and one;
7. unknown, duplicate, mismatched, or role-swapped evidence fails closed;
8. abstention is valid only when statement and all evidence lists are empty.

An accepted candidate is still not truth. It may be displayed as ephemeral or
converted into the existing `RepositoryIdeaCard` only through an explicit user
action. Keep/reject/task/research/Codex-plan behavior remains separately typed.

### Evaluation and receipts

The evaluator runs the frozen cases through a supplied generator and emits a
sorted, deterministic report containing manifest hash, evaluator version,
runtime/model identity, case results, failures, unanswered cases, and metrics.
A checked-in receipt may claim the frozen synthetic contract only; a separate
live local-model receipt records the selected model and actual results.

Passing the synthetic evaluator proves that validation catches grounded,
ungrounded, and abstention cases. Passing a live-model run proves that one
named local runtime met that frozen contract. Neither result proves arbitrary
repository correctness, SOTA reasoning, safe code reuse, or license
compatibility.

## Data and authority flow

```text
selected clean snapshot
  -> deterministic bounded evidence bundle
  -> explicit loopback candidate generation
  -> deterministic citation/counterevidence/abstention validation
  -> ephemeral semantic candidate
  -> explicit Keep/Reject or typed proposal promotion
```

Repository bytes remain read-only. The analyzer stores no source bytes in
receipts, makes no repository writes, and grants no CAM/Codex execution
authority.

## Failure and recovery

- Dirty, missing, stale, or mismatched snapshots fail before generation.
- Missing or unhealthy selected local models fail visibly.
- Invalid JSON, model identity drift, unknown evidence, unsupported prose,
  missing counterevidence, or malformed abstention produces a failed case,
  never an accepted candidate.
- Cancellation and later rerun operate on the same immutable case/snapshot.
- Failed candidates remain status-only evaluation evidence and cannot be
  promoted.

## Proof boundary

This design advances the semantic-evaluation portion of CAM-015. The full
repository goal additionally requires broader intake coverage, saved
non-mutation proof for every lifecycle path, complete idea-card fields,
retained research-packet promotion, and live bounded CAM/Codex coordination.

