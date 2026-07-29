# Repository Semantic V3 and Native Mining Design

**Date:** 2026-07-29

**Status:** Approved refinement of the existing evidence-first semantic
repository design. V1 and V2 remain immutable evidence. V3 is pre-registered
before any named-model run.

## Outcome

CAM Assistant can ask one explicitly selected loopback local model to propose
an ephemeral repository hypothesis from a clean, commit-addressed evidence
bundle. The result names a closed claim category, cites exact supporting and
limiting evidence, exposes confidence and model identity, and can abstain.
Nothing is retained, promoted, copied, or executed without a later explicit
user action.

V3 also provides a frozen synthetic evaluation that measures semantic claim
selection without matching model prose against phrases observed after a run.

## Why V3

V2 proved snapshot, evidence, counterevidence, identity, structured-output,
abstention, and failure plumbing. A live Gemma run also exposed two independent
contract defects:

1. empty JSON-Schema enums prevented inference for abstention cases; this is
   repaired without changing V2;
2. free prose was accepted only when it contained frozen literal phrases, so a
   semantically correct answer could fail for wording alone.

Adding phrases after seeing model output would invalidate the evaluation.
V3 instead evaluates closed claim identifiers selected from a catalog that
also contains plausible distractors.

## Alternatives

1. **Add more accepted phrases to V2 — rejected.** This is post-hoc label
   tuning and remains brittle.
2. **Use another model as a semantic judge — rejected.** It adds cost,
   nondeterminism, circular authority, and a new route.
3. **Closed claim catalog plus exact evidence — selected.** The local model
   chooses claim identifiers and citations from bounded catalogs.
   Deterministic code validates identity, selection, evidence, metrics, and
   abstention. Free prose is presentation only.

## Frozen V3 contract

V3 uses separate types and a separate fixture. It never rewrites or silently
migrates V1/V2.

Each observation case contains:

- an immutable synthetic snapshot and license;
- a question;
- a claim catalog with supported claims and same-topic distractors;
- hidden required claim identifiers;
- bounded exact evidence with hidden expected support/counterevidence roles;
- hidden required support and counterevidence identifiers.

The generator receives the question, claim catalog, and evidence citations,
but not the expected outcome, required identifiers, or evidence roles.

It returns exactly:

```text
statement
claim_ids
support_ids
counterevidence_ids
confidence
```

V3 measures:

- claim recall;
- claim precision;
- support-evidence precision;
- counterevidence recall;
- abstention accuracy.

Every metric threshold is frozen at `1.0` for the small synthetic corpus.
Unknown, duplicate, cross-role, missing, or distractor selections cannot pass.

## Native repository analysis

A runtime bundle builder accepts only an explicitly inspected clean snapshot.
It reads bounded committed lines through Git, never the working tree, and
produces neutral evidence records with stable identifiers, exact commit, path,
line, symbol, and excerpt.

The runtime claim catalog is a small documented taxonomy:

- declared architecture boundary;
- declared dependency;
- explicit implementation gap;
- test-backed behavior;
- operational limitation;
- reusable design candidate.

The model may select applicable categories and exact evidence. Runtime
validation proves structure, identity, snapshot binding, known IDs, confidence,
and non-overlapping citations. It does not upgrade the hypothesis into truth.

The native Repositories workspace shows:

- analysis status and cancellation;
- selected local model and loopback endpoint identity;
- statement and claim categories;
- support and limiting citations;
- confidence;
- explicit abstention or failure;
- explicit Keep, Reject, local task, research plan, or Codex-plan proposal.

Generation never invokes CAM, Codex, a provider, the web, a remote clone, or a
repository write.

## Error and authority boundaries

- Dirty, missing, changed, or unbounded snapshots fail before transport.
- The selected local model must health-check and remain identical.
- Redirects, authorization headers, remote endpoints, unknown response keys,
  oversized data, and unsupported IDs fail closed.
- Cancellation produces no candidate and no normal success receipt.
- An abstention has empty statement and empty claim/evidence lists.
- A non-abstaining runtime candidate requires support and limiting evidence.
- Repository bytes and model prose are not written into audit receipts.
- Keep and promotion reuse the existing idea-card validation and revalidate
  the snapshot and license.

## Proof

Completion of this slice requires:

1. an immutable V3 fixture hash recorded before any named-model run;
2. deterministic perfect, distractor, role-swap, unknown-ID, and abstention
   evaluator tests;
3. strict loopback transport tests with hidden labels/roles;
4. a named live-model V3 receipt preserved whether it passes or fails;
5. a packaged clean-repository journey with before/after Git status and byte
   hashes;
6. explicit ephemeral, Keep/Reject, and promotion behavior in the native UI;
7. aggregate, privacy, package, and clean-clone verification.

