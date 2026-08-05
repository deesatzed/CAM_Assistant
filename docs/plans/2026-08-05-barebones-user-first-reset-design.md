# Barebones User-First Reset Design

**Approved:** 2026-08-05

## Product Promise

CAM Assistant is a private memory inbox for one person:

> Capture something once, find it later, ask questions grounded in it, and
> deliberately keep only what remains useful.

The first successful product is not a general agent. It reduces organization
work and technical mental overhead for a general iPhone user. It must remain
useful without a model or network connection.

## Target User

The default experience assumes the user:

- understands ordinary actions such as Save, Search, Keep, Hide, and Restore;
- does not know or care about indexes, embeddings, routes, manifests, endpoint
  URLs, model schemas, content hashes, or permission classes;
- expects the app to choose safe local defaults;
- wants trustworthy answers without maintaining a folder taxonomy;
- may inspect technical details, but should never need them for normal use.

The UX benchmark is a general iPhone application, not a developer console.

## Design Principles

1. **One obvious next action.** Each primary state has one visually dominant
   action and at most one secondary escape.
2. **Plain language first.** Say “Saved to your Library,” not “ingest completed”;
   say “Local AI is not running,” not “loopback transport unavailable.”
3. **Automatic after understandable consent.** Choosing a folder or invoking
   Save Clipboard authorizes bounded local capture; normal ingestion does not
   require repeated approval.
4. **Useful without AI.** Capture, Library, exact search, citations, visibility,
   backup, and recovery work with no model.
5. **One local answer path.** Ask uses the selected local model when healthy and
   otherwise shows matching local passages with a plain explanation. It never
   silently uses cloud, web, CAM, or another provider.
6. **Answers are temporary by default.** Keep is an explicit, reversible act.
7. **Progressive disclosure.** Friendly titles, dates, previews, and source
   names are primary. Hashes, passage IDs, extractor IDs, route identity, and
   audit details live under “Details.”
8. **Errors explain recovery.** Every error says what happened, whether the
   user's content is safe, and the next action.
9. **No specialist surface without earned utility.** Experimental systems do
   not enter default navigation because their code exists.
10. **Accessibility is normal UX.** Keyboard, VoiceOver, focus, contrast,
    text scaling, empty states, and reduced motion are acceptance requirements.

## Primary Information Architecture

The default sidebar contains three destinations:

### Home

Home combines the ordinary daily loop:

- “Save Clipboard”
- “What are you looking for?” question field
- one “Ask” action
- current answer or matching passages
- source citations that open in Library
- Keep and Discard
- a small recent-saves area

There are no separate “Ask locally,” “Ask Selected Local Model,” or “Ask
OpenRouter” buttons. The user does not choose an internal implementation lane.
The app reports the result in plain language and exposes the route under
Details.

### Library

Library presents human-recognizable saved material:

- source title or filename;
- captured date;
- short preview;
- broad type such as Note, Document, Image, Audio, or Code;
- search and simple filtering;
- Hide/Restore;
- citation navigation;
- technical provenance under Details.

The primary row label must never be a content hash.

### Settings

Settings has four understandable groups:

1. **Capture** — keyboard shortcut and watched folders.
2. **Local AI** — detected status, selected model, and a simple connection
   action. Endpoint editing is Advanced.
3. **Backup & Restore** — create, check, and restore into a new location.
4. **Advanced** — technical identities, diagnostics, and developer-only
   controls.

Research, Repositories, CAM, Mac Care, Modules, Meaning Preview, Approvals,
Tasks, and Activity are absent from default navigation. Their code and tests
remain intact. A test-injected developer experience may expose them, but a
normal release cannot reveal them accidentally.

## Core Interaction Journeys

### First Launch

1. Home says “Your private Library is empty.”
2. The primary action is “Save Clipboard.”
3. A secondary action, “Watch a Folder,” opens the relevant Settings group.
4. A short statement says the content stays on this Mac.
5. No model setup is required before capture or search.

### Capture

1. The user chooses Save Clipboard or a watched folder once.
2. CAM saves and indexes locally.
3. Home shows “Saved to your Library” with the recognizable source name.
4. Duplicate content reports “Already in your Library” rather than creating
   confusing copies.
5. Failure reports a safe, actionable message and offers Retry when valid.

### Find and Ask

1. The user enters an ordinary question.
2. CAM retrieves local passages deterministically.
3. If Local AI is healthy, it produces a cited answer.
4. If Local AI is unavailable, CAM displays the best matching passages and
   says, “Local AI is not running, so these are the closest matches.”
5. Unsupported questions yield “I couldn't find enough in your Library” with
   no fabricated answer.

### Keep

1. The answer is temporary.
2. Keep saves a short cited memory, not the conversation transcript.
3. A duplicate or likely related memory prompts a simple choice: Update
   existing or Save separately.
4. Undo remains available from the confirmation state.
5. Task/fact/assumption classifications are not primary controls; later
   organization happens automatically or under More Options.

### Recover

1. Settings creates a validated backup.
2. Restore always targets a fresh location.
3. The app explains what will and will not be restored in ordinary language.
4. Restored watched folders remain paused until the user resumes them.

## Progressive Disclosure

Every core object has two presentations:

- **Friendly:** title, preview, date, source, state, and relevant action.
- **Details:** immutable ID, SHA-256, extractor, passage ID, model/endpoint,
  route, audit receipt, and technical error code.

Details are available through a disclosure group or Inspector. They are never
required to complete a normal journey.

## Application Architecture

The reset preserves existing core storage and safety code. It changes the
product seam rather than rewriting the vault.

### Experience boundary

Add an injected `AppExperience` value with two modes:

- `.primary` — Home, Library, Settings only;
- `.developer` — existing specialist workspaces for tests and continued
  incubation.

Production defaults to `.primary`. Developer mode is injected by tests or an
explicit development-only launch argument; it is not a normal preference.

### Presentation boundary

Introduce small presentation types for Home and friendly Library rows. The
existing `AppModel` remains the temporary integration façade, but new UI logic
must not add another feature domain directly to it. Core actions delegate to
focused coordinators or existing stores.

Initial extraction boundaries:

- `HomePresentation` and home action façade;
- `LibraryItemPresentation` and filtering;
- `LocalAssistantAvailability` for friendly model state;
- `UserFacingIssue` for safe error and recovery copy.

No broad AppModel rewrite occurs before the simplified journey is green.

## Data and Authority

- Immutable captured bytes and existing SQLite metadata remain authoritative.
- Search indexes remain replaceable derived state.
- Model answers remain ephemeral until Keep.
- Normal local capture does not request network or mutation approval.
- Restricted data never produces an outbound payload.
- Cloud/OpenRouter is excluded from the primary experience.
- Hidden experimental features gain no permission or execution authority.

## Failure Language Contract

Primary UI errors must contain:

1. a friendly description;
2. a content-safety statement when relevant;
3. one next action;
4. an optional Details disclosure containing the stable technical code.

Raw exception descriptions, filesystem paths, model schemas, and database
language must not be primary error copy.

## Independent Acceptance Gates

No feature advances until its own packaged journey passes.

1. **Shell:** a fresh profile shows only Home, Library, and Settings.
2. **Capture:** clipboard and one watched folder save once, survive restart,
   and expose understandable success/failure/retry.
3. **Find:** representative personal fixtures retrieve exact passages and open
   recognizable sources without a model.
4. **Ask:** one named local model yields cited answers or honest abstention;
   model absence falls back only to visible local matches.
5. **Keep:** a kept cited memory survives restart; discard leaves no answer;
   duplicate/update and Undo are proven.
6. **Recover:** the complete simplified state validates and restores into a
   fresh root.
7. **Human:** a general non-developer completes the journey without help and
   can explain where the content lives and whether anything went online.

## Non-Goals

- CAM execution or mining
- Mac maintenance
- Repository semantic analysis
- General web research
- OpenRouter or cloud routing
- Plugin/module marketplace
- Multi-agent orchestration
- Meaning Preview promotion
- Automatic durable retention of every answer
- A fixed user-visible folder taxonomy
- Signing, notarization, or public distribution in this reset slice

## Migration and Rollback

- Do not delete specialist code or persisted records.
- Default navigation hides specialist workspaces through the experience
  boundary.
- Existing local vaults open without migration for the shell phase.
- New presentation state is derived and disposable.
- Each feature batch is independently revertible.
- The current full interface remains available only through the explicit
  developer experience while the reset is validated.

## Success Statement

The barebones app succeeds when a general iPhone user can save something, find
it, receive a trustworthy cited local answer, Keep or discard it, and recover
their Library without learning CAM Assistant's architecture.
