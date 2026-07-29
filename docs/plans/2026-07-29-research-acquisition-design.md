# Policy-Gated Research Acquisition V1 Design

**Date:** 2026-07-29

**Status:** Approved finish-plan Task 4 made concrete for implementation. This
design does not authorize provider search, paid APIs, arbitrary browser
control, cloud-model synthesis, background crawling, or automatic retention.

## Outcome

CAM Assistant can deliberately acquire one caller-selected public HTTPS
document for one local research question. Before any DNS or transport work,
the deterministic outbound policy classifies the question and target. The
native UI shows one exact action card; one explicit **Approve & Acquire**
action records and consumes a one-use approval and starts the bounded fetch.

The acquired bytes enter the existing content-addressed vault and ingestion
pipeline with research provenance. The resulting research packet and source
receipt remain ephemeral until the user explicitly keeps or discards them.

## Chosen boundary

V1 is a direct public-document adapter, not a search provider:

- HTTPS only, with an explicit host and no credentials or user information;
- no literal IP, localhost, `.local`, private-network, or non-default-port
  targets;
- same-origin HTTPS redirects only;
- `text/plain`, Markdown, JSON, and PDF documents only;
- a five-megabyte maximum, enforced during streaming;
- an ephemeral URL session with no cookies, credentials, cache, or
  authorization header;
- zero provider cost, with a typed zero-dollar budget and receipt;
- no model request, source discovery, link following, HTML execution, script
  interpretation, or tool invocation.

This is intentionally narrower than a general web researcher. It proves the
complete authority, durability, provenance, cancellation, and retention path
before search-provider or browser scope is considered.

## Alternatives considered

### Provider search first

This would answer open-ended questions sooner, but it adds provider accounts,
keys, pricing, result ranking, query egress, and model/provider coupling before
the acquisition safety path exists. It is deferred.

### Arbitrary browser automation

This handles more sites but substantially expands cookies, authentication,
JavaScript, redirects, downloads, prompt injection, and ambient browser-state
authority. It is deferred.

### Local-document import only

This is safest and reuses existing ingestion, but it does not close the
required outbound acquisition gap. Local import remains available through
existing file and watched-folder capture; V1 adds only the missing public
document boundary.

## Authority and approval

`ResearchAcquisitionRequest` holds the local question, canonical target,
state version, maximum bytes, zero-dollar budget, route, and tool identity.
Its deterministic canonical representation is classified and hashed before a
proposal exists.

`ActionCard.target` binds the exact canonical URL. Its outbound manifest binds
the canonical request digest and state version. The card visibly states:

- the exact public target;
- the question and target data considered for policy;
- the five-megabyte and zero-dollar limits;
- that the local vault, credentials, cookies, and unrelated files are
  excluded;
- cancellation and verification behavior;
- that no external action has occurred before approval.

The native **Approve & Acquire** click is the explicit approval source. It
creates and consumes one exact approval immediately before transport. Resume
after cancellation, interruption, or failure requires a new card with a new
state version; approval is never reused.

## Durable lifecycle

A schema-v9 SQLite `research_acquisition_jobs` table stores a versioned typed
job document plus indexed job ID, status, and update time. It preserves:

- query, canonical target, route, tool, limits, and idempotency identity;
- pending, running, cancelled, failed, and completed state;
- state version, attempt count, safe error code, and resume cursor;
- approval/card identities and consumed-at time;
- request and response byte counts, content digest and content ID;
- start/end time and zero-dollar actual cost;
- canonical/final origin, MIME type, duplicate identity, source-quality
  metadata, and untrusted-content signals.

Raw exception messages, credentials, authorization values, response headers,
source text, prompts, and model output never enter the job record or audit.
The SQLite online backup automatically includes jobs; vault bytes and research
packets already have canonical backup paths.

An app restart changes an unleased `running` job to a safe interrupted failure
that can be resumed. Cancellation is terminal for the current attempt but
resumable under the same job identity and incremented state version. A late
result cannot turn a cancelled job into completed.

## Transport and content

`ResearchAcquisitionTransport` is an injected async protocol. Tests use
deterministic transport spies. The live adapter uses an ephemeral
`URLSession`, streams bytes while enforcing the bound, rejects unsupported
status/MIME/final URLs, and returns only typed response metadata and bytes.

The coordinator writes accepted bytes to the existing `ContentStore` through
`IngestQueue`. A new research capture origin records run ID and canonical URL.
Content identity deduplicates repeat acquisitions without pretending the
second acquisition did not occur; each attempt retains its own receipt and
explicit `wasDuplicateSource` value.

Downloaded material is data, never instructions. No acquired text is passed to
routing, policy, approval, tools, or an LLM during acquisition. Prompt-like
content is recorded as an untrusted-content signal for review but cannot alter
execution.

## Packet and review

`ResearchPacket` gains typed source receipts, contradictions, unanswered
questions, recommendations, and limitations while preserving separately
validated facts and inferences. The acquisition-only packet initially contains:

- the validated source receipt;
- the original question as unanswered;
- an explicit limitation that no model-generated finding was created;
- no fabricated facts, inferences, contradiction, or recommendation.

The native Research workspace shows the proposal, progress, safe lifecycle,
source origin, freshness/quality status, bytes/digest, safety signals,
questions, findings, limitations, and separate **Keep Packet** and **Discard
Packet** actions. Keeping creates a copy whose retention is
`explicitlyKept`; the store refuses to persist a falsely ephemeral label.

## Failure behavior

Policy block, invalid target, stale approval, cancellation, redirect refusal,
HTTP failure, unsupported MIME, size overflow, transport failure, ingestion
failure, and restart interruption remain distinct safe states. No failure
creates a ready packet or reports verified success. Protected policy fixtures
produce zero transport calls and zero outbound bytes.

## Proof

Focused tests must prove:

- exact request/card/approval/transport binding and one transport call;
- zero transport for every protected privacy fixture;
- URL, redirect, MIME, byte, and zero-cost bounds;
- streaming cancellation, restart recovery, reapproval, and safe resume;
- content identity deduplication and research provenance;
- prompt-like content remains inert data;
- complete status-only receipts and source-quality metadata;
- typed packet construction and explicit retained-label Keep/Discard;
- native accepted, blocked, running, cancelled, failed, ready, kept, and
  discarded presentation;
- schema migration, full-vault recovery, privacy, and aggregate regression.

One separately saved live proof may acquire a stable public plaintext
standards document only after the deterministic and injected-transport suites
pass. It must record the exact target, commit, bytes, digest, timing, tool
identity, and limitations without retaining response text in evidence.
