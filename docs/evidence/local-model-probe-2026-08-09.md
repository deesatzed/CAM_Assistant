# Local model probe — 2026-08-09

## Result

**No local OpenAI-compatible server was reachable** on this host at probe time.

```text
DOWN  http://127.0.0.1:1234/v1/models
DOWN  http://127.0.0.1:11434/v1/models
DOWN  http://localhost:1234/v1/models
DOWN  http://localhost:11434/v1/models
status=none_ready
```

Script: `scripts/probe-local-models.sh`  
Raw log: `docs/evidence/local-model-probe-2026-08-09.txt`

## What was still proven (no mock)

| Path | Proof |
|------|--------|
| Offline Find / matching passages | Unit: LocalAnswerCoordinatorTests |
| Offline Talk coach | Unit: DirectionTalkCoordinatorTests |
| Cite-or-admit when empty Library | Unit: DirectionTalkCoordinatorTests |
| Packaged barebones + Direction | `scripts/verify.sh barebones-packaged` → **status=pass** |

## How to re-prove live synthesis later

1. Start LM Studio or Ollama with an OpenAI-compatible endpoint.  
2. Run `/bin/zsh scripts/probe-local-models.sh` until READY.  
3. Settings → Local AI → Check Again → Ask / Talk with real content.  
4. Append evidence under `docs/evidence/` with date — no fabricated responses.
