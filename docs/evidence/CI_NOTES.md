# CI notes

## Core-only on GitHub Actions (2026-08-09)

GitHub-hosted `macos-15` + Xcode 16.4 / Swift 6.1.2 **crashes** (`signal 10`)
while SILGen-emitting `AppModel()` for `CAMAssistantApp` (`StateObject`
default init over a very large `@MainActor` type).

**CI policy:** build/test **CAMAssistantCore** (+ Core tests) and portability
script. Full app build/test remains local (`swift build` / `swift run
CAMAssistant` / `scripts/verify.sh barebones-packaged` on developer machines).

**Pages deploy** is separate (`.github/workflows/pages.yml`) and does not
compile Swift.
