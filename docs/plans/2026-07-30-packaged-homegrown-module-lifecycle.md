# Packaged Home-Grown Module Lifecycle Implementation Plan

> **For Codex:** REQUIRED SUB-SKILL: Use `executing-plans` to implement this
> plan task-by-task.

**Goal:** Prove one locally trusted, packaged native read-only module can be
installed, explicitly granted, exercised, disabled, removed, and restart
verified without affecting the offline Memory core.

**Architecture:** The first module is not arbitrary executable code. Its
manifest is a repository-packaged JSON resource and its only fixed dispatcher
operation is deterministic text statistics over caller-provided public text.
An installer owns a staging directory and an app-owned installed-manifest root;
it validates a pinned packaged SHA-256 before atomic promotion. The registry
remains the authority for enablement and grants; the dispatcher requires a
current advertised capability on every invocation.

**Tech Stack:** Swift 6.3, Foundation, CryptoKit, Swift Testing, SwiftPM
resources, native SwiftUI packaged-app verification.

---

## Boundaries

- No module may supply a dynamic executable, shell command, network target,
  process, provider, or filesystem path.
- Initial installation accepts only the exact bundled manifest digest for the
  one native read-only module; generic third-party installation stays absent.
- Enablement is not a grant. Dispatch requires all declared permissions and a
  healthy manifest at the moment of invocation.
- Disable/remove delete only the app-owned installed manifest and grants;
  they never delete vault data, tasks, research, or other Layer 1 state.

### Task 1: Package and trust one manifest

**Files:**

- Create: `Modules/Packaged/cam.text-summary.json`
- Modify: `Package.swift`
- Modify: `Sources/CAMAssistantCore/Modules/ModuleManifest.swift`
- Test: `Tests/CAMAssistantCoreTests/ModuleRegistryTests.swift`

1. Add a failing test that loads the packaged manifest, validates it, and
   rejects changed bytes against its fixed digest.
2. Add the manifest resource and smallest typed trust descriptor.
3. Run the focused module suite.

### Task 2: Install, dispatch, disable, and remove

**Files:**

- Create: `Sources/CAMAssistantCore/Modules/PackagedModuleLifecycle.swift`
- Modify: `Sources/CAMAssistantCore/Modules/ModuleRegistry.swift`
- Test: `Tests/CAMAssistantCoreTests/ModuleRegistryTests.swift`

1. Write a failing lifecycle test in a temporary app-support root: install,
   reload, enable with zero grants, grant `readLocal`, dispatch text summary,
   disable, remove, restart, and prove disappearance and unchanged core data.
2. Implement staged atomic manifest promotion and status-only receipts.
3. Implement a closed dispatcher for `text.summary` only; reject all other
   IDs and all unavailable permission/health states.
4. Run focused module tests and the aggregate module suite.

### Task 3: Native packaged journey and truthful evidence

**Files:**

- Modify: `Sources/CAMAssistantApp/Views/` (new Modules view if absent)
- Modify: `Sources/CAMAssistantApp/AppModel.swift`
- Create: `docs/evidence/task-17-packaged-homegrown-module-lifecycle.md`
- Modify: `PROGRESS.md`, `TASK_QUEUE.md`, and goal map when justified

1. Add a packaged isolated-root journey that shows install, explicit grant,
   exercise, disable, remove, relaunch, and core-memory availability.
2. Preserve module receipts in the app-owned durable state; restored runtime
   health never creates implicit authority.
3. Run focused, aggregate, package/smoke, and fresh-clone verification before
   changing the goal-gate verdict.
