# Retrieval Evidence Hardening Implementation Plan

> **For Codex:** REQUIRED SUB-SKILL: Use `executing-plans` to implement this plan task-by-task.

**Goal:** Turn the recovered Task 6 retrieval scaffold into a persistent, deterministic, source-grounded retrieval capability whose frozen evaluation proves the Layer 1 retrieval requirements in `../../GOAL_3Layer.md`.

**Architecture:** Retain the SQLite FTS5 and protocol-backed semantic/entity lanes, but replace the fixture-only evidence path with a validated chunked manifest, explicit citation expectations, typed index fingerprints, and an index builder based on existing ingestion records. Retrieval remains local and deterministic. Embeddings and graph lanes stay protocols until independently proven.

**Tech Stack:** Swift 6.3, Swift Testing, SQLite FTS5, `SQLiteStore`, `ContentStore`, `IngestQueue`, `CryptoKit`, and JSON fixtures.

---

## Preconditions

- Preserve all uncommitted Task 6 files as a candidate baseline.
- Do not edit donor repositories or live CAM databases.
- Treat the current `manifest.json` report as invalid evaluation evidence; do not alter a successor frozen manifest after observing its evaluation output.
- Keep test indexes in temporary directories. Rebuilding or deleting a derived index must never delete source bytes.
- Do not add cloud, external packages, or a mandatory runtime.
- Use the repository-local Swift verification path; consolidate ordinary local checks and never use broad permission bypasses.

### Task 1: Freeze a validated v2 evaluation corpus

**Files:**
- Modify: `Tests/CAMAssistantCoreTests/RetrievalTests.swift`
- Create: `Tests/Fixtures/Retrieval/v2/manifest.json`
- Create: `Tests/Fixtures/Retrieval/v2/README.md`
- Modify: `Sources/CAMAssistantCore/Retrieval/FullTextIndex.swift`

**Step 1 — Write failing validation tests.** Add real tests that reject duplicate source/chunk/query/claim IDs, unknown source or passage references, blank chunks, invalid modality/authority/time values, empty relevance/citation expectations, and unknown manifest versions. Add a passing test asserting all modalities, multi-chunk sources, paraphrases, distractors, and expected citation pairs.

**Step 2 — Verify red.** Run only those tests. Expected failure: no chunked manifest, expected claims/citations, or typed validation exists.

**Step 3 — Implement minimum contract.** Add Codable chunk, expected-claim, expected-citation, and typed validation-error types. Ensure validation runs before any index mutation.

**Step 4 — Freeze fixture before tuning.** Create v2 entirely from approved synthetic/current ingestion fixture material. Include multiple chunks for at least one source, paraphrased queries, distractors, and a contradiction pair. Record source/label rationale and exact SHA-256 in the README. Commit this fixture before evaluating the updated retriever.

**Step 5 — Verify green.** Run focused manifest and current retrieval tests. Expected result: malformed input fails deterministically and v2 is stable.

**Step 6 — Commit.** Commit only the manifest contract, tests, v2 fixture, and README with `test: freeze validated retrieval corpus`.

### Task 2: Build persistent, versioned derived indexes from ingestion

**Files:**
- Modify: `Sources/CAMAssistantCore/Retrieval/FullTextIndex.swift`
- Create: `Sources/CAMAssistantCore/Retrieval/RetrievalIndexBuilder.swift`
- Modify: `Sources/CAMAssistantCore/Ingest/IngestQueue.swift`
- Modify: `Tests/CAMAssistantCoreTests/RetrievalTests.swift`
- Modify: `Tests/CAMAssistantCoreTests/IngestTests.swift`

**Step 1 — Write failing tests.** Test capture → ingest → build → restart → cited search; test generation rebuild without source/provenance loss; test previous generation remains readable after failed rebuild; test every fingerprint dimension mismatch: schema, manifest, tokenizer/preprocessing, chunking, semantic provider/model/dimension, and fusion version.

**Step 2 — Verify red.** Expected failure: the index accepts an anonymous fingerprint string and cannot build from completed ingestion documents.

**Step 3 — Implement minimum generation model.** Add canonical Codable `IndexFingerprint`, deterministic chunking with stable IDs, and `RetrievalIndexBuilder`. It builds into an isolated generation directory, verifies metadata, and atomically promotes only successful generations. Add only the source metadata accessor `IngestQueue` needs; do not duplicate source bytes or make retrieval own ingestion storage.

**Step 4 — Verify green.** Run focused retrieval plus ingestion regression tests. Expected result: restart, rebuild, rollback, and source-survival tests pass.

**Step 5 — Commit.** Commit the index builder, minimal ingestion API, and their tests as `feat: add persistent retrieval index generations`.

### Task 3: Harden deterministic hybrid fusion

**Files:**
- Modify: `Sources/CAMAssistantCore/Retrieval/FullTextIndex.swift`
- Modify: `Sources/CAMAssistantCore/Retrieval/HybridRetriever.swift`
- Modify: `Tests/CAMAssistantCoreTests/RetrievalTests.swift`

**Step 1 — Write failing tests.** Require documented lexical normalization; per-lane deduplication; deterministic handling of non-finite/missing candidates; stable tie ordering; preserved source provenance when semantic candidates join lexical results; and bounded age-based recency rather than epoch division.

**Step 2 — Verify red.** Expected failure: duplicate/non-finite lane scores are accepted and lexical explanation is rank-only.

**Step 3 — Implement minimum safe fusion.** Validate finite candidate scores, deduplicate each lane, expose the chosen lexical normalization, define bounded recency, and retain deterministic ordering. Do not claim an embedding implementation exists.

**Step 4 — Verify green and commit.** Run focused ranking tests, then commit as `feat: harden deterministic hybrid retrieval`.

### Task 4: Make context and citation evidence non-tautological

**Files:**
- Modify: `Sources/CAMAssistantCore/Retrieval/ContextAssembler.swift`
- Modify: `Sources/CAMAssistantCore/Retrieval/CitationVerifier.swift`
- Modify: `Tests/CAMAssistantCoreTests/RetrievalTests.swift`

**Step 1 — Write failing tests.** Require context accounting to include citation metadata, separators, and estimator version; prevent Unicode/metadata overhead from exceeding the stated budget; verify frozen expected citations against retrieved context; distinguish exact quote availability from semantic entailment; reject forged/negated claims; and mark no-relevant-hit queries unanswered even if irrelevant results exist.

**Step 2 — Verify red.** Expected failure: support is currently a source-text tautology, an unanswered query requires an empty result list, and context excludes overhead.

**Step 3 — Implement narrow deterministic verification.** Add a serializable context format with all budget overhead. Keep verification to passage identity and exact quote support, name that limitation explicitly, and calculate expected citation availability from v2 claims against retrieved context rather than matching a loaded source to itself.

**Step 4 — Verify green and commit.** Run citation/context tests and commit as `feat: make retrieval context and citation evidence auditable`.

### Task 5: Benchmark and receipt the frozen retrieval capability

**Files:**
- Modify: `Sources/CAMAssistantCore/Retrieval/CitationVerifier.swift`
- Modify: `Sources/CAMAssistantCLI/main.swift`
- Modify: `scripts/evaluate-retrieval.swift`
- Modify: `Tests/CAMAssistantCoreTests/RetrievalTests.swift`
- Create: `docs/evidence/task-06-retrieval-methodology.md`
- Update: `docs/evidence/task-06-retrieval-report.json`

**Step 1 — Write failing report tests.** Require report fields for manifest/fingerprint/evaluator version, index size, runtime/build identity, query count, warm-up/repetition counts, operation definition, latency distribution, Recall@10, MRR, exact-citation availability, unanswered/empty query IDs, and per-modality failures. Require invalid manifest or metric failure to be reported distinctly.

**Step 2 — Verify red.** Expected failure: the evaluator times one retrieval per tiny query and lacks reproducibility metadata and a real citation metric.

**Step 3 — Implement benchmark configuration.** Define warm-up and measured repetitions. Time the documented warm local operation: retrieve, assemble context, and verify expected citations. Record build/runtime identity and on-disk index size. Keep `cam-assistant evaluate-retrieval MANIFEST OUTPUT` pure local: explicit paths, temporary index cleanup, no vault/network/CAM access.

**Step 4 — Evaluate v2 without label changes.** Save methodology and report. Preserve negative evidence if a metric fails; repair implementation/configuration only, never frozen labels.

**Step 5 — Verify aggregate.** Run focused tests, full tests, release build, CLI evaluator, evidence secret scan, and `git diff --check`.

**Step 6 — Commit.** Commit as `feat: add evidence-backed cited retrieval`.

### Task 6: Record truthful Task 6 completion state

**Files:**
- Modify: `PROGRESS.md`
- Modify: `TASK_QUEUE.md`
- Modify: `DECISIONS.md` only if index-generation/citation semantics need a durable decision
- Create: `docs/evidence/task-06-retrieval.md`

**Step 1 — Audit requirements.** Map every Task 6 and Layer 1 retrieval requirement to a current test, saved report, or explicit limitation.

**Step 2 — Save receipt.** Record initial red state, v2 hash/provenance, exact commands, metrics, environment, branch/commit/dirty state, limitations, and rollback/source-survival evidence.

**Step 3 — Update truth only from evidence.** Mark CAM-006 complete only if all retrieval gates pass. Otherwise retain pending status with exact missing evidence. Do not enable cloud context, CAM mining, or mutating orchestration on a partial result.

**Step 4 — Commit.** Commit the documentation receipt as `docs: record verified retrieval evidence`.
