# Handoff — Orison Apartments build (local continuation)

This document briefs a fresh Claude (or human) instance picking up the
Orison Apartments set build on a local machine. It covers the pipeline,
how to verify the build, exactly where work stopped, and the one open
defect with its full diagnosis so far.

## What this project is

*The Audio Virus* — a first-person Godot prototype set in the Orison
Apartments, a 1927 Midwestern brick apartment block, now aged to 2027.
The player is a support-line operator; sound propagates through the
building's physical infrastructure (heating risers, electrical, water,
structural, chimney flue) as an "audio virus". Design docs live in
`design/` and `art/docs/`; per-case content in the Case Network docs.

Three top-level projects:

| Path | What |
|---|---|
| `game/` | Godot 4.7.1 project (originally authored against 4.5) |
| `art/` | Procedural pipeline: layout generator + Blender build scripts |
| `legacy_mobile_mvp/` | The old mobile MVP, kept for reference only |

## The pipeline (single source of truth)

Everything is coordinate-driven from **one** generator. Never hand-edit
geometry or the JSONs — change `gen_layout.py` and re-run the chain.

```
art/data/gen_layout.py
  └─> building_layout.json   (walls, rooms, furniture, markers)
      acoustic_graph.json    (heating/electrical/water/structural/flue)
      prop_catalog.json      (functional prop behavior profiles)
      material_catalog.json
        └─> art/blender/scripts/build_orison.py  (bpy → per-floor GLBs)
              └─> game/assets/building/*.glb
        └─> game/data/*.json  (same files, copied verbatim — Godot reads
                               them directly to spawn props/doors/player)
```

Rebuild steps:

```sh
# 1. regenerate layout (validates itself: overlap, footprint, door-width,
#    height-aware door-swing audit — a nonzero exit means a real defect)
cd art/data && python gen_layout.py

# 2. copy the four JSONs into the game
cp building_layout.json acoustic_graph.json prop_catalog.json \
   material_catalog.json ../../game/data/

# 3. rebuild GLBs — only needed if walls/furniture/openings changed
#    (marker-only changes skip this). Uses the `bpy` pip wheel (4.5),
#    or real Blender: blender --background --python art/blender/scripts/build_orison.py
python art/blender/scripts/build_orison.py

# 4. re-import + run the walk test (Godot 4.5 or 4.7.1)
godot --headless --path game --import
godot --headless --path game res://tests/WalkTest.tscn
```

Conventions that bite if forgotten:
- Meters, Blender axes (X east, Y north, Z up, street = −Y).
  Godot mapping: `GameBoot.b2g(p) = Vector3(p[0], p[2], -p[1])`.
- Mesh names ending `-col` import as visual+trimesh collision,
  `-colonly` as invisible collision.
- Aging/weathering is seeded (`random.Random(1927)` in `aging_pass`) —
  deterministic across rebuilds by design.
- Door markers carry `leaf` ("closed"/"open"/"locked"/"none"),
  optional `cabinet: true` (exempt from the swing audit), and optional
  `swing: "out"` (reversed hinge — currently only the street door).

## Verification

- `game/tests/WalkTest.tscn` — 157-check suite: physics-verified walks
  (stairs, apartment 4B entry, street exit, roof egress, the reading nook
  at the light tree's base), elevator doors and per-floor cab buttons,
  acoustic propagation timing (riser sweep, flue-vs-riser race), prop
  behavior, touch controls, occluders, and all three Case Network cases
  driven end to end including their consequences. Exit code 0 = all pass.
  **Run this before every commit.**
- `game/tests/LightingAudit.tscn` — every space is reachable by light:
  127 spaces, 11 intentionally ambient/dark. Exit code 0 = pass.
- `game/tests/Perf.tscn` — six worst-case camera stations, reporting
  objects/draw calls/primitives and frame time. Must run **windowed**;
  headless reports zeroes, which the probe fails on rather than passing.
- `game/tests/Screenshot.tscn` — renders documentation stills into
  `SHOT_DIR`; needs a real window, so run it **without** `--headless`.
  `SCREENSHOT_ONLY` takes a comma-separated list of shot names to
  re-shoot a sequence in one scene load. Copies in
  `game/docs/screenshots/` are current as of the ground-plane fix.

Throwaway probes are a normal tool here: write one, get the number, then
delete it in the same pass rather than letting it rot in `tests/`. Two
have already paid for themselves — the street probe that found the B1
bearing wall, and a raycast fan that found the road slab over the well.

## State

**`art/docs/photoreal_target.md` is the live status document** — it holds
the eight-phase roadmap with an honest per-phase assessment and the
invariants that hold across all of it. Read it before starting new work.
This file covers only how to build and verify; do not duplicate phase
status here, because two copies of a status always disagree.

Broadly: phases 1, 2, 6 (dressing) and 7 (performance) are done; 3, 4, 5
and 8 are partly done with named remainders. The building is fully
walkable end to end — street, all seven storeys, basement, roof — and
runs 112-161 fps at 1440p on an RTX 4080.

## Known open items

Nothing here blocks a build; these are the honest edges.

- **Lighting (phase 5 remainder).** Lightmap bake / GI fallback is not
  started, and the light-leak pass (under-door and transom spill) is open.
- **HLOD and prop LODs (phase 7 remainder).** Untouched. The headroom
  above is measured on one high-end GPU only — mid-range is unproven.
  The coarse floor-visibility stand-in in `building_root.gd` is still a
  stand-in, though occlusion culling has taken most of its load.
- **Mobile.** The APK builds and runs, but the light/shadow budgets in
  `light_rig.gd` were tuned by argument and then loosened once from real
  device feedback. They want confirming on hardware via the debug panel
  sliders, not another guess.
- **Volumetrics.** Unavailable on the Compatibility renderer, so stairwell
  and basement fog needs a different technique. Glass has no dirt masks
  or per-window variation yet.
- **Aging (phase 4 remainder).** The `aging_pass` thin-box patches (facade
  brick, damp bases) should become mask-driven decals for softer edges.
- **Case content (phase 8).** Three of the seven drafted cases are wired
  (01 The Early Answer, 02 Someone Upstairs, 03 Voiceprint Correction —
  the opening trio the design doc names as the strongest). Cases are data
  in `scripts/call/case_library.gd`; `call_interface.gd` is the runner, so
  a fourth case is a dictionary rather than a class. Cases 04-07 and the
  convergence are unbuilt, and the draft in
  `audio_virus_prototype/docs/design/case_network_batch_01.md` is still
  marked NOT CANON — names and outcomes there are not settled.
  Case 02 has a **field phase**: its response window is long enough to
  leave the desk, and standing where the route ends resolves the case on
  foot. That is scored as a different outcome from letting the window run
  out in the chair, which is the whole point — the building learns whether
  you can be waited out. Any case can declare one; see the `field` key.
  What is still missing is the *journey*: the design has contact
  microphones and positional listening on the way down, and right now the
  walk is unguided beyond a banner and the motif playing from the F03
  riser.
- **Rigged residents are deliberately paused.** 19 rigged GLBs exist and
  import, but `USE_RIGGED_RESIDENTS := false` in `building_root.gd` keeps
  sprite placeholders as the active cast. Flip the one flag to resume.
  `assets/characters/mina/` is a stale duplicate of `mina_vale/`.
- **The B1 "KNOW YOUR EXIT" hallway decal renders mirrored.**

## Working alongside other sessions

More than one agent session works this repo, sometimes in the same
working tree. Before pushing: `git fetch`, and if both sides changed the
same ground, keep the newest user-directed design, port the other side's
features additively, regenerate artifacts, and prove it with WalkTest.
Check `git status` before a sweeping `git add -A` — untracked files that
appeared in the last few minutes are somebody else's work in progress.

## Defects resolved along the way

Kept because each one cost real time and the diagnosis generalizes.

- **The street-exit blocker** was the B1 bearing wall: 1927 walls run
  continuously past the joist zone, so the basement street wall topped
  out 0.4 m above the F01 slab — a solid curb across the doorway. It now
  stops flush under the F01 slab (`exterior()`), water table dressing the
  base.
- **The basement was sealed by the road.** `site_pass` laid the ground as
  one 220 x 148 m asphalt slab across the whole block, running through
  the building footprint 20 mm under the lobby floor and capping the
  atrium well — every sightline down the eye died on tarmac instead of
  reaching B1. The road is now laid as four bands around the footprint.
  The lesson: site geometry authored in world space does not know the
  building is there, so anything spanning the block needs the footprint
  subtracted explicitly.
