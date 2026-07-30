# ADD2CAM-01 Dependency And Provenance Receipt

Date: 2026-07-30

## Pin

- CAM Assistant commit before this task: `df36a6d2857e52f8c1782813e581268e83b08aee`
- MeaningCore repository: `https://github.com/deesatzed/meaningcore.git`
- Pinned revision: `23db68044ebdc410edf3b7f436e433ffba6e94b8`
- Product used: library product `MeaningCore` only; `MeaningCoreCLI` is not a
  CAM dependency.
- `git ls-remote` for upstream `main` returned the same revision on
  2026-07-30.
- The source checkout was clean at that revision and was not modified. Its
  independent aggregate verifier was run from a disposable clone at
  `/private/tmp/meaningcore-add2cam-proof`.

## Verification

The expected-red dependency test first failed with `no such module
'MeaningCore'`. After the exact SwiftPM pin resolved:

```text
swift package resolve --disable-sandbox
swift test --disable-sandbox --scratch-path .swift-build-add2cam \
  --filter MeaningCoreDependencyTests
swift build --disable-sandbox --scratch-path .swift-build-add2cam-release -c release
```

The focused CAM test passed. The fresh release build produced the native
`CAMAssistant` binary in its isolated scratch directory. The independently
cloned MeaningCore verifier passed: 104 tests, release build, 40 deterministic
scenario replays, forbidden-public-surface scan, and host-neutral-boundary
scan.

## Licensing Stop

No `LICENSE`, `COPYING`, or equivalent license grant exists in the pinned
MeaningCore checkout. This is recorded as **unlicensed / distribution rights
unknown**, not as an implied open-source license. Consequently, the package is
technically compatible for local development, but a packaged or distributed
Meaning Preview pilot cannot satisfy GOAL_ADD2CAM Gate 1 until the MeaningCore
owner supplies and records an explicit compatible license or distribution
grant. No further Meaning Preview implementation is authorized under the
goal's legal-uncertainty stop condition.

## Runtime Boundary

Once dependencies have been resolved, this package pin introduces no network
behavior into the packaged runtime. It does not enable Meaning Preview, grant
data/model/network permissions, or alter ordinary CAM behavior.
