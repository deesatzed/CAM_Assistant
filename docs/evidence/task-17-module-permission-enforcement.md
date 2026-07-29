# Task 17 Module Permission Enforcement Evidence

**Date:** 2026-07-28
**Verified commit:** `ada0a99974c921b5dff9f61258519f10cd714ae7`
**Scope:** Discovery, enablement, grants, capability advertisement, disable,
restart, and isolated health behavior

## Current proof

`ModuleRegistry.capabilities()` exposes a module capability only when all
three conditions hold:

1. the module is enabled;
2. every permission declared by its manifest is present in the separately
   persisted grant set; and
3. the module reports healthy.

Discovery and enablement never write a grant. A partial grant exposes no
capability. Revoking grants withdraws capabilities. Disabling a non-core
module clears its grants, and the state survives restart. An unhealthy module
withdraws only its own capabilities.

Focused verification:

```text
./scripts/verify.sh modules
```

Result:

```text
7 tests passed
```

The suite directly covers zero, partial, and complete grant sets; enable,
disable, revoke, reload, and restart; isolated health failure; duplicate IDs;
and invalid manifests.

## Claim boundary

This proves that discovery or enablement grants no permissions and that the
registry capability surface fails closed without every declared grant. It
does not prove permission-change receipts, expected-state revisions, native
permission review, packaged installation, real manifest health execution,
signature/trust policy, typed module dispatch, or uninstall.
