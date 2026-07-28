# Policy-Gated Research Acquisition Gap Audit

**Date:** 2026-07-28  
**Status:** Read-only implementation inventory. Live source acquisition is not
implemented or proven.

## Scope

This audit compares the current local research coordinator, route/policy
foundation, packet retention store, native Research view, and focused tests
with the CAM-014 and `GOAL_FINISH_WIKI.md` research-acquisition gates. It
inspects repository-owned code and synthetic fixtures only at commit
`9a2ca1bea135ae7b3fcf522595cce757cc945071`.

## What is currently real

- A local research run validates unique nonblank queries and begins
  `planned` with a versioned checkpoint.
- Resume requires the expected checkpoint version and advances to
  `collecting`.
- Repository-idea promotion can preserve commit-cited provenance,
  counterevidence, confidence, and a validation experiment in a local plan.
- Facts and inferences are typed separately.
- Facts must carry exact citations available in the supplied local
  `ContextBundle`; forged citations fail.
- Inferences must reference one or more verified fact IDs in the same packet.
- Plans remain in memory until the user explicitly selects Keep.
- `ResearchPlanStore` and `ResearchPacketStore` use atomic local JSON writes
  and have restart tests.
- `WR` and `WRGR` routing markers parse, but route only to a deferred privacy
  decision.
- `OutboundPolicy` blocks restricted/proprietary/contextual payloads with zero
  outbound bytes and creates only a scrubbed proposal for public/generic data.
- The native Research screen creates, keeps, lists, and resumes local plans
  while stating that web, cloud, CAM, scheduling, and automatic retention are
  disabled.
- Current focused verification:
  `swift test --disable-sandbox --scratch-path .swift-build --filter
  ResearchTests` passed all seven tests.

## Missing end-to-end acquisition behavior

| Required behavior | Current state | Missing proof or implementation |
|---|---|---|
| Deliberately acquire approved web/document sources | Router and policy stop at a proposal | No typed acquisition request, transport, local-document importer, URL policy, or exact execution boundary |
| Privacy-safe outbound payload | Deterministic classification and scrubbed proposal exist | No transport-spy proof connecting consumed approval to exact transmitted bytes |
| Exact approval | Generic exact action card and one-use approval store exist | Research is not wired to a canonical approval store, action card, target, expiry, cost/budget, verification, or recovery contract |
| Checkpoint/cancel/resume | Plan checkpoint version exists | No persisted acquisition job, item cursor, cancellation state, retry/idempotency identity, terminal state, or safe resume boundary |
| Deduplicate sources | No acquired-source record exists | Define canonical source identity, content digest, redirect identity, and repeat-query behavior |
| Acquisition receipt | No transport exists | Record query, route, model/tool, target, status, bytes, content digest, cost, start/end time, source quality, cancellation, and failure without raw secrets |
| Cost/spend control | Manifest describes possible USD spend | No budget, price, metering, actual-cost receipt, over-budget refusal, or zero-cost local-document path |
| Source quality | Facts validate citation text only | No publisher/origin, freshness, primary/secondary status, authority, conflicts, or source-quality review |
| Untrusted-content boundary | Outbound prompt-injection fixtures exist | No acquired HTML/document sanitization, instruction isolation, MIME/size limit, redirect policy, SSRF/local-address refusal, or tool-output quarantine |
| Typed research output | Facts and inferences exist | No contradiction, unanswered-question, recommendation, source-receipt, or acquisition-limitation fields in `ResearchPacket` |
| Native packet review | Native UI handles local plans only | No acquired-source list, cited finding review, Keep/Discard packet action, partial/cancelled/error view, or retained packet history |
| Explicit packet retention | `ResearchPacketStore.keep` persists packets | Store has no canonical app-owned path or AppModel wiring; a kept packet still carries `ResearchRetention.ephemeral`, so durable storage and the packet's own retention label disagree |
| Offline review | Local planning works offline | No native reopening/review of previously retained packets |
| Backup/restore | Component packet store test exists | No canonical path, full-vault inventory entry, or fresh-root packet recovery proof |

## Required safety boundary

1. Research execution must begin only from an explicit `WR`/`WRGR` or native
   acquisition action. A weak local answer cannot trigger it.
2. The deterministic outbound policy must run before any DNS, socket, provider,
   browser, or document fetch.
3. Approval must bind the exact scrubbed query/payload digest, route, target,
   state version, expiry, byte/cost limits, verification, cancellation, and
   recovery policy.
4. Protected classifications remain zero-byte blocks. Approval cannot override
   a policy block merely because a user clicked Continue.
5. The first adapter should be bounded and independently testable with a local
   deterministic transport double before any public live request.
6. Web/document content is untrusted data. It cannot alter routing, policy,
   permissions, tools, retention, or the completion claim.
7. Acquired bytes enter the Layer 1 vault only under the approved source
   boundary with content identity and provenance. Research packets retain
   typed citations and receipts, not an unaudited duplicate source store.
8. Packet construction and packet retention remain separate. Keep changes the
   durable retention record only after citation validation and explicit review.
9. Cancellation, failed validation, partial acquisition, cost refusal, and
   unavailable routes remain visible states and cannot become a ready or kept
   packet silently.

## Candidate first bounded proof

A safe first vertical slice can use a caller-approved public HTTPS document
with strict scheme/host/redirect/size/MIME limits and a deterministic injected
transport in focused tests. The packaged journey should use a disposable local
HTTP fixture or separately approved public source, preserve the exact request
and response receipts, support cancellation/restart, build a citation-validated
packet, and require explicit Keep or Discard.

This is a candidate direction, not an approved implementation design.

## Current proof boundary

The current seven tests prove useful offline planning, checkpoint versioning,
citation validation, fact/inference separation, and component persistence.
They do not prove any source acquisition, transmitted bytes, web safety,
deduplication, cost control, cancellation/recovery, source quality, native
packet review, or packaged research journey.

No network request, provider call, paid operation, live source read, approval
consumption, or packet retention in the live app occurred during this audit.

