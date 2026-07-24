# CAM Assistant Goal

## Ultimate Goal

Complete the native, local-first CAM Assistant defined by
[`../GOAL_LLM_WIKI.md`](../GOAL_LLM_WIKI.md).

## Primary Objectives

1. Ship a launchable native SwiftUI macOS app that remains useful offline.
2. Provide automatic, idempotent clipboard and watched-folder capture.
3. Build stable local memory, sourced retrieval, tasks, research, and audit.
4. Integrate CAM_Codx/CAM_CAM through typed, conformance-tested adapters.
5. Provide permissioned on-demand modules for Mac Care, repositories, privacy,
   capture, research, and prompts.
6. Prove model routing, privacy, retrieval quality, rollback, accessibility,
   packaging, and cross-repo boundaries.

## User Value

One quiet assistant can remember, retrieve, research, coordinate, maintain the
Mac, and invoke specialized tools without surrendering ownership of personal
data or forcing the user to manage separate systems.

## In Scope

- This repository and its local test artifacts.
- Narrow, explicit adapters to existing local runtimes.
- Synthetic and approved evaluation fixtures.
- Local packaging without signing, notarization, or deployment.

## Out of Scope

- Broad donor-repo rewrites or merges.
- Mutating live CAM databases during read-only operations.
- Production deployment, code signing, or notarization.
- Autonomous clinical, legal, financial, or destructive decisions.

## Assumptions

- Apple Silicon and Swift 6.3 are available.
- CAM_Codx and CAM_CAM remain separately owned repositories.
- Local inference is exposed through an OpenAI-compatible local endpoint or a
  future native MLX adapter.
- Donor repos remain read-only unless a separate approved goal changes scope.

## Non-Goals

- Reproducing every donor feature.
- Training a foundation model.
- Making the app dependent on network, Docker, PostgreSQL, or a hosted account.

## Completion

This repository is complete only when every proof gate in
`../GOAL_LLM_WIKI.md` is supported by current commands and saved artifacts.
