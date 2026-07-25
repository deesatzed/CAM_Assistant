# Task 5 Capture and Ingestion Verification

- Date: 2026-07-24
- Branch: `feat/cam-assistant-foundation`
- Expected contract red: capture and ingestion types were absent.
- Expected watcher red: automatic start/stop behavior was absent.
- Focused green: 6 ingestion tests passed.
- Aggregate green: 22 Swift tests passed.
- Production build: app and CLI linked successfully.

Verified behaviors:

- Clipboard and watched-folder inputs use one `CaptureEnvelope`.
- Raw source bytes enter SHA-256 storage before derived processing.
- Text, Markdown, PDF, image, WAV audio, transcript, Swift code, and TOML
  configuration fixtures ingest locally.
- Duplicate bytes create one source and one queue job while distinct capture
  provenance remains recoverable.
- Queue state, source provenance, cancellation, retry, and structured warnings
  persist through SQLite.
- Malformed media reaches a bounded terminal failure without stopping later
  jobs.
- Native FSEvents produces a capture envelope for a newly written watched file
  without a manual rescan.

Current limitation: application settings and global capture-hotkey wiring are
not part of this engine milestone and remain pending in the UX/package task.
