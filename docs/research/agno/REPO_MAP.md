# Agno Cookbook Recon

## Project Type

Read-only reference snapshot of Agno Python cookbooks, not a Git checkout.
The byte-identical `agnocook.txt` copies at
`/Volumes/WS4TB/waswiki/agnocook.txt` and
`/Volumes/WS4TB/agno314/agno/agnocook.txt` concatenate the same cookbook
tree and source material.

## Tech Stack

- Python examples using Agno agents, teams, workflows, SQLite/Postgres,
  knowledge/RAG, tools, approvals, guardrails, evals, and AgentOS.
- Installed environment: Conda `py314`, Python 3.14, `agno 2.8.5`.
- Installed package metadata declares Apache License 2.0.
- Snapshot size: 2,936 files, including 2,135 Python files.

## Package Manager

The snapshot has no repository-level `pyproject.toml` or Git metadata.
Individual cookbook groups carry `requirements.in` and `requirements.txt`.
Their documentation normally assumes Agno's own `.venvs/demo`; this machine
instead has a separate `py314` environment.

## Commands

| Purpose | Command | Verified |
|---|---|---|
| Identify installed runtime | `conda run -n py314 python -c 'import agno, importlib.metadata'` | Yes: `agno 2.8.5` |
| Check key APIs exist | Import `Agent`, approval, FileSystem, workflow primitives, and wiki backends in `py314` | Yes |
| Compare text snapshots | `shasum -a 256 .../agnocook.txt` | Yes: identical SHA-256 |
| Run checkpoint cookbook | Requires a configured model/API key | No; upstream log says syntax-only |
| Run approval examples | Requires configured model/database | Not locally; upstream log has passes and three failures |
| Run eval suite | Requires configured model | Not locally; upstream log records a passing JSON/exit-code suite |

## Entry Points

- `cookbook/README.md`: catalog and quality conventions.
- `cookbook/01_demo/agents/local_wiki.py`: model-driven local Markdown wiki.
- `cookbook/01_demo/agents/git_wiki.py`: credential-gated, auto-commit/push wiki.
- `cookbook/01_demo/evals/cases.py`: judge plus expected-tool-call cases.
- `cookbook/02_agents/11_approvals/`: durable approval lifecycle.
- `cookbook/02_agents/18_checkpointing/`: tool-batch checkpoint concept.
- `cookbook/02_agents/20_time_travel/`: safe-boundary resume and non-destructive fork.
- `cookbook/04_workflows/`: step, condition, loop, parallel, and router primitives.
- `cookbook/09_evals/`: accuracy, reliability, performance, and suites.
- `cookbook/13_filesystem/`: namespaced durable working records and quotas.

## Major Folders

- `02_agents`: typed input/output, sessions, knowledge, guardrails, hooks,
  approvals, checkpointing, time travel, and model fallback.
- `03_teams`: delegation and shared-state variants.
- `04_workflows`: deterministic-looking control-flow shells around model/tool
  executors.
- `07_knowledge`, `12_context`: RAG and filesystem/Git/wiki context providers.
- `08_learning`, `11_memory`: model-managed preferences, decisions, and memory.
- `09_evals`: judge, tool-call reliability, latency, and suite reporting.
- `13_filesystem`: durable records, working state, namespaces, and quota
  recovery.
- `93_components`: versioned agent/team/workflow configuration.

## Existing Patterns To Preserve Selectively

1. Separate agent/session/knowledge/working-record state classes.
2. Persist at tool-batch barriers for long work, with explicit write-amplification.
3. Resume only from a structurally safe boundary; fork completed history
   non-destructively.
4. Resolve approvals with an expected-current-status compare-and-swap guard.
5. Wrap tool calls with ordered policy, audit, timing, and postcondition hooks.
6. Define eval cases with expected tool calls, timeouts, JSON output, and CI
   exit codes.
7. Enforce per-file/per-namespace quotas with typed refusal and no silent
   eviction.
8. Keep read and write wiki capabilities distinct.

These are concepts to re-express in Swift and CAM's existing schemas. They are
not evidence that CAM Assistant should embed Agno.

## Tests and Verification

- Local import introspection confirms the installed `2.8.5` wheel exposes the
  key APIs above.
- Agno's saved approval log reports most examples passing, but team and some
  audit flows failing.
- Its eval-suite log records passing list/filter/JSON/CI behavior.
- Its filesystem subgroup logs are largely green, including read-only shared
  namespaces and exact-line deduplication.
- Its checkpoint examples were not run because they require a live model.
- Many workflow cookbook logs are red, so workflow examples are patterns, not
  a trustworthy runtime baseline for CAM.

## Likely Files For A Future CAM Design

No Agno file should be copied yet. If a design is approved, compare these
concepts with:

- `Sources/CAMAssistantCore/Coordination/OrchestrationState.swift`
- `Sources/CAMAssistantCore/Authority/ApprovalStore.swift`
- `Sources/CAMAssistantCore/Audit/`
- `Sources/CAMAssistantCore/Modules/ModuleRegistry.swift`
- `Sources/CAMAssistantCore/Repositories/RepositoryModule.swift`
- `Sources/CAMAssistantCore/Research/`
- `scripts/verify.sh`

## Unknowns

- The cookbook snapshot's exact source commit and its compatibility with the
  installed `agno 2.8.5` wheel.
- Whether current checkpoint and time-travel examples pass against a live
  local model.
- Exact third-party license/notice obligations for any source-level copying;
  concept-only reimplementation avoids that dependency.
- Whether an optional isolated Agno adapter would add enough unique capability
  to justify Python lifecycle, security, packaging, and support costs.
