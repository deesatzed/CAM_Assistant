# Direction packaged journey evidence

**Date:** 2026-08-09  
**Command:** `/bin/zsh scripts/verify.sh barebones-packaged`  
**Result:** `CAM_ASSISTANT_BAREBONES_PACKAGED status=pass` (exit 0)

## What the packaged proof covers for Direction

In addition to barebones capture → model-free Ask → Keep → backup/restore:

1. Writes `direction-profile.json` with person **Jordan** and promise **Call this week**.
2. Full-vault package includes Direction state (recognized `LocalVaultStateFile.directionProfile`).
3. Restore to fresh root reloads person and open promise unchanged.
4. Watched sources still restored paused; Keep memory path still green.

## Related unit evidence

- `DirectionProfileStoreTests` — CRUD, restart, validation  
- `DirectionTalkCoordinatorTests` — offline coach, admit absence, profile continuity, library grounded  
- `fullVaultPackageCapturesDirectionProfile` — backup/restore isolated  
- Home presentation tests — strip copy + Home embeds `DirectionStripView`  

## Not claimed

- Gate D6 human pilot  
- Live named-model Talk quality beyond unit wiring  
- Barebones Gate 7 human pilot  
