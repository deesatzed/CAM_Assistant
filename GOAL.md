# CAM Assistant Goal

## Active Goal

Complete the user-first private memory inbox defined by
[`GOAL_BAREBONES.md`](GOAL_BAREBONES.md).

The broader [`GOAL_FINISH_WIKI.md`](GOAL_FINISH_WIKI.md) remains historical
specialist scope and evidence. It does not authorize expanding the ordinary
product while the barebones goal is active.

## Primary Objectives

1. Ship a launchable native SwiftUI macOS app that remains useful offline.
2. Provide automatic, idempotent clipboard and watched-folder capture.
3. Build stable local memory, exact sourced retrieval, and explicit Keep.
4. Hide specialist systems from default navigation while preserving their code
   and tests.
5. Prove each barebones feature through an independent packaged journey before
   advancing.
6. Meet a general iPhone user's expectations for language, accessibility,
   defaults, recovery, and progressive disclosure.

## User Value

One quiet app captures and retrieves personal material without forcing the user
to maintain a taxonomy or understand the app's technical architecture.

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

This active reset is complete only when every gate in `GOAL_BAREBONES.md` has
the required current packaged or human evidence.
