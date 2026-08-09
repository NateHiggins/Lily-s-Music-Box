# The Lived-In Pass

The user-authored brief for making every occupied apartment read as a
functioning home is the operating document for this pass; this file records
where it lives and what was added to it. The brief text arrived 2026-08-01
(session transcript) and its schema, audit table, kits, budgets, execution
order and acceptance criteria are adopted as written.

## Status

- **Step 1 DONE:** `apartment_life_profiles.json` authored for all 18 units
  (art/data source of truth, copied to game/data). Every entry carries the
  brief's schema plus the additions below.
- Steps 2-7 are queued as tasks (sockets+audits; 2C/5C/6C conversions + 4B
  formalization; kits/dressing/decals/hero interactions).

## Additions to the brief (Claude)

1. **hero_object is triple-duty.** Each unit's hero object is (a) the
   examine-interaction the brief allows, (b) the poltergeist's
   director-reactive prop for that resident — one possession target per
   home, already matching their rung ladder — and (c) where a case exists,
   a dialogue anchor: Mina's `conspicuously_unlabeled_box` is scripted to
   feed the Case 01 tree (the one thing she never annotated).
2. **sleep_schedule is bound to the light story.** window_glow is already
   the single authority on who is awake (door spill asks it); profiles'
   sleep_schedule must drive/agree with that seed so curtains, lit windows
   and under-door light never contradict the dressing. One story per wall.
3. **contradiction is a required field**, per the brief's own audit rule
   ("one contradiction per resident") — authored now, not sprinkled later.
4. **daily_loops map to ResidentRoutines stages.** WATCHING exists; the
   work loops (record/paint/catalog/write) become future routine stages at
   the WORK_PRIMARY socket, so dressing and behaviour share coordinates.
5. **Vantry points:** one 1912 house-circuit listening head now covers every
   enclosed room. Quiet faces batch per floor; only the current chirp is
   promoted to a functional owner, so coverage does not become draw-call debt.
6. **no_tv / no_sofa flags** (Rhea, Sacha, Cal's wear pattern) are in the
   profiles so the generic-completeness trap is machine-checkable, not
   tribal knowledge.
