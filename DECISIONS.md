# CAM Assistant Decisions

## Decision Log Overview

This file records product and architecture decisions that materially affect
scope, security, data ownership, licensing, or verification.

## Active Decisions

| Date | Decision | Status |
|---|---|---|
| 2026-07-24 | Build a new native SwiftUI product repo | Active |
| 2026-07-24 | CAM_Codx is the workflow hub; CAM_CAM remains runtime owner | Active |
| 2026-07-24 | The wiki is a core module, not the entire product | Active |
| 2026-07-24 | Local inference and deterministic retrieval are defaults | Active |
| 2026-07-24 | Use manifests/adapters instead of merging donor repos | Active |
| 2026-07-24 | Treat GPL repos as concept donors until licensing is explicit | Active |
| 2026-07-24 | Begin on a feature branch because no prior repo/worktree exists | Active |
| 2026-07-24 | Discovery and enablement do not grant module permissions | Active |

## Initial Default Decisions

- Swift 6, SwiftUI, Swift Package Manager, native macOS services, and SQLite3.
- Human-readable Markdown plus local SQLite metadata and replaceable indexes.
- One base config plus versioned model profiles.
- Synthetic fixtures for privacy and evaluation.
- Automations and optional modules disabled initially.
- Only the native Memory module is core-enabled. Every other initial module is
  discovered but disabled until the user enables it, and permission grants are
  persisted separately from enablement.

## Superseded Decisions

- The earlier product framing as only a personal wiki is superseded by CAM
  Assistant; the wiki design remains applicable to the Memory/Wiki module.

## Decision Rules for Future Agents

- Prefer the smallest reversible option that preserves the full goal.
- Never move personal data ownership into CAM or a cloud provider.
- Never silently change model/provider or permission class.
- Require measured evidence before architecture optimization.
- Record a decision before copying donor code.

## Pending Decision Questions

- Product license.
- Signing/notarization/distribution strategy.
- Whether a later direct MLX Swift path outperforms the local service adapter.
