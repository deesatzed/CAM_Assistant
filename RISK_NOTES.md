# RISK_NOTES.md

## Risks

| Risk | Severity | Why It Matters | Mitigation |
|---|---|---|---|
| Twelve peer workspaces obscure the primary journey | High | Users see subsystems instead of a coherent assistant | Reduce default navigation to Home, Library, and Settings |
| `AppModel.swift` is 4,005 lines | High | Unrelated lifecycle state is coupled and difficult to change safely | Extract feature coordinators only as each simplified feature is rebuilt |
| Task tracker completion conflicts with product gate status | High | "Complete" component labels can hide partial user outcomes | Make the gate map and packaged journey the release authority |
| Specialist systems dominate code volume | High | CAM, repositories, research, and Meaning exceed the core journey in complexity | Park them behind developer/experimental boundaries |
| Synthetic contracts may be mistaken for real utility | High | Passing tests do not prove named-model quality or daily usefulness | Require representative packaged and human evidence per feature |
| Untracked foreign files and nested Git repo at root | High | Easy to bundle, edit, or publish unrelated work accidentally | Preserve now; quarantine only through a separately approved bounded move |
| Provider/OpenRouter path expands privacy and credential surface | High | Adds network, Keychain, provider, and disclosure complexity | Exclude it from the first simplified release |
| Meaning Preview human value is unknown | Medium | Large recent investment may bias product decisions | Keep opt-in and isolated; use the approved human pilot before promotion |
| Mac Care and module UI overstate current usefulness | Medium | Read-only/manual behavior and word counts feel like demos | Remove from default navigation; retain underlying proofs |
| Old reports contain fixed findings | Medium | Stale P0 lists can send work toward already-resolved defects | Prefer current code, current tests, and dated gate receipts |
| Fresh-clone verification was skipped today | Low | Today’s run does not independently reproduce a clean checkout | Run only after the reset documents and root-boundary decision stabilize |

## Safe Next Step

Create a controlling reset goal for a three-place shell and a single Capture ->
Library acceptance journey. Preserve all existing code and tests until the new
shell proves the core value, then retire or extract specialist surfaces one at
a time.
