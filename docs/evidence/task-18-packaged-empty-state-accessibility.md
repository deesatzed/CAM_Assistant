# Packaged Empty-State Accessibility Inspection

**Date:** 2026-07-29
**Status:** Valid bounded packaged-app evidence. This is not complete
VoiceOver, keyboard, visual, populated-state, or journey automation proof.

## Identity and isolation

- Source commit:
  `94977951b558435f97c5c4967092dd73edfa88dc`
- Embedded source dirty state: `false`
- Bundle version: `51`
- Packaged executable SHA-256:
  `2112dac8cd45cb69e7132249b44b29c15f602c39c6d72a876166ea50743d3e61`
- Runtime: macOS 27.0 build `26A5388g`, Apple silicon `arm64`
- Disposable application-support root:
  `/private/tmp/cam-gui-audit-clean.GrWMaK`
- Launch:

```text
open -n -F \
  --env CAM_ASSISTANT_APPLICATION_SUPPORT_ROOT=/private/tmp/cam-gui-audit-clean.GrWMaK \
  "artifacts/CAM Assistant.app"
```

The packaged app created only its isolated `CAMAssistant/vault.sqlite`.
Read-only inspection after quit found zero `sources`, `derived_documents`,
`task_records`, and `repository_jobs`. The disposable root was removed after
the inspection. Normal application-support state was not selected or read.

## Native accessibility-tree observations

The clean packaged app was opened and each primary sidebar row was selected
through the native accessibility interface. A fresh full tree was read after
each selection.

| Workspace | Observed bounded state |
|---|---|
| Assistant | Initial question field is focused; local Ask and Capture controls are named; selected-model Ask is disabled; output states answers are ephemeral |
| Library | Container reports zero active and hidden sources; Refresh is named; empty state explains how to add local sources |
| Activity | Container and Refresh are named; empty state explains where local ingest jobs appear and that original bytes remain local |
| Tasks | Container reports zero open tasks; empty state explains cited-answer promotion |
| CAM | Container exposes the pinned contract identity, disconnected state, unavailable actions, and disabled execution |
| Research | Question field and local-plan controls are named; Keep is disabled; external execution and automatic retention are explicitly unavailable |
| Repositories | Path, inspect, save, index, and observation controls expose distinct names and authority hints; empty state says inspection is read-only and CAM mining is disabled |
| Mac Care | Read-only scope and unavailable Apply/Undo authority are explicit; assessment control is named |
| Settings | Models, Hotkeys, and Capture Sources are separate named radio buttons |

All three Settings panes were also selected and re-read:

- Models reports no active profile, visible local-only safety text, and a named
  Reload control.
- Hotkeys exposes named Open/Capture fields, Save and Register, and the active
  registration state.
- Capture Sources exposes the paused-until-enabled policy and a named Add
  Folder control.

No folder picker, repository operation, clipboard capture, model endpoint,
research run, CAM action, Mac assessment, provider, browser, network request,
or retention action was invoked.

## Keyboard observation

An ordinary `Tab` key was sent while Capture Sources was selected. A fresh
full accessibility tree showed no focused-element change. This run did not
alter the host's Full Keyboard Access setting, so it does not prove that Tab
focus is broken in the app; it proves only that a portable keyboard journey
cannot depend on the current host setting without an explicit harness
boundary.

## Claim boundary

This receipt adds exact-commit, clean-package coverage for all empty primary
workspaces and Settings panes. It does not prove:

- spoken VoiceOver output, rotor behavior, announcements, or reading order;
- every keyboard tab stop, focus return, or keyboard-only completion path;
- populated, loading, error, cancellation, recovery, or large-data states;
- contrast, text scaling, clipping, reduced-motion runtime behavior, or
  alternate window-size matrices;
- a repository-owned repeatable GUI driver or unified fresh-user/recovery
  journey.

Those gates remain partial or missing.
