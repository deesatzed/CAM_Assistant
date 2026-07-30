# REVIEW.md

## Review Scope

Native packaged `cam.text-summary` workspace, durable module removal semantics,
tests, evidence, and goal-map changes.

## Summary Judgment

Proceed.

## Findings

| Severity | Category | Finding | Why It Matters | Required Fix |
|---|---|---|---|---|
| Low | Test clarity | The lifecycle test name claimed absence after restart even though it reinstalled the module before the final restart assertion. | A misleading test name weakens evidence interpretation. | Renamed to state that reinstall needs a new grant. |

## Correctness

Removal now prunes durable grants for missing manifests; a reinstall cannot revive
old authority. The app rechecks registry state after every transition.

## Security and Privacy

The new module is a digest-pinned bundled manifest with one fixed native text
statistics dispatcher. The native workspace exposes no network, shell,
downloaded-code, or vault-browsing path.

## Tests

Focused core, app-model, native view-contract, real packaged accessibility,
goal-map, and package checks cover the claimed slice. Broader aggregate and
fresh-clone checks remain required before publishing.

## Maintainability

Module paths and registry construction are centralized in `AppModel`; the view
contains only presentation and explicit action wiring.

## Performance

The operation is small local filesystem state plus deterministic in-memory text
counting; no main-actor network or model work was added.

## UI/UX Impact

The user sees separate install, enable, grant, summarize, disable, and remove
states, including disabled controls when authority is absent.

## Regression Risk

Low for Layer 1: the isolated lifecycle test preserves a core-memory marker,
and removal touches only the app-owned manifest/state path.

## Scope Creep Check

No generic plugin loading, arbitrary executable, cloud route, CAM invocation,
or Mac mutation was added.

## Required Fixes Before Done

None after the test-name correction.

## Optional Improvements

- Add generic third-party module admission only after a separate trust and
  health-check design.
- Expand end-user accessibility coverage beyond the current focused lifecycle.
