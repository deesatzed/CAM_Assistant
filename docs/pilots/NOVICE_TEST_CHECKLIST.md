# CAM Assistant Second-Mac Test Checklist

Follow the tests in order. Read **What should happen** before choosing a result,
but do not treat the expectation as proof: record what you actually see.

Preparation: [`NOVICE_TEST_START_HERE.md`](NOVICE_TEST_START_HERE.md)  
Problem form: [`NOVICE_TEST_PROBLEM_REPORT.md`](NOVICE_TEST_PROBLEM_REPORT.md)  
Final summary: [`NOVICE_TEST_RESULTS.md`](NOVICE_TEST_RESULTS.md)

## Run information

- Run ID:
- Date and local time started:
- Tester:
- Mac model:
- macOS version:
- Build commit:
- Local AI application: Ollama / LM Studio / other:
- Local model name:
- Date and local time finished:

## Result key

For each test, check every label that applies:

```text
[ ] Pass  [ ] Problem  [ ] Confusing  [ ] Enhancement  [ ] Skipped
```

If you check Problem, Confusing, or Enhancement, copy the problem-report
template and give it the next ID: `P01`, `P02`, and so on.

---

## 1. Installation and first launch

### TEST-LAUNCH-01 — Open the packaged app

**Why:** A normal user must be able to start the application.

**Do this:**

1. In Finder, open the cloned `CAM_Assistant/artifacts` folder.
2. Double-click `CAM Assistant.app`.
3. If macOS refuses because the app is unsigned, Control-click the app, choose
   **Open**, and confirm **Open**.

**What should happen:** The app opens without Terminal errors or a crash. The
unsigned warning may appear once; record it as distribution friction if it is
hard to understand.

- [ ] Pass  [ ] Problem  [ ] Confusing  [ ] Enhancement  [ ] Skipped
- Evidence filename:
- Problem-report ID:
- Notes:

**Continue?** Stop only if the app cannot open or crashes repeatedly.

### TEST-LAUNCH-02 — Understand the first screen

**Do this:** Without clicking, look at the first screen for ten seconds. Say or
write what you think the app is for and what action seems most important.

**What should happen:** Home should communicate private memory, Direction, one
obvious Save Clipboard action, and one Find/Ask action without requiring words
such as index, embedding, endpoint, provider, or manifest.

- [ ] Pass  [ ] Problem  [ ] Confusing  [ ] Enhancement  [ ] Skipped
- What I thought the app was for:
- What looked like the main action:
- Evidence filename:
- Problem-report ID:

---

## 2. Home and navigation

### TEST-NAV-01 — Find the three ordinary places

**Do this:** Find and visit Home, Library, and Settings. Return to Home.

**What should happen:** Exactly these three ordinary destinations are easy to
find. Research, Repositories, CAM, Mac Care, Modules, Meaning Preview, and
Approvals should not appear as ordinary destinations.

- [ ] Pass  [ ] Problem  [ ] Confusing  [ ] Enhancement  [ ] Skipped
- Unexpected destination, if any:
- Evidence filename:
- Problem-report ID:

### TEST-NAV-02 — Close sheets without getting trapped

**Do this:** In Settings, open Watched folders, Backup & Restore, and Advanced
one at a time. Close each with **Done**. Reopen one and press **Escape**.

**What should happen:** Every sheet has an obvious Done control. Escape closes
the open sheet. You always know how to return.

- [ ] Pass  [ ] Problem  [ ] Confusing  [ ] Enhancement  [ ] Skipped
- Which sheet was hardest to leave:
- Evidence filename:
- Problem-report ID:

---

## 3. Save Clipboard

### TEST-SAVE-01 — Save the prepared note

**Do this:**

1. Copy the exact clipboard paragraph from the Start Here guide.
2. Return to Home.
3. Choose **Save Clipboard** once.

**What should happen:** Within about one second, the app confirms in ordinary
language that the item was saved to the Library. The original clipboard text
must remain unchanged. No Local AI server is running, and saving should still
work.

- [ ] Pass  [ ] Problem  [ ] Confusing  [ ] Enhancement  [ ] Skipped
- Approximate response time:
- Message shown:
- Evidence filename:
- Problem-report ID:

**Continue?** Stop if unrelated clipboard content appears or the copied text is
changed.

### TEST-SAVE-02 — Avoid an accidental duplicate

**Do this:** With the same paragraph still copied, choose **Save Clipboard** a
second time.

**What should happen:** The app explains that the item was already saved. It
does not create a second Library item and does not expose storage jargon.

- [ ] Pass  [ ] Problem  [ ] Confusing  [ ] Enhancement  [ ] Skipped
- Message shown:
- Evidence filename:
- Problem-report ID:

### TEST-SAVE-03 — Handle an empty clipboard safely

**Do this:** Copy nothing if you can do so safely, or skip this test if clearing
the clipboard is inconvenient. Choose Save Clipboard.

**What should happen:** The app says there is nothing to save and suggests a
clear next action. It does not crash or create a blank Library item.

- [ ] Pass  [ ] Problem  [ ] Confusing  [ ] Enhancement  [ ] Skipped
- Message shown:
- Evidence filename:
- Problem-report ID:

---

## 4. Library and search

### TEST-LIB-01 — Recognize the saved item

**Do this:** Open Library and find the clipboard note without searching.

**What should happen:** The row has a recognizable title, saved date, preview,
and type. It does not lead with a hash, UUID, passage ID, or extractor name.

- [ ] Pass  [ ] Problem  [ ] Confusing  [ ] Enhancement  [ ] Skipped
- Title shown:
- Evidence filename:
- Problem-report ID:

### TEST-LIB-02 — Search by remembered words

**Do this:** Search for `east office` and open the matching item.

**What should happen:** The clipboard note appears as a match. Opening it shows
the exact saved text and a recognizable explanation of where it came from.

- [ ] Pass  [ ] Problem  [ ] Confusing  [ ] Enhancement  [ ] Skipped
- Evidence filename:
- Problem-report ID:

### TEST-LIB-03 — Inspect technical details only when requested

**Do this:** Open the item's Details or Technical details section, then close
the item using Close, Done, or Escape.

**What should happen:** Technical identity and integrity information are
available but were not required to recognize or search for the item. Closing
the detail view is obvious.

- [ ] Pass  [ ] Problem  [ ] Confusing  [ ] Enhancement  [ ] Skipped
- Detail that was least understandable:
- Evidence filename:
- Problem-report ID:

---

## 5. Ask without Local AI

Confirm Ollama or LM Studio is still stopped. In Settings → Local AI, choose
**Check Again** if available.

### TEST-ASK-01 — See an honest offline state

**What should happen:** Settings says Local AI is not running or unavailable in
plain language. It does not ask for a cloud account, silently choose another
provider, or make Library unusable.

- [ ] Pass  [ ] Problem  [ ] Confusing  [ ] Enhancement  [ ] Skipped
- Status shown:
- Evidence filename:
- Problem-report ID:

### TEST-ASK-02 — Find supported information without a model

**Do this:** On Home, ask exactly:

```text
Where is the Wednesday planning call?
```

**What should happen:** The same Ask action returns a local matching passage or
an extractive answer showing `east office`. It includes a source that opens the
correct Library item. It should not pretend Local AI generated the result.

- [ ] Pass  [ ] Problem  [ ] Confusing  [ ] Enhancement  [ ] Skipped
- Answer or passage shown:
- Source label shown:
- Evidence filename:
- Problem-report ID:

**Continue?** Stop if the source does not contain the displayed factual claim.

### TEST-ASK-03 — Refuse an unsupported answer

**Do this:** Ask exactly:

```text
What time does the purple lighthouse close?
```

**What should happen:** The app says it lacks enough information or displays no
matching support. It must not invent a time or cite the planning-call note as
support for a lighthouse claim.

- [ ] Pass  [ ] Problem  [ ] Confusing  [ ] Enhancement  [ ] Skipped
- Exact answer shown:
- Evidence filename:
- Problem-report ID:

**Continue?** Stop immediately if the app presents an invented closing time as
supported.

### TEST-ASK-04 — Open the citation

**Do this:** Ask `What should I bring to the Wednesday planning call?` and open
the source shown with the result.

**What should happen:** The answer or matching passage says `blue folder`. The
source opens the exact Library item containing those words.

- [ ] Pass  [ ] Problem  [ ] Confusing  [ ] Enhancement  [ ] Skipped
- Number of clicks needed to reach the source:
- Evidence filename:
- Problem-report ID:

---

## 6. Keep, duplicate choice, restart, and Undo

### TEST-KEEP-01 — Keep one useful result

**Do this:** From a supported planning-call result, choose **Keep**.

**What should happen:** The app confirms that one concise cited memory was
kept. It does not save an entire chat transcript.

- [ ] Pass  [ ] Problem  [ ] Confusing  [ ] Enhancement  [ ] Skipped
- Confirmation shown:
- Evidence filename:
- Problem-report ID:

### TEST-KEEP-02 — Find the kept memory after restart

**Do this:** Quit with Command-Q, reopen the app, and find the kept result in
Home or Library.

**What should happen:** The kept memory remains, including its source. The
ordinary three-place navigation and saved Library item also remain.

- [ ] Pass  [ ] Problem  [ ] Confusing  [ ] Enhancement  [ ] Skipped
- Where the kept memory appeared:
- Evidence filename:
- Problem-report ID:

### TEST-KEEP-03 — Require a duplicate/update choice

**Do this:** Ask the same supported question again and choose Keep.

**What should happen:** If the result is similar to the existing memory, the
app asks whether to update the existing memory or save separately. It must not
silently merge or overwrite.

- [ ] Pass  [ ] Problem  [ ] Confusing  [ ] Enhancement  [ ] Skipped
- Choice shown:
- Evidence filename:
- Problem-report ID:

### TEST-KEEP-04 — Undo only the latest Keep

**Do this:** Complete the second Keep using either offered choice, then use
**Undo Keep**.

**What should happen:** Only the most recent Keep operation is reversed. The
original captured source and earlier valid state remain.

- [ ] Pass  [ ] Problem  [ ] Confusing  [ ] Enhancement  [ ] Skipped
- What remained after Undo:
- Evidence filename:
- Problem-report ID:

**Continue?** Stop if Undo removes original source material or unrelated kept
items.

---

## 7. Direction: people and promises

### TEST-DIR-01 — Understand the Direction strip

**Do this:** Return Home and inspect Direction before opening it.

**What should happen:** Direction appears as a small part of Home, not a fourth
destination or a companion-chat identity. Empty-state wording explains how to
add a person, promise, or direction.

- [ ] Pass  [ ] Problem  [ ] Confusing  [ ] Enhancement  [ ] Skipped
- What I thought Direction was for:
- Evidence filename:
- Problem-report ID:

### TEST-DIR-02 — Add the fictional profile

**Do this:** Add the prepared Jordan Lee person, promise, and north star from
the Start Here guide.

**What should happen:** The Direction strip displays Jordan and the open
promise in recognizable language. No real contact permission or online account
is required.

- [ ] Pass  [ ] Problem  [ ] Confusing  [ ] Enhancement  [ ] Skipped
- Hardest field to understand:
- Evidence filename:
- Problem-report ID:

### TEST-DIR-03 — Complete and reopen a promise

**Do this:** Mark the promise Done. Open Manage, find the completed promise, and
reopen it.

**What should happen:** Done removes it from the open-promises display without
deleting it. Manage lets you find and reopen it. Removing a person or promise,
if tested, asks for confirmation.

- [ ] Pass  [ ] Problem  [ ] Confusing  [ ] Enhancement  [ ] Skipped
- Evidence filename:
- Problem-report ID:

### TEST-DIR-04 — Preserve Direction after restart

**Do this:** Quit and reopen CAM Assistant.

**What should happen:** Jordan, the reopened promise, and the north star remain.

- [ ] Pass  [ ] Problem  [ ] Confusing  [ ] Enhancement  [ ] Skipped
- Evidence filename:
- Problem-report ID:

---

## 8. Live Local AI Ask and Talk

Start Ollama or LM Studio, load the installed model, and start its local server.
In CAM Assistant Settings → Local AI, choose **Check Again**.

### TEST-AI-01 — Detect and select the local model

**What should happen:** Settings changes to a ready/detected state and offers a
recognizable model name. A longer technical model ID may appear as secondary
information. No cloud key is required.

- [ ] Pass  [ ] Problem  [ ] Confusing  [ ] Enhancement  [ ] Skipped
- Status shown:
- Friendly model name:
- Full model ID, if shown:
- Evidence filename:
- Problem-report ID:

### TEST-AI-02 — Produce a grounded local answer

**Do this:** Ask exactly:

```text
Summarize the Wednesday planning call in one sentence.
```

**What should happen:** If the selected local model is healthy, the app may
produce a concise answer containing only supported details: Wednesday, 10:00
AM, east office, and blue folder. Citations open the planning-call source. If
the model fails or abstains, the app should fall back only to already retrieved
local passages—not cloud or an invented answer.

- [ ] Pass  [ ] Problem  [ ] Confusing  [ ] Enhancement  [ ] Skipped
- Exact answer shown:
- Citation opened correctly: yes / no
- Evidence filename:
- Problem-report ID:

**Continue?** Stop if any factual detail is unsupported by the cited source.

### TEST-AI-03 — Admit missing knowledge with Local AI running

**Do this:** Ask the purple lighthouse question again.

**What should happen:** Local AI does not invent an answer. The app visibly
admits missing support or returns no matching evidence.

- [ ] Pass  [ ] Problem  [ ] Confusing  [ ] Enhancement  [ ] Skipped
- Exact answer shown:
- Evidence filename:
- Problem-report ID:

### TEST-AI-04 — Use Direction Talk with Library support

**Do this:** Open Direction Talk and ask:

```text
What should I remember about Wednesday's planning call?
```

**What should happen:** Talk either cites the planning-call Library source with
supported details or honestly says it does not have enough Library support. It
must not invent a personal history, relationship, or completed promise.

- [ ] Pass  [ ] Problem  [ ] Confusing  [ ] Enhancement  [ ] Skipped
- Exact response shown:
- Source opened correctly: yes / no / no source because it admitted absence
- Evidence filename:
- Problem-report ID:

### TEST-AI-05 — Keep offline usefulness after model shutdown

**Do this:** Stop the local server, choose Check Again, then search Library and
ask `east office` once more.

**What should happen:** Local AI shows not running, but Library search and the
model-free Ask result still work.

- [ ] Pass  [ ] Problem  [ ] Confusing  [ ] Enhancement  [ ] Skipped
- Evidence filename:
- Problem-report ID:

---

## 9. Watched-folder capture

### TEST-WATCH-01 — Add the prepared folder

**Do this:** In Settings → Capture or Watched folders, add the prepared
`Watched Folder` directory.

**What should happen:** The folder is added in a paused state. Merely selecting
it does not silently start broader file access.

- [ ] Pass  [ ] Problem  [ ] Confusing  [ ] Enhancement  [ ] Skipped
- State shown immediately after adding:
- Evidence filename:
- Problem-report ID:

### TEST-WATCH-02 — Enable automatic local capture

**Do this:** Explicitly enable the folder. Wait briefly, then look for
`garden-key.txt` in Library. Use Refresh only if the interface offers it and
the item does not appear automatically.

**What should happen:** The file appears once with a recognizable name, preview,
and watched-folder provenance. The original file still exists with exactly the
same sentence.

- [ ] Pass  [ ] Problem  [ ] Confusing  [ ] Enhancement  [ ] Skipped
- Time until item appeared:
- Needed Refresh: yes / no
- Original file unchanged: yes / no
- Evidence filename:
- Problem-report ID:

**Continue?** Stop if the original file was moved, renamed, edited, or deleted.

### TEST-WATCH-03 — Ask about watched content

**Do this:** Ask exactly:

```text
Where is the blue garden key?
```

**What should happen:** The result says `kitchen drawer` and opens
`garden-key.txt` as its source. This must work without Local AI running.

- [ ] Pass  [ ] Problem  [ ] Confusing  [ ] Enhancement  [ ] Skipped
- Exact result shown:
- Evidence filename:
- Problem-report ID:

### TEST-WATCH-04 — Confirm before removing the folder

**Do this:** Choose Remove for the watched folder, cancel the confirmation once,
then choose Remove again and confirm.

**What should happen:** The first attempt changes nothing after Cancel. The
confirmed removal stops watching but does not delete `garden-key.txt` or its
already saved Library item.

- [ ] Pass  [ ] Problem  [ ] Confusing  [ ] Enhancement  [ ] Skipped
- Original file remained: yes / no
- Library item remained: yes / no
- Evidence filename:
- Problem-report ID:

---

## 10. Restart and persistence

### TEST-RESTART-01 — Preserve ordinary state

**Do this:** Quit the app completely, reopen it, and check Home, Library,
Direction, and Settings.

**What should happen:** Captured sources, kept memories not undone, Jordan,
promises, north star, and settings remain. Removed watched-folder configuration
stays removed. The app does not require a network connection to show local data.

- [ ] Pass  [ ] Problem  [ ] Confusing  [ ] Enhancement  [ ] Skipped
- Missing item, if any:
- Evidence filename:
- Problem-report ID:

---

## 11. Backup, validation, and fresh restore

### TEST-BACKUP-01 — Create a local backup

**Do this:** In Settings → Backup & Restore, create a backup in the Desktop run
folder named `CAM-Second-Mac-Test.camvault`.

**What should happen:** The app reports success and does not delete or replace
the live Library. The backup exists at the chosen location.

- [ ] Pass  [ ] Problem  [ ] Confusing  [ ] Enhancement  [ ] Skipped
- Backup location shown:
- Evidence filename:
- Problem-report ID:

### TEST-BACKUP-02 — Validate the backup

**Do this:** Use the app's Validate action on the new backup.

**What should happen:** Validation clearly reports that the package is valid.
It does not silently restore or switch the current Library.

- [ ] Pass  [ ] Problem  [ ] Confusing  [ ] Enhancement  [ ] Skipped
- Validation message:
- Evidence filename:
- Problem-report ID:

### TEST-BACKUP-03 — Restore only to a fresh destination

**Do this:** Choose the backup and restore it into the prepared empty `Restore
Destination` folder. Do not choose the current application-data location.

**What should happen:** The app preflights the backup, restores into the fresh
destination, and reports success. It refuses an unsafe overwrite. Restored
watched folders are paused. The live Library remains unchanged.

- [ ] Pass  [ ] Problem  [ ] Confusing  [ ] Enhancement  [ ] Skipped
- Restore message:
- Watched-folder pause explained: yes / no
- Live Library unchanged: yes / no
- Evidence filename:
- Problem-report ID:

**Continue?** Stop if the app attempts to overwrite live data or cannot explain
the restore destination.

---

## 12. Accessibility and general ease

### TEST-ACCESS-01 — Complete the main path with the keyboard

**Do this:** Use Tab and Shift-Tab to move through Home controls. Press Escape
to close a sheet. If you know the app's open shortcut, try it once.

**What should happen:** Focus is visible, important controls are reachable, and
Escape works. No keyboard trap prevents returning to the main app.

- [ ] Pass  [ ] Problem  [ ] Confusing  [ ] Enhancement  [ ] Skipped
- Control that could not be reached:
- Evidence filename:
- Problem-report ID:

### TEST-ACCESS-02 — Check readability and plain language

**Do this:** Review Home, Library, Settings, Direction, backup messages, and one
error/empty state. Note any text that is too small, clipped, overly technical,
or difficult to understand.

**What should happen:** Primary actions and statuses use familiar language.
Technical details remain optional. Text is readable without overlapping or
being cut off at the Mac's current display settings.

- [ ] Pass  [ ] Problem  [ ] Confusing  [ ] Enhancement  [ ] Skipped
- Least understandable wording:
- Smallest or clipped text:
- Evidence filename:
- Problem-report ID:

### TEST-ACCESS-03 — Explain privacy in your own words

Without rereading the documentation, answer:

1. Where is captured content stored?
2. Which features still work when Local AI is stopped?
3. Did CAM Assistant silently use a cloud model during this test?
4. What happens to an answer before and after Keep?

**What should happen:** The interface supports the understanding that captured
content stays on this Mac; capture, Library, search, model-free Ask, Keep, and
backup remain local; no silent cloud fallback occurred; and answers are
ephemeral until explicitly kept.

- [ ] Pass  [ ] Problem  [ ] Confusing  [ ] Enhancement  [ ] Skipped
- My answers:
- Evidence filename:
- Problem-report ID:

---

## 13. Final assessment

### TEST-FINAL-01 — Repeat the main workflow without instructions

Close this checklist. Using a new harmless sentence of your own that contains
no private information, try to Save it, find it in Library, Ask about it, open
its source, and Keep or Discard the result. Reopen the checklist afterward.

**What should happen:** You can repeat the core workflow without step-by-step
instructions or technical knowledge.

- [ ] Pass  [ ] Problem  [ ] Confusing  [ ] Enhancement  [ ] Skipped
- Where I hesitated:
- Evidence filename:
- Problem-report ID:

### TEST-FINAL-02 — Give the product verdict

Complete [`NOVICE_TEST_RESULTS.md`](NOVICE_TEST_RESULTS.md). Do not mark an
untested or skipped behavior as passing.

- [ ] Completed results page
- [ ] Indexed every problem report
- [ ] Reviewed screenshots for private information
- [ ] Recorded the single most valuable improvement

