# Repository Semantic Evaluation v1

This frozen synthetic corpus evaluates whether repository semantic candidates
remain bound to exact commit/file/line/symbol evidence, cite required
counterevidence, cover the expected concepts, and explicitly abstain when the
available evidence cannot support an answer.

It was frozen before implementing the semantic evaluator or asking any model
the cases. It contains no personal-vault material, donor-repository source,
credentials, or web content.

Frozen manifest SHA-256:
`039cf0792d2c362321f039fc28abdeff9e8bafd3e1f53c693299841496b5d23c`.

The required-concept matcher is a deterministic lexical contract, not a claim
of general semantic entailment. Do not alter this version after observing
evaluator or model results; create `semantic-v2` instead.
