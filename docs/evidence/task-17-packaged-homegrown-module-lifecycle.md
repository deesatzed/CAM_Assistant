# Task 17 Packaged Home-Grown Module Lifecycle

## Scope

This receipt proves the first bounded home-grown module, `cam.text-summary`,
through the native unsigned packaged application. It is a closed native text
statistics operation; it is not downloaded code and has no network, shell,
provider, vault-browsing, or mutation authority.

## Isolated packaged journey

- Package: `artifacts/CAM Assistant.app`, built from the working implementation
  under verification.
- Data root: disposable absolute application-support root
  `/private/tmp/cam-module-gui.LTKeSO`.
- Method: macOS native accessibility-tree inspection through Computer Use. No
  normal application-support root, model endpoint, CAM runtime, network route,
  repository, or personal source was selected.

The real packaged UI exposed the following states in order:

1. The Modules sidebar workspace showed `Not installed. Installing does not
   grant access.` and only `Install Packaged Module`.
2. After installation, it showed `Installed but disabled. Enablement still
   grants no access.`; the Grant, Disable, and Summary controls were disabled
   as appropriate.
3. After Enable, it showed `Enabled with no local-text access. Grant is still
   required.` and made the explicit `Grant Local Text Access` control
   available. Summary remained disabled.
4. After Grant, entering `one two two` and selecting `Summarize Locally`
   exposed `Local summary: 3 words, 11 characters.`
5. Disable withdrew local-text access and disabled Summary. Remove returned the
   workspace to its not-installed state.
6. Closing and relaunching the package against the same disposable root still
   showed the not-installed state and the sole Install control. No prior grant
   reappeared.

## Automated evidence

| Command | Result |
|---|---|
| `swift test --filter CAMAssistantCoreTests.removingEnabledPackagedModuleRevokesGrantsBeforeReinstall` | PASS after the expected red: removal prunes durable grants so reinstall cannot revive authority. |
| `/bin/zsh scripts/verify.sh modules` | PASS: 10 module tests, including trust tampering, staged install, explicit grant, disable/remove/reload/restart, and removal/reinstall revocation. |
| `swift test --filter CAMAssistantAppTests.modulesWorkspaceExposesExplicitLifecycle` | PASS after the expected red: native UI exposes the full explicit lifecycle and no-authority boundary. |
| `swift test --filter CAMAssistantAppTests.appModelRunsPackagedModuleLifecycle` | PASS: isolated app-model lifecycle preserves a Layer 1 core-memory marker through install, grant, use, disable, remove, and reload. |
| `/bin/zsh scripts/verify.sh package` | PASS: release package rebuild and `Info.plist` validation. |
| `/bin/zsh scripts/verify.sh fresh-clone` | PASS: exact clean clone of `0301edbc942856745be3ada26c7c1fc9c7977b45`; portability, 48-gate map, all 336 Swift tests, release builds, reproducible package, privacy scan, offline smoke, and clone-cleanliness checks. |

## Aggregate-verification note

The first aggregate run was executed inside the managed Codex sandbox. macOS
correctly denied that outer sandbox from nesting the app's deliberate
`/usr/bin/sandbox-exec` confinement, producing exit 71 before CAM test fixtures
started. The same exact clean-clone verifier passed at normal macOS process
privilege. This is a test-harness constraint, not a relaxation of the product
sandbox or a module defect.

## Boundaries

- This proves one closed, repository-packaged native module, not generic
  third-party module loading or executable plugins.
- The visible result is deterministic word/character counting over text the
  user types into the module workspace. It does not inspect vault content.
- This is an unsigned local package proof. It is not signing, notarization,
  full VoiceOver spoken-audio coverage, or completion of CAM-012/CAM-018.
- Module health execution and permission-change receipts remain partial module
  work; core memory remains independent of this optional module.
