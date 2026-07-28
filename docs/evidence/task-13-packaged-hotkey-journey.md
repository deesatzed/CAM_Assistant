# Task 13 Packaged Hotkey and Isolated Restart Journey

Date: 2026-07-27
Platform: macOS 15, Apple Silicon
Package: `artifacts/CAM Assistant.app`
Branch: `agent/portable-canonical-repo`
Feature commit: `715dfc3701e0cc8358b73ca2a8cd05ed65bd60b1`

## Scope

This receipt covers a fresh packaged-app run, real global open and clipboard
capture hotkeys, visible collision handling, and restart recovery against a
disposable application-support root. It does not claim the remaining watched
folder, backup/restore, selected-model, or complete accessibility journeys.

## Expected reds and correction

The initial Finder-to-app exercise returned `Finder -> Finder` even though the
app showed `Global hotkeys active`. A focused regression test then proved the
cause: `HotkeyManager` incorrectly treated macOS letter virtual key codes as
alphabetically contiguous. The red values for C, K, and Z were 2, 10, and 25;
the required macOS values are 8, 40, and 6.

The implementation now maps every supported A-Z key to its explicit Carbon
virtual key constant. The default open shortcut is Command-Option-K rather than
Command-Option-Space because Finder owns the latter for Search. The capture
shortcut remains Command-Option-C.

## Isolation contract

`CAM_ASSISTANT_APPLICATION_SUPPORT_ROOT` may be supplied only as a nonempty
absolute path. The packaged proof launched with:

```sh
open -n 'artifacts/CAM Assistant.app' \
  --env CAM_ASSISTANT_APPLICATION_SUPPORT_ROOT=/tmp/cam-assistant-gui-proof.ewAFyx
```

Both vault state and model-profile state resolve beneath that root's
`CAMAssistant` directory. Invalid relative or empty overrides fail closed. No
override preserves the normal macOS Application Support location.

## Packaged GUI results

- The packaged UI reported `Global hotkeys active`.
- From Finder, Command-Option-K changed the frontmost process from
  `Finder -> CAMAssistant`.
- A harmless 46-byte marker was placed on the clipboard, the packaged
  Command-Option-C shortcut was sent, and the prior clipboard was restored in
  the same AppleScript on both success and error paths.
- The native UI reported `Clipboard captured and indexed locally.`
- The isolated vault contained exactly one `Clipboard.txt` source and one
  derived document.
- The pre-existing normal CAM vault remained at one source and one derived
  document. No normal `hotkeys.json` was created.
- Settings exposed distinct Models, Hotkeys, and Capture Sources panes.
- The Hotkeys pane displayed open key K and capture key C.
- Submitting duplicate C/C shortcuts displayed
  `Hotkey configuration could not be saved.` The valid K/C configuration was
  then restored and saved only to the isolated root.
- After terminating and relaunching the package against the same isolated
  root, Library reported one active indexed source, K/C reloaded, and
  `Global hotkeys active` remained visible.

## Automated verification

```text
swift test --disable-sandbox --scratch-path .swift-build
183 tests passed

CAM_ASSISTANT_SKIP_FRESH_CLONE=1 /bin/zsh scripts/verify.sh all
portability, 183 tests, and app/CLI release build passed

/bin/zsh scripts/verify.sh package
production app build passed
Info.plist validation passed
unsigned package produced

/bin/zsh scripts/verify.sh smoke
offline capture/local-search smoke passed with cloud auto-routing disabled

/bin/zsh scripts/verify.sh fresh-clone
commit 715dfc3701e0cc8358b73ca2a8cd05ed65bd60b1
source dirty false
183 tests, release build, package, and smoke passed
```

Focused coverage includes:

- foreground activation before window raise;
- collision-safe default shortcut;
- explicit macOS virtual key codes;
- the three reachable Settings panes;
- isolated application-support routing; and
- rejection of ambiguous isolation paths.

## Privacy and evidence boundary

An earlier non-isolated exploratory capture accidentally indexed the user's
then-current clipboard into the normal local vault. Its content is excluded
from this receipt, was not committed or transmitted, and remains untouched
because deletion was not authorized. The valid proof above used only the
disposable root and a harmless marker while restoring the existing clipboard.

The temporary proof root is disposable runtime evidence, not a shipped fixture.
This receipt proves the bounded packaged hotkey/capture/restart slice only; it
does not close all CAM-013 or full-product gates.
