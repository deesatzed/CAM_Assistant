# Primary UX click / selection audit (Pattern A)

**Date:** 2026-08-09  
**Scope:** Ordinary product only — Home, Library, Settings (+ sheets).  
**Needs:** N4 memory body, N3 Direction strip.  
**Not in ordinary scope:** Developer specialist nav (Research, CAM, Meaning Preview workspace, etc.).

Legend:

| Mark | Meaning |
|------|---------|
| ✅ | Acceptable for ordinary use |
| ⚠️ | Works but friction / partial |
| ❌ | Broken, trap, or wrong scope |
| Esc | Escape / Done / cancel available |

---

## Global chrome

| Control | Works | Friendly | Esc | Need-fit |
|---------|-------|----------|-----|----------|
| Sidebar **Home** | ✅ | ✅ plain | ✅ (always visible) | N4 + N3 home |
| Sidebar **Library** | ✅ | ✅ | ✅ | N4 find |
| Sidebar **Settings** | ✅ | ✅ | ✅ | config for N4 |
| Window close (traffic light) | ✅ macOS | ✅ | ✅ | leave app |
| Footer offline status | ✅ | ✅ | n/a | trust / privacy |

Specialist sections are **not** listed in production sidebar (`AppExperience.primary`).

---

## Home

| Control | Works | Friendly | Esc | Need-fit | Notes / fix |
|---------|-------|----------|-----|----------|-------------|
| Welcome copy | ✅ | ✅ | n/a | N4 | |
| **Direction** strip (readout) | ✅ (new build) | ✅ empty invites | n/a | **N3** | Rebuild if missing in UI |
| Add person | ✅ sheet | ✅ | ✅ Done/Esc chrome | N3 | |
| Add promise | ✅ sheet | ✅ | ✅ | N3 | No “mark done” yet → ⚠️ |
| Edit north star | ✅ sheet | ✅ renamed from “Direction” | ✅ | N3 | Fixed label |
| Talk | ✅ sheet | ⚠️ coach vs model | ✅ Close/Esc | N3 | Offline coach honest |
| Save Clipboard | ✅ | ✅ | n/a | **N4** core | |
| Watch a Folder… | ✅ → Settings sheet | ⚠️ multi-step | ✅ Done/Esc | N4 capture | Trap fixed |
| Capture status / Try Again | ✅ | ✅ | n/a | N4 | |
| Technical details disclosure | ✅ | ✅ progressive | n/a | power users | |
| Find field + Ask | ✅ | ✅ | n/a | **N4** | |
| Local AI status line | ✅ | ✅ | n/a | sets expectation | |
| Answer text | ✅ | ✅ | n/a | N4 | |
| Show in Library (citation) | ✅ | ✅ friendlier label | n/a | N4 trust | Was “Open source N” |
| Keep / Discard | ✅ | ✅ | Discard = cancel answer | N4 Keep | |
| Update / Save Separately | ✅ | ✅ | n/a | N4 | |
| Undo Keep | ✅ | ✅ | undo escape | N4 | |
| Answer Details disclosure | ✅ | ✅ | n/a | progressive | |
| Recently kept rows | ✅ → Library | ✅ now tappable | n/a | N4 | Was dead display |

---

## Library

| Control | Works | Friendly | Esc | Need-fit | Notes / fix |
|---------|-------|----------|-----|----------|-------------|
| Refresh | ✅ | ✅ | n/a | N4 | |
| Search field | ✅ | ✅ | clear text = reset filter | N4 | |
| Type picker | ✅ | ✅ | All = reset | N4 | |
| Item row click | ✅ opens detail | ✅ | **Close** + Esc on Close button | N4 | Close added |
| Item preview / text select | ✅ | ✅ | n/a | N4 | |
| More about this item | ✅ | ✅ | n/a | progressive | Renamed from “Details” |
| Verify original… | ✅ | ✅ plainer | n/a | trust | |
| Hide / Restore lifecycle | ✅ | ⚠️ label from core | n/a | landfill control | |
| Technical identifiers | ✅ nested | ✅ nested | n/a | power users | Hashes not on primary row |
| Kept answers list | ✅ | ✅ | n/a | N4 Keep | |
| Show source in Library | ✅ | ✅ | n/a | N4 | |
| Hidden items restore | ✅ | ✅ | disclosure | N4 | |
| Empty / no search hits | ✅ | ✅ | n/a | | |

---

## Settings (root)

| Control | Works | Friendly | Esc | Need-fit |
|---------|-------|----------|-----|----------|
| Privacy note | ✅ | ✅ | n/a | trust |
| Capture card / Manage Folders | ✅ sheet | ✅ | ✅ Done/Esc | N4 |
| Shortcut hint ⌘⌥C | ✅ if hotkeys reg | ⚠️ Advanced to change | n/a | N4 |
| Local AI status | ✅ | ✅ | n/a | optional N4 Ask quality |
| Model picker (when detected) | ✅ | ⚠️ IDs technical | n/a | |
| Check Again | ✅ | ✅ | n/a | |
| Open Backup & Restore | ✅ sheet | ✅ | ✅ | recover need |
| Open Advanced Settings | ✅ sheet | ⚠️ power | ✅ Done/Esc | progressive |

---

## Sheet: Watched folders

| Control | Works | Friendly | Esc | Need-fit |
|---------|-------|----------|-----|----------|
| Done / Escape | ✅ chrome | ✅ + caption tip | ✅ | **was ❌ trap** |
| Enable / Pause | ✅ | ✅ | stay in sheet | N4 |
| Remove | ✅ | ⚠️ no confirm | stay | N4 |
| Add Folder… (NSOpenPanel) | ✅ | ✅ | panel Esc cancel | N4 |

---

## Sheet: Backup & Restore

| Control | Works | Friendly | Esc | Need-fit |
|---------|-------|----------|-----|----------|
| Done / Escape | ✅ | ✅ | ✅ | **was ❌ trap** |
| Create / Validate / Restore | ✅ panels | ✅ plain copy | panel cancel | recover |
| Never overwrite live vault | ✅ | ✅ stated | n/a | safety |

---

## Sheet: Advanced

| Control | Works | Friendly | Esc | Need-fit |
|---------|-------|----------|-----|----------|
| Done / Escape | ✅ | ✅ tip text | ✅ | **was ❌ trap** |
| Local AI Details (endpoints) | ✅ | ⚠️ builder | stay | optional model |
| Shortcuts | ✅ | ⚠️ raw keys | stay | hotkeys |
| **Meaning Preview tab** | **Removed** from ordinary Advanced | was dead-end | — | **out of primary scope** (parked pilot) |

Meaning Preview UI code remains for **developer experience** only; ordinary users no longer enter a grant-without-workspace maze.

---

## Direction sheets

| Sheet | Works | Friendly | Esc | Need-fit |
|-------|-------|----------|-----|----------|
| Who matters? | ✅ Save/Done | ✅ | ✅ | N3 |
| Promise | ✅ | ✅ | ✅ | N3 |
| North star | ✅ | ✅ | ✅ | N3 |
| Talk | ✅ | ⚠️ | ✅ Close | N3; cite-or-admit for Library |

**Gaps (honest):** no UI to remove person, mark promise done, or edit existing person without re-add.

---

## Out of ordinary product (do not audit as primary needs)

Developer-only when experience ≠ primary: Assistant chat, Activity, Tasks, Modules, CAM, Research, Repositories, Mac Care, Approvals, Meaning Preview workspace. These do **not** fulfill N3/N4 primary jobs and must not reappear in the sidebar without a new goal.

---

## Fixes applied this pass

1. Dismissible sheets (prior): Done + Escape on Capture / Backup / Advanced / Direction.  
2. Removed Meaning Preview from ordinary Advanced (scope trap).  
3. Library detail **Close** + `clearLibrarySelection()`.  
4. Friendlier citation buttons; nest technical IDs.  
5. Recently kept → opens Library.  
6. “Edit north star” label; Watch a Folder ellipsis + escape hint.

---

## UX backlog status

| Item | Status |
|------|--------|
| Mark promise done / remove person / Manage | **Done** (strip Done + Manage sheet + confirms) |
| Confirm before Remove folder | **Done** (confirmationDialog) |
| Hotkey editor more guided | **Done** (preview + normalize + tips) |
| Local model IDs plainer names | **Done** (`LocalModelDisplayName` + full id caption) |
| Human pilots G7 + D6 | **Still human-only** — protocols ready |

---

## How to verify after rebuild

```bash
cd CAM_Assistant
swift run CAMAssistant
```

Walk: Home Direction → Talk Esc → Save Clipboard → Ask → Keep → Library item Close → Settings Manage Folders Done → Advanced Esc → no Meaning Preview tab.
