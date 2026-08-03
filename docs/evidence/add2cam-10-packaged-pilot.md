# ADD2CAM-50 Packaged Pilot Evidence

**Date:** 2026-08-03  
**Branch:** `agent/add2cam-50-packaged-pilot`  
**Terminal commit:** `65e6e3d6790936193063f2ace045666a358b0297`  
**Status:** Packaged native journey **PASS** (software proof). Human pilot (ADD2CAM-60) remains pending and human-only.

## Command

```zsh
cd /private/tmp/cam-add2cam-20260731/packaged-pilot
/bin/zsh Tests/ReleaseProofTests/meaning-preview-packaged-journey-tests.sh
```

## Result (verbatim summary)

```
capture=pass
enable=pressed
settings=closed
preview=selected
grant=pressed
result=card action=now feedback=helpful
disable=pass
restart=disabled
CAM_ASSISTANT_MEANING_PREVIEW_PACKAGED status=pass commit=65e6e3d6790936193063f2ace045666a358b0297 resources=exact result=card action=now feedback=helpful permissions=exact audit=status-only audit_outbound_bytes=0 sockets_point_in_time=0 restart=disabled
```

## Required state sequence proven

1. Disabled / no Meaning Preview sidebar  
2. Enable → `enabled` with `permission_count=0`  
3. Close settings with permissions still zero  
4. Select Meaning Preview workspace with permissions still zero  
5. Explicit workspace Grant → `permission_count=2` (`readLocal`, `writeLocal`)  
6. Request → card → Inspect → Now → second Request → Helpful  
7. Disable → sidebar gone  
8. Restart → remains disabled; isolated Preview DB retained  

## Product fixes on this branch

| Commit | Fix |
|---|---|
| `53ca916` | Explicit Close control for Meaning Preview settings (Escape unreliable) |
| `c2aed25` | Grant is **workspace-only**; settings Enable cannot double-activate Grant |
| `ca7712f` | Auto-select sole active library source after grant (Picker AX unreliable) |
| `58ae854` | Inspect sheet Done control with stable accessibility id |
| `b05d36c` / `c08746a` | Harness retries transient AX incompleteness |
| `65e6e3d` | Order-stable ordinary vault table containment compare |

## Boundaries preserved

- Disposable Application Support root only  
- No production vault  
- Ordinary vault table fingerprints unchanged through exercise  
- Status-only Meaning Preview audit; zero outbound bytes in receipts  
- Point-in-time zero network sockets on the pilot process  
- Named-model reflection remained unavailable (no fallback)  

## Limitations

- Synthetic disposable context only — not lived-use human evidence  
- Sole-source auto-select is intentional pilot UX when exactly one active source exists  
- Aggregate `verify.sh all` / fresh-clone and integrator cherry-pick remain separate serial steps after this evidence packet  
- ADD2CAM-60 must not be started by agents  
