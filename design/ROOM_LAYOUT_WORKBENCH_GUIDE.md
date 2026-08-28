# Room layout workbench — usage and interpretation

`tools/room_layout_workbench.py` is a read-only inspection lane beside the
room-by-room reconstruction.  It converts the authoritative building-layout
JSON into per-room visual plans and analytical packets so object placement and
circulation problems can be understood without opening Blender or Godot.  It
never edits, regenerates or reformats production data, and nothing it prints
is a relocation or deletion order.

## Commands

```
python tools/room_layout_workbench.py --list-rooms
python tools/room_layout_workbench.py --room F01_COMMON_B --output <dir>
python tools/room_layout_workbench.py --floor F02 --output <dir>
python tools/room_layout_workbench.py --room F01_COMMON_B --output <dir> --detritus
python tools/room_layout_workbench.py --room F01_COMMON_B --output <dir> --json-only
python tools/room_layout_workbench.py --room F01_COMMON_B --output <dir> --visual-only
python tools/room_layout_workbench.py --compare game/data/building_layout.json --room F01_COMMON_B
```

`--layout` defaults to `art/data/building_layout.json`.  An explicit
`--output` directory is required for report generation; the tool refuses to
default into tracked directories.  Use a temporary directory or a personal
scratch location.

**Overwrite safety:** the tool never overwrites an existing generated file
unless `--force` is passed.  The check runs before anything is written and is
atomic per invocation: if any target file of a room packet (or any room of a
`--floor` run, or `layout_comparison.md` for `--compare`) already exists, the
run refuses with exit code 3 and writes nothing — a packet is never partially
refreshed over older files.  `--force` overwrites everything the run targets.

Per room it writes `<ROOM>.plan.html` (self-contained SVG plan, opens in any
browser), `<ROOM>.packet.json` (machine-readable) and `<ROOM>.packet.md`
(human-readable).  Output is deterministic: same layout in, same bytes out.

## Fact tiers — the core reading rule

Every element carries one of four tiers, and the plan styles them differently
so an uncertain estimate is never drawn as exact:

| Tier | Meaning | Drawn as |
|---|---|---|
| `exact` | Read directly from the layout JSON: room rects, wall segments and openings, `rect` furniture parts, marker positions, pipe axes, door hinge/width/leaf/subtype. | solid stroke |
| `inferred` | Derived from assembly metadata or engine constants: assembly AABBs from the generator's `ASM_FOOT` half-extents (parsed out of `art/data/gen_layout.py` by AST, never executed), marker appliance feet (`FRIDGE_FOOT` etc.), the DoorProp 100° interactive swing and 168° parked-open leaf, latch-side service stands. | dashed stroke |
| `heuristic` | Workbench analysis: circulation routes, occupancy ratios, minimum passage widths, wall-endpoint near-misses, conservative door-sweep envelopes, detritus zones.  Questions for visual inspection. | dotted stroke |
| `unknown` | Not derivable: assemblies without an `ASM_FOOT` entry (mugs, dishracks, arcade cabinets…), radiator depths, records without positions.  Listed in “Unresolved facts”, drawn only as a red `?` point. | red `?` |

If `gen_layout.py` ever stops exposing the footprint tables, every assembly
footprint degrades to `unknown` rather than being invented here.

## What the plan shows

- Room boundary (dashed blue rect) with metre grid, axis labels in building
  coordinates (+x east, +y north), a 1 m scale bar and a legend.
- Walls at true thickness with window (blue) and doorway (white gap) openings;
  decorative alcoves and sills appear in tooltips.
- Doors: hinge dot, closed leaf, 100° swing arc (green), parked-open leaf when
  `leaf: "open"`, conservative clearance square (ochre, heuristic) and the
  latch-side service stand cross.
- Object footprints per tier, with `<title>` tooltips carrying id, assembly,
  material, tier, blocking status and ownership warnings.  Non-blocking parts
  (rugs, trim under 0.30 m, overhead work at z0 ≥ 1.9, `nocol`) are drawn
  faint.
- Pipes as grey plan-projected axes (movement-exempt, like the generator).
- Services and anchors: switches, sockets, vent registers, vantry points,
  radiators (position exact, dimensions unknown), kitchen sinks.
- Stair wells / elevator shafts / slab holes as hatched voids.
- Circulation: door-to-anchor and door-to-door routes (blue dotted) from a
  0.08 m grid BFS with the 0.33 m player radius, annotated with the minimum
  apparent passage width.
- Findings ring markers at wall-endpoint near-misses.
- Layer checkboxes toggle architecture, tiers, clearances, routes, findings,
  labels and the detritus overlay.

## The room packet

`*.packet.json` / `*.packet.md` contain: room id/floor/kind/unit/resident,
quoted room-profile text when a `## Room profile` section naming the room
exists under `design/` (otherwise “kind only — purpose required”), dimensions,
entrances with swing and clearance data, every contained or overlapping
object with position/yaw/footprint/tier, ownership classification (assigned,
overlapping, ambiguous, crosses-room-boundary), wall/door/intersection
findings, occupied- and furnished-area ratios, per-route minimum passage
widths, art/frame id-stem pairing, unresolved facts, and `verdict: null`
placeholders (KEEP / MOVE / REPAIR / REPLACE / REMOVE per object, ADD via
`verdict_schema.additions`).  Verdicts are for the reconstruction owner to
fill; the workbench never proposes them.

## Detritus advisory mode (`--detritus`)

Represents small-clutter potential as *categories and density envelopes*,
never as placed objects.  Zones are free floor after subtracting door swings
and approaches, computed circulation inflated to the 0.80 m gate, appliance
and fixture stands, radiator/service access bands, furniture use positions
and window sightlines; each zone lists why it is eligible (room kind is the
exact input) and which exclusions protect it.  Categories: swept-clean,
ordinary lived-in, active work surface (attached to real work surfaces, not
floor), neglected edge, service residue, resident-specific personal
accumulation.  The last is only offered when a named resident *and* a written
room profile exist; otherwise the packet says “PURPOSE REQUIRED” instead of
guessing.  No resident biography is invented.

## How the reconstruction chat should use this

1. Before profiling a room, generate its packet and plan; read the exact
   dimensions, entrances and object census instead of re-deriving them.
2. Treat `heuristic` findings exactly like the census: candidates that become
   defects only after checking the generator, the built scene and a camera
   angle.  Chair-tuck overlaps and kitchen-run layering are flagged but
   annotated as commonly intentional.
3. Use the `verdict` placeholders as the working sheet for the object
   dispositions the plan requires, then author corrections in
   `art/data/gen_layout.py` as usual.
4. After regenerating, run `--compare` between the old and new layout files to
   confirm exactly which objects moved, resized or disappeared in that room.
5. Use `--detritus` only after the room profile exists, as a placement-safety
   map for the dressing pass.

## Known limitations of 2D inference vs Blender/Godot truth

- Assembly AABBs are the generator's own worst-case half-extents, not meshes;
  a flagged overlap can be air between chair legs, and a clear plan can still
  clip at mesh level.  `ASM_FOOT` covers movement-relevant assemblies only.
- Rotation handling matches the movement audit: yaw 90 swaps extents; any
  other yaw becomes a safe bounding square (over-estimate).
- Door swings are the DoorProp constants about the hinge marker; the small
  runtime hinge setback and door-check closers are not modelled.
- Height is collapsed: the plan reasons in bands (blocking vs rug vs
  overhead), so a wall shelf above a counter is not a conflict here even if it
  is one in 3D, and vice versa.
- Runtime props placed by GDScript (detail passes, resident dressing) are
  invisible to the layout JSON and therefore to this tool.
- Circulation is a grid estimate with square cells; widths within ±0.08 m of
  a gate deserve a real WalkTest, not a verdict.
- Radiator footprints, unlisted assemblies and positionless records are
  reported as unknown — the room cannot be signed off from this plan alone.
- Room rects are rectangles; rooms whose built extent exceeds their declared
  rect (see the F01 common-room checkpoint) will show their extra leg as
  “outside every declared room”.

## False-positive risks

- Conservative door sweeps use the audit's square envelope and over-report
  corners by design.
- Inferred-AABB intersections inherit `ASM_FOOT` worst cases (arms and
  overhangs); the packet marks the basis of every finding.
- The smallest-containing-room ownership rule mirrors the generator; the
  deliberately overlapping MAIN envelopes are not reported as ambiguity, but
  two genuinely similar overlapping rooms are.
- Near-miss endpoints between 12 and 300 mm may be authored junction details.

## Tests

```
python tools/tests/test_room_layout_workbench.py
```

34 focused tests over a synthetic fixture (`tools/tests/fixtures/
mini_layout.json`): rotation handling, swing direction and reversal, overlap
and near-intersection detection, boundary/ambiguity classification, unknown
footprints, no-position records, detritus exclusion safety, byte-identical
determinism, compare mode, no-overwrite refusal / atomic preflight /
`--force`, and graceful degradation when the generator tables are
unavailable.  The suite touches no production files.
