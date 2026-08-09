# CI notes

## AppModel SILGen crash (2026-08-09)

GitHub-hosted Swift 6.1.2 **crashed** (`signal 10`) while SILGen-emitting a
property-level `@StateObject private var model = AppModel()` because
`AppModel` has a large default-argument initializer.

**Mitigation:** construct `AppModel` inside `CAMAssistantApp.init` via
`StateObject(wrappedValue: AppModel(initializeFullWorkspace: true))` so the
compiler does not emit the broken stored-property default thunk.

CI runs full `swift build` + filtered `swift test` + portability script.

**Pages deploy** is separate (`.github/workflows/pages.yml`) and does not
compile Swift. Live site: https://deesatzed.github.io/CAM_Assistant/

**Verified green:** CI workflow on `main` after AppModel `StateObject` init fix
and `HotkeySettingsView.normalizeKeyField` `nonisolated` (2026-08-09).
