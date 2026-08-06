# Barebones General-User Pilot

**Status:** Ready to run; no human result has been recorded.

**Build:** internal unsigned macOS app from branch
`feat/barebones-user-first-reset`.

## Purpose

This is the human-only Gate 7. The participant should be comfortable using an
iPhone or Mac but should not need developer knowledge. A developer may observe
and take notes, but must not tell the participant which control to press after
the journey begins.

Use a temporary Standard macOS user account so the test starts fresh without
touching anyone's existing CAM Assistant content. Do not use real secrets,
health information, financial information, or other sensitive data.

## Observer setup

1. In **System Settings > Users & Groups**, create a temporary **Standard**
   account named `CAM Pilot`. This may require an administrator password.
2. Sign out and sign into `CAM Pilot`.
3. Put `CAM Assistant.app` in the account's **Applications** folder.
4. On the Desktop, create a folder named `CAM Pilot Folder`.
5. Open TextEdit, choose **Format > Make Plain Text**, and save this file in
   that folder as `garden-key.txt`:

   `The blue garden key is stored in the kitchen drawer.`
6. In TextEdit, create this separate sentence and copy it to the clipboard:

   `The Wednesday appointment starts at 10 in the east office.`
7. Start screen or written observation. Record exact participant words,
   hesitation, wrong turns, errors, and whether help was requested.
8. Tell the participant only: “Please use CAM Assistant to save the copied
   appointment, automatically watch the folder, find what you saved, ask about
   both facts, keep and undo one answer, and make a backup. Please think aloud.”

## Participant journey

The observer reads only a numbered goal if the participant asks what remains;
the observer does not name a button or location.

1. Open **CAM Assistant**. Because this build is unsigned, the first launch may
   require Control-clicking the app, choosing **Open**, and confirming **Open**.
   Record this as distribution friction, not product confusion.
2. Without opening Settings first, save the sentence already on the clipboard.
3. Save it a second time. Explain aloud whether CAM made a duplicate.
4. Go to the Library, find the appointment, and open it. Explain what the item
   is and where it came from.
5. Return Home. Ask exactly: `Wednesday appointment`. Open the shown source.
6. Keep that answer. Quit CAM Assistant with **Command-Q**, reopen it, and find
   the kept answer.
7. Ask `Wednesday appointment` again, Keep it if needed, then use **Undo Keep**.
   Confirm that only the last Keep was reversed.
8. Add `CAM Pilot Folder` as a watched folder and explicitly enable it. Wait for
   `garden-key.txt` to appear in the Library, using Refresh if necessary.
9. Ask exactly: `blue garden key`. Open its source and explain whether the
   answer is supported by the saved file.
10. Ask exactly: `purple lighthouse schedule`. Explain whether CAM clearly
    says it lacks support instead of inventing an answer.
11. Create a backup named `CAM-Pilot-Backup.camvault` on the Desktop. Validate
    that backup. Explain in your own words what the backup contains.
12. Create a Desktop folder named `CAM Restored Test`. Restore the backup there
    as a new vault. Confirm that CAM reports success and says watched folders
    are paused in the restored copy.
13. Answer aloud:
    - “Where does the content I saved live?”
    - “Did anything go online during this journey?”
14. Give a final 1-to-5 ease rating and name the single most confusing moment.

## Pass criteria

Gate 7 passes only when the participant, without control-level coaching:

- recognizes Home, Library, and Settings and completes the journey;
- understands that the duplicate was not saved as a second item;
- distinguishes a supported result from an unsupported question;
- reaches and understands a cited source;
- understands Keep, restart persistence, and exact Undo;
- creates and explains a local backup and understands that restore is separate
  and watched folders are paused; and
- answers that saved content remains on this Mac and that the model-free journey
  did not send content online.

Gate 7 fails or remains incomplete if the participant needs control-level
coaching, cannot recover from ordinary friction, misunderstands the privacy or
backup boundary, sees unsupported content presented as fact, or cannot finish.
Do not average away a privacy, data-loss, unsupported-answer, or recovery
failure.

## Result record

- Date:
- Participant description (no name):
- Build commit:
- Completed unaided: yes / no
- Save and duplicate:
- Find and source:
- Supported Ask:
- Unsupported Ask:
- Keep, restart, Undo:
- Watched folder:
- Backup, validation, restore:
- “Where does content live?” answer:
- “Did anything go online?” answer:
- Ease rating:
- Most confusing moment:
- Observer interventions:
- Final Gate 7 verdict: PASS / FAIL / INCOMPLETE
