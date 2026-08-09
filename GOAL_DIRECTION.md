# CAM Assistant Direction Goal (N3 on Pattern A)

## Status

**Authorized** as Phase 2 of the ordinary product after barebones machine
Gates 1–6. Implementation must not start until the human reviews and approves
the Pattern A implementation plan.

**Does not replace** [`GOAL_BAREBONES.md`](GOAL_BAREBONES.md). Barebones remains
the N4 body and must stay green.

**Positioning source:**  
[`docs/plans/2026-08-09-n3-n4-pattern-a-positioning.md`](docs/plans/2026-08-09-n3-n4-pattern-a-positioning.md)  
and workspace  
[`../docs/plans/2026-08-09-n3-n4-pattern-a-positioning.md`](../docs/plans/2026-08-09-n3-n4-pattern-a-positioning.md).

---

## Product Promise (N3 strip)

On top of the private memory inbox, provide **continuity with people and
promises** without turning the app into a companion bot or a fourth primary
destination:

> While you save and find what you kept, a thin **Direction** strip always
> shows who matters and what you promised—and optional **Talk** that must
> cite your Library or admit it does not know.

Pattern A: **Memory is the body; Direction is the face (thin strip).**

---

## Relationship to Barebones

| Layer | Goal file | Need |
|-------|-----------|------|
| Body | `GOAL_BAREBONES.md` | N4 — capture, find, ask, Keep, recover |
| Face | this file | N3 — people, promises, direction, Talk |

### Sequencing rules

1. **Do not break** barebones Gates 1–6 packaged evidence or no-model /
   no-network utility for capture, find, Library, Keep, backup.
2. Barebones **Gate 7** (human pilot) remains required for barebones
   completion; Direction work may proceed in parallel only if it does not
   block or contaminate that pilot protocol.
3. Direction features are **absent from default navigation as specialist
   workspaces**. They live on **Home** as a strip/card, not Research /
   Meaning Preview / Modules.
4. **Meaning Preview** (ADD2CAM / parked specialist) is **not** the
   Direction product. Do not re-enable specialist navigation to satisfy N3.
5. Normal use still must not require Terminal, embeddings jargon, or
   endpoint literacy on the happy path.

---

## Default Product Additions

The ordinary app still has exactly three destinations: **Home**, **Library**,
**Settings**.

Home gains, above the save/find body:

1. **Direction strip** — people summary, open promises count or first open
   promise, one-line north star (or empty-state invites).
2. **Add person / Add promise** — short plain-language sheets; real humans
   only for people.
3. **Talk** — optional partner dialogue that receives:
   - direction profile (people, open commitments, north star);
   - retrieved Library evidence when the user asks about saved material;
   - hard rule: claims about “your stuff” must cite Library items or
     **admit absence**; never invent keeps.

Library and Settings primary groups are unchanged. Full-vault backup/restore
must include Direction profile data once it exists.

---

## Partner Stance (from MLX-SAGE; product ethics)

- Partner, not servant, romantic companion, or deity.
- People are real humans only — not AI “friends.”
- Commitments point toward a person or shared good.
- Human owns consequential decisions.
- Refusals: no parasocial “I love you” product behavior; no “you don’t need
  other people” framing; no ego-only goals presented as complete.

Stance is copy and system-prompt policy. It is not a claim of clinical care.

---

## Authority and Data Boundaries

- Direction profile is local, inspectable, and part of the vault backup set.
- Library source bytes remain authoritative for “what you saved.”
- Talk answers about captures are ephemeral until the user uses existing
  **Keep** (same Keep gate semantics as barebones).
- No cloud, web, CAM, or alternate provider is selected silently for Talk.
- If Local AI is unavailable, Talk shows an honest coach; Direction strip
  edit/view still works fully offline.
- Restricted data rules from barebones still apply to any model path.

---

## Proof Gates (Direction)

Each gate is independently verified. Component tests alone are not completion.

### Gate D1: Strip shell

Fresh production profile shows a Direction strip on Home in plain language.
Empty state invites one person and one promise without blocking capture or
find. No specialist sidebar destinations are reintroduced.

### Gate D2: Profile persistence

Add/edit/remove person and promise; set north star; survive restart; appear
in full-vault backup and restore into a fresh root without clobbering live
data. Self-tests cover codec and store IO.

### Gate D3: Offline Direction

With Local AI off or unhealthy, strip and profile edits work; Talk refuses
synthesis with a clear non-technical message and never fabricates partner
text.

### Gate D4: Cite-or-admit Talk

With a health-checked local model, Talk about Library content either:

- returns an answer with valid citations to current Library items, or  
- admits insufficient material;

never invents sources. Talk that is only about people/promises (no library
claim) need not cite captures but must not invent Library items.

### Gate D5: Barebones non-regression

Packaged barebones journey (or equivalent repository-owned proof) still
passes for capture, model-free find/ask path, Keep, backup; primary shell
remains Home / Library / Settings only.

### Gate D6: Human Direction gate

A general non-developer can add a person and a promise, see them on Home,
use capture/find as before, and try Talk once—without Terminal or jargon.
Synthetic evidence cannot satisfy this gate.

---

## Parked / Forbidden for this goal

- Replacing barebones with a partner-only app.
- Making Direction a fourth primary nav item equivalent to Library.
- Merging full MLX-SAGE Python runtime into the app.
- Agent Rails, WattOS, hive multi-agent runtime.
- ScreenSage / ZoomIt as product identity (optional capture later only).
- Reopening Research, Repositories, CAM, Mac Care, Modules, Meaning Preview
  as default navigation to “ship N3.”
- Mock, simulated, or placeholder Partner Talk replies.

---

## Stop Rules

Stop Direction work when:

- any barebones packaged gate regresses;
- primary copy requires embeddings/index/endpoint jargon;
- Talk invents Library content;
- Meaning Preview or other specialist surfaces become required for N3;
- romantic companion behavior appears in product copy or prompts;
- a destructive, clinical, legal, or financial autonomous decision is
  implied;
- human review of the implementation plan has not been given for code
  execution.

---

## Completion

Phase 2 Direction is complete only when Gates D1–D5 have current repository-
owned evidence and Gate D6 has authentic human evidence **or an explicit human
waiver recorded in the repository**.

The **Pattern A product** (N3+N4) is complete only when **both** barebones
Gates 1–7 and Direction Gates D1–D6 are satisfied (waivers explicit).

**Waiver (2026-08-09):** Gate D6 waived by product owner (Gate 7 also waived) —
see `docs/evidence/HUMAN_GATE_WAIVER_2026-08-09.md`. Pattern A controlling
completion accepted under that waiver.
