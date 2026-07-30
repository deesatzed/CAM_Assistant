# ADD2CAM-02 Opt-In Meaning Preview Module Boundary

Date: 2026-07-30

`cam.meaning-preview` is a non-core native module. It declares only local
read/write permissions for explicitly selected derived context and its own
separate pilot state. It declares no web, cloud, model role, spend,
notification, shell, or external-action capability.

The manifest's sole capability, `meaning.preview.request`, is unavailable at
discovery and remains unavailable after enablement. The module registry test
proves that only an explicit grant of every declared permission can advertise
the capability. Enablement itself neither exposes context nor grants any
authority.

Verification:

```text
/bin/zsh scripts/verify.sh modules
```

All 11 focused module tests passed, including the Meaning Preview
discovery/enablement authority-boundary test.
