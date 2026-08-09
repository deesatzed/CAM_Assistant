# Direction Gate Status

**Updated:** 2026-08-09 (post DIR-007)

| Gate | Meaning | Status | Evidence |
|------|---------|--------|----------|
| D1 | Strip on Home, plain language | PASS (machine) | `DirectionStripView` on Home; HomePresentationTests |
| D2 | Profile persist + backup/restore | PASS (machine) | DirectionProfileStoreTests; fullVaultPackageCapturesDirectionProfile; packaged proof |
| D3 | Offline Talk coach | PASS (machine) | DirectionTalkCoordinatorTests offline; AppModel `sendDirectionTalk` |
| D4 | Cite-or-admit Talk | PASS (machine unit) | Coordinator library grounded + admit absence tests; live model optional |
| D5 | Barebones non-regression + Direction packaged | PASS | `scripts/verify.sh barebones-packaged` → status=pass; `direction-packaged-journey.md` |
| D6 | Human Direction pilot | PENDING | `docs/pilots/direction-general-user-protocol.md` |

**Phase 2 complete for machine gates only.** Human D6 + barebones G7 remain open.
