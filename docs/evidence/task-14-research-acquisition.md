# Task 14 — Policy-Gated Research Acquisition

**Date:** 2026-07-29

**Verdict:** Passed for the bounded direct-public-document V1 acquisition,
durable lifecycle, untrusted-data boundary, and native packet review. Typed
result authoring remains partial because no acquired-source workflow yet
creates and citation-validates populated facts, contradictions, or
recommendations.

## Implemented boundary

- One caller-selected canonical public HTTPS document.
- Exact one-use action card and consumed approval before transport.
- No literal IP, local/private host, credentials, query, fragment, non-HTTPS
  scheme, or non-default port. Percent-decoded paths are privacy-classified.
- Every request is TLS-pinned to validated public DNS addresses. Redirects are
  not followed by the transport; CAM re-resolves and revalidates each
  same-origin redirect before another connection.
- Credential-free `GET` through the macOS system curl with ambient curl
  configuration and proxies disabled; no cookies, cache, authorization,
  request body, browser, provider search, cloud model, or CAM.
- Plain text, Markdown, JSON, and PDF only; streamed maximum of 5 MiB.
- Fixed route `WR/direct-public-document`, tool
  `pinned-curl-public-document-v1`, maximum and actual cost USD 0.
- Durable schema-v9 jobs with pending/running/cancelled/failed/completed
  transitions, restart interruption recovery, bounded attempts, and
  state-versioned exact reapproval. V1 resume is a new full fetch, not an
  unverified partial-byte continuation.
- Accepted bytes enter the immutable content-addressed vault and only their
  targeted ingest job is processed.
- Source text is data. Prompt-like or protected-looking content can create a
  review signal but cannot alter policy, approval, routing, tools, or
  retention.
- The packet is ephemeral until explicit Keep. A completed durable receipt can
  reconstruct that ephemeral acquisition-only packet after restart without
  persisting model output or fabricating findings.

## Deterministic proof

| Command | Result |
|---|---|
| `/bin/zsh scripts/verify.sh research` | 27 tests pass: request/card binding, strict/query-free URLs, stable recursive decoded-target privacy, exact approval, protected-query zero transport, DNS-rebinding refusal, pinned curl arguments/environment/version, transition-address refusal, distinct production failure codes, hard response bounds, process pre-launch cancellation, inert content, coordinator cancellation, resume/reapproval, restart, attempt limit, deduplication, CLI explicit approval, status-only receipt, and completed-receipt reconstruction |
| `/bin/zsh scripts/verify.sh app` | 22 tests pass: proposal/block/acquire/cancel/recover/review/Keep/Discard/restart state, real coordinator/store cancellation race, and native source/accessibility contracts |
| `/bin/zsh scripts/verify.sh privacy` | 8 privacy tests and 3 audit tests pass, including every frozen restricted fixture producing zero outbound bytes |
| `/bin/zsh scripts/verify.sh ingest` | 27 tests pass, including source-targeted ingestion that cannot process an unrelated pending source |
| `/bin/zsh scripts/verify.sh storage` | 8 storage and schema-migration tests pass |
| `/bin/zsh scripts/verify.sh backup` | 18 full-vault tests pass, including a representative completed acquisition job after restore |
| `CAM_ASSISTANT_SKIP_FRESH_CLONE=1 /bin/zsh scripts/verify.sh all` | All 287 Swift tests pass with portability, the honest 48-gate map, release app/CLI builds, reproducible package, package identity, and a 54-file zero-finding credential-signature scan |
| `/bin/zsh scripts/verify.sh smoke` | Offline launch contract passes: capture and local search available; automatic cloud routing disabled |
| `/bin/zsh scripts/verify.sh fresh-clone` | Exact implementation checkpoint `8d2dc163f3a516598967f9700406cd58b9d2c098` passes all 287 tests, release builds, reproducible package, clean package identity, 54-file privacy scan, and offline smoke from a temporary non-local clone |

## One live public-document receipt

The live command used a disposable vault and an explicit CLI
`--approve-exact` action:

```text
target: https://www.rfc-editor.org/rfc/rfc9110.txt
run: live-rfc9110-pinned-20260729
job: 1628f604-c1ce-4cc3-9ec0-da37111da780
status: completed
route: WR/direct-public-document
tool: pinned-curl-public-document-v1
content type: text/plain
bytes: 502941
sha256: 21c1cdce6ab0e5509b04d84a28000836c7a087cf786efe6f04877ebfff47232a
maximum cost usd: 0
actual cost usd: 0
duplicate source: false
source quality: unknown
source reviewed: false
untrusted content signals: pii
packet retention: ephemeral
```

Postconditions, without opening or saving response text:

- SQLite `quick_check`: `ok`.
- Acquisition jobs: one `completed`.
- Ingest jobs: one `completed`.
- Sources: one; capture events: one.
- Immutable object size and SHA-256 exactly match the receipt.
- Approval history exists.
- `research-packets.json` did not exist before explicit native Keep.

The conservative PII signal is retained as an untrusted-content review flag.
The acquisition did not reinterpret it as an instruction or mark the source
reviewed.

The hardening receipt used `/usr/bin/curl 8.7.1`. The live adapter fails
closed when the system curl is absent or older than 8.4 because older versions
cannot enforce `--max-filesize` while streaming a response with unknown length.

The hardened live binary was built from source base `c15f7f4` with the implementation
worktree dirty; the package truthfully embedded `CAMBuildSourceDirty=true`.
The clean implementation checkpoint is
`8d2dc163f3a516598967f9700406cd58b9d2c098`; its fresh-clone package embedded
that exact commit with `dirty=false`. This evidence does not mislabel the
pre-commit live binary as a clean exact-commit build.

## Packaged native journey

The unsigned packaged app was launched against a disposable copy of the live
vault. No second network request was made.

1. The Research workspace reopened the one completed durable job after app
   restart and exposed **Review Ephemeral Packet**.
2. Review reconstructed an ephemeral packet and displayed the exact route,
   tool, URL, MIME, 502,941-byte bound result, digest, USD 0 cost,
   retrieval/start/completion times, unreviewed/unknown source quality, PII
   signal, unanswered question, and explicit no-model-finding limitation.
3. **Keep Packet** persisted one `explicitlyKept` packet with one source,
   zero facts, and one unanswered question.
4. **Discard Packet** removed only the ephemeral presentation; the kept packet
   and immutable source remained.
5. After a second packaged-app restart, the completed job and explicitly kept
   packet both reopened.
6. SQLite remained healthy with one completed acquisition, one source, and one
   capture. The immutable object retained the exact live digest and byte count.

This repeated hardened package journey used run
`live-rfc9110-pinned-20260729`. Its post-restart retained packet had one source,
zero facts, one unanswered question, and `explicitlyKept` retention. The
disposable copy retained one completed acquisition, one source, one capture
event, a 502,941-byte object, and the exact
`21c1cdce6ab0e5509b04d84a28000836c7a087cf786efe6f04877ebfff47232a`
digest.

## Gate effect

- `research.acquisition`: passed.
- `research.native-review`: passed.
- `research.untrusted-output`: passed.
- `research.typed-results`: remains partial. The complete type set now exists,
  but an acquired-source authoring workflow has not yet populated and
  citation-validated all result types.
- `approvals.exact-action`: remains partial. This research executor is fully
  bound, but other future outbound or mutating executors are not all complete.

## Adversarial review adjudication

The required independent review initially returned one Critical, four
Important, and two Minor findings. All were accepted as security, lifecycle,
truth-contract, or inspection improvements. The implementation now:

- pins production TLS connections to validated public addresses and
  revalidates every redirect;
- refuses mapped, compatible, NAT64, 6to4, Teredo, and other covered
  private/transition address forms;
- classifies percent-decoded targets to a stable bounded representation and
  rejects query-bearing URLs in V1;
- records distinct transport, DNS, response, and ingestion safe states;
- linearizes process launch against cancellation and refuses late native
  success;
- explicitly defines resume as a new full fetch rather than claiming a missing
  byte cursor;
- shows the full digest, freshness/timing, and whether textual signal
  inspection actually ran.

No recommendation was rejected. The final review reported no remaining
Critical or Important findings and independently re-ran all 27 research tests
green.

## Non-claims

This is not provider search, query-bearing URL acquisition, arbitrary web
research, HTML/JavaScript execution, browser automation, cross-origin link
following, partial-byte resume, paid acquisition, cloud-model synthesis,
automatic knowledge promotion, or proof that the RFC contains PII. No response
text is stored in this repository evidence.
