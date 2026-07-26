# Watched Source Onboarding Design

## Goal

Turn the existing local `FolderWatcher` engine into a user-controlled watched
source workflow. This closes the onboarding portion of the native capture
journey without widening data access, contacting a service, or mutating a
watched folder.

## Chosen approach

Support multiple independently controlled watched folders from the first
implementation. Each folder is an explicit user-selected local source with a
canonical path, enabled state, and locally persisted status. Multiple folders
fit the assistant's intended role across knowledge, projects, and research
while avoiding a hidden global watcher.

The alternatives rejected for this slice are:

1. One global folder: smaller initial surface but forces an artificial product
   limit and a later migration of consent/state semantics.
2. Automatic discovery: rejected because discovering a path must not grant
   data access or start capture.

## Boundaries

- A folder is added only after an explicit native picker action.
- Only enabled records start a watcher; pause and remove stop it immediately.
- Capture uses the existing local `CaptureService` and preserves the exact
  `watchedFolder` provenance already modeled by the ingestion queue.
- The configuration contains paths and operational status only. It never
  copies folder bytes, indexes an unselected folder, sends anything outward,
  or changes a watched folder.
- An unreadable or missing folder becomes a visible local error. Removing it
  removes only local watcher configuration, never retained vault sources.
- The initial lifecycle is foreground app-session ownership. Background launch,
  scheduling, and automatic repair remain explicitly out of scope.

## Data flow

```text
Choose folder -> canonicalize + locally save disabled record
    -> user enables -> FolderWatcher starts
    -> changed envelope -> existing CaptureService -> existing IngestQueue
    -> local receipt/status -> Library refresh

Pause/remove -> watcher stops -> local configuration is updated
```

## Components

1. A core atomic configuration store and typed presentation state, testable
   with temporary directories.
2. A session manager that owns one `FolderWatcher` per enabled source,
   translates watcher errors into source-specific state, and forwards envelopes
   only to the supplied local capture closure.
3. App-model actions that build local vault dependencies off the main actor,
   expose progress/error state, and refresh the Library after capture.
4. A native Capture Sources settings surface with add, enable/pause, remove,
   path, and status controls. It must be keyboard and VoiceOver labeled.

## Failure and recovery

- Duplicate paths are rejected before persistence.
- A failed watcher start does not claim enabled/running status.
- A launch with a missing path remains locally visible and can be paused or
  removed; it does not delete existing captured content.
- Individual watcher failures do not stop unrelated watched folders or the
  rest of the app.
- No operation is treated as complete until local configuration persistence and
  watcher status agree.

## Verification

Tests will prove atomic restart persistence, duplicate rejection, independent
enabled/paused transitions, remove semantics, path failure presentation, and
that only an enabled selected source sends envelopes to the supplied local
capture closure. The current focused FSEvents test remains the platform proof
that a running watcher emits a folder-origin envelope. App-level verification
will cover presentation labels and a safe error/empty state; it will not claim
background automation or a global OS capture event proof.

## Release claim

This slice proves user-controlled native watched-source onboarding. It does
not prove unattended background capture, cloud processing, or automatic
retention of model output.
