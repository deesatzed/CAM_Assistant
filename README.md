# CAM Assistant

**Private, local-first macOS memory inbox** with a thin **Direction** strip for people and promises (Pattern A: N4 body + N3 face).

This repository is a **standalone product codebase**. Clone it alone; no parent monorepo is required.

| | |
|--|--|
| **Platform** | macOS 15+, Apple Silicon recommended |
| **Language** | Swift 6.2 (SwiftPM) |
| **Data** | On-device under Application Support (`CAMAssistant/`) |
| **Models** | Optional local OpenAI-compatible server (LM Studio / Ollama); Find works offline |

---

## Quick start

```bash
git clone https://github.com/deesatzed/CAM_Assistant.git
cd CAM_Assistant
swift build
swift test
swift run CAMAssistant
```

**Requirements:** Xcode command-line tools (or full Xcode), network once to resolve the pinned [MeaningCore](https://github.com/deesatzed/meaningcore) package.

### Ordinary product surface

1. **Home** — Direction (people / promises / Talk), Save Clipboard, Find/Ask, Keep  
2. **Library** — Browse, search, hide/restore, citations  
3. **Settings** — Capture folders, Local AI, Backup & Restore, Advanced (endpoints / hotkeys)

Sheets use **Done** and **Escape** to leave.

---

## Goals (controlling)

| Document | Role |
|----------|------|
| [`GOAL.md`](GOAL.md) | Active sequenced goals |
| [`GOAL_BAREBONES.md`](GOAL_BAREBONES.md) | Phase 1 — private memory inbox (N4) |
| [`GOAL_DIRECTION.md`](GOAL_DIRECTION.md) | Phase 2 — Direction strip + Talk (N3) |
| [`docs/plans/2026-08-09-n3-n4-pattern-a-positioning.md`](docs/plans/2026-08-09-n3-n4-pattern-a-positioning.md) | Needs lock |

Historical / specialist scope (not ordinary navigation): `GOAL_FINISH_WIKI.md`, `GOAL_ADD2CAM.md`.

**Honest status:** Machine gates for barebones + Direction are evidenced in-repo. Human pilots (barebones Gate 7, Direction D6) remain open unless waived by a human.

---

## Verify

```bash
# Focused / full suites (see scripts/verify.sh)
/bin/zsh scripts/verify.sh barebones-packaged
/bin/zsh scripts/verify.sh portability

# Optional fuller aggregate (longer)
# CAM_ASSISTANT_SKIP_FRESH_CLONE=1 /bin/zsh scripts/verify.sh all
```

Package a local app (unsigned development bundle):

```bash
/bin/zsh scripts/package-app.sh
```

---

## Repository layout

```text
Sources/
  CAMAssistantApp/     # SwiftUI shell
  CAMAssistantCore/    # Vault, ingest, retrieval, Direction, modules
  CAMAssistantCLI/     # CLI entry
Tests/
scripts/               # verify, package, smoke, portability
docs/plans/            # designs and implementation plans
docs/evidence/         # gate evidence
Modules/               # module manifests
Package.swift
```

---

## Dependencies

| Package | Purpose | Pin |
|---------|---------|-----|
| [meaningcore](https://github.com/deesatzed/meaningcore) | Meaning Preview pilot (opt-in specialist path) | See `Package.resolved` |

No Docker, PostgreSQL, or cloud account is required for ordinary Home / Library / Settings use.

**Optional external systems** (adapters only; not required to build or use barebones):

- Local LLM server (LM Studio / Ollama) for synthesized Ask / Talk  
- Historical CAM_Codx / CAM_CAM contracts for developer specialist surfaces  

---

## Development

Read [`AGENTS.md`](AGENTS.md), then `GOAL.md` → `STANDARDS.md` → `IMPLEMENT.md` → `DECISIONS.md` → `PROGRESS.md` → `TASK_QUEUE.md`.

```bash
swift test --filter DirectionProfileStoreTests
swift run CAMAssistant
```

Primary branch for collaboration: **`main`**.

---

## Privacy and non-claims

- Ordinary capture, Library, exact find, Keep, and backup work **without** a network model.  
- No silent cloud provider for Partner/Ask paths.  
- Not production-signed/notarized by default; packaging scripts produce local bundles.  
- Do not claim “complete” while human gates remain open without an explicit waiver.

---

## License

MIT — see [`LICENSE`](LICENSE). Third-party attributions: [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).
