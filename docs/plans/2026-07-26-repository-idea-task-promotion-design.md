# Repository Idea to Local Task Design

## Goal

Give a user an explicit durable promotion path from a reviewed repository idea
proposal to a local task, preserving the cited commit evidence and authored
validation experiment.

## Chosen approach

Add a Core mapper from a clean-snapshot `RepositoryIdeaCard` to the existing
`TaskProposal`/`TaskStore` contract. The user-facing Repository view exposes a
separate `Save as Local Task` button only after the proposal-only receipt
exists. It saves one local-read task and refreshes the existing Tasks view.

The task citation is a structured local repository evidence reference: source
is the canonical repository path, passage is commit/file/line, and quote is the
deterministic observation statement. The acceptance criteria require reviewing
the cited evidence and running the user-authored smallest validation experiment.

## Boundaries

- Saving a task is an explicit local derived write, not an execution request.
- The task retains no copied repository bytes and makes no claim that the idea
  is correct.
- The task is `localRead` authority only. It cannot edit code, run CAM, call
  a model, or access a network.
- The repository snapshot must be clean and the idea evidence must still match
  it; stale or dirty inputs fail before persistence.
- Research-packet and Codex-plan promotion remain separate future ownership
  contracts. This slice does not conflate a local task with either.

## Verification

Test the mapper's task ID stability, local-read authority, exact criteria,
evidence citation, stale/dirty refusal, and `TaskStore` restart persistence.
The app build verifies the explicit button compiles; no package/smoke command
is treated as proof that a real repository task was endorsed or executed.
