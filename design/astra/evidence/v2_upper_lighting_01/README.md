# Occupied upper-apartment room lighting

Adds all **42 room circuits across 5A, 5B, 5C, 6A, 6B and 6C** in one category
batch: six pendant shades, six kitchen fixtures and thirty schoolhouse domes,
each with its own physical switch and approach anchor. The source now contains
81 room circuits, and the existing household save owner captures 98 controls.
The restricted 5D/6D programs receive no domestic lights or controls.

## Source and ownership

`work/v2_upper_lighting_01/build.py` is the authoring entry point. It reconstructs
the batch from `e4a0964`, refuses overlapping source changes, and appends 126
anchors plus 42 fixtures and 42 switches. Previous anchors, circuits, furniture,
fittings, room programs, resident data, native fixture bodies/materials, lamp
implementation and selector are preserved.

Existing resident-specific energy values are retained where corresponding
markers exist. Newly divided rooms inherit the same household's bedroom/alcove
gain. Fixture positions and bounded ranges derive from the new room program,
rather than copying obsolete floor-plan coordinates. Native ceiling fixtures
hang from a 3 m mount; no replacement material or screenshot-only light is used.

Switch search uses solid authored wall faces at 1.12 m, excludes apertures and
door sweeps, and chooses reachable approaches. Source paths account for the
current furniture, fittings, chases, fully open wardrobes and ordinary open
doors. They contain 7,054 points with intermediate edge samples. A person may
move while opening a door; this is not a claim that every switch stance is safe
through every intermediate door angle. Engine checks independently probe the
standing capsule and eye-height interaction ray at all 42 destinations.

The existing room-light loader now refuses a missing circuit control or two
controls assigned to the same room. The existing switch system and save owner
remain authoritative; no new persistence subsystem is introduced. A save from
before the 42 lights existed retains its lower-household settings, while omitted
upper circuits inherit construction defaults without eagerly rewriting the save.

## Runtime results

All suites use the serial runner, windowed Forward+, 960x540, dummy audio, and a
180-second ceiling. Final logs have empty stderr and zero failures:

| Suite | Checks | Coverage |
| --- | ---: | --- |
| Upper lighting | 8249 | All 42 fixtures/switches, capsule/ray targeting, isolation across all 81 circuits, save capture, both storey gates and render visibility, malformed circuits, two-world teardown |
| Household state | 57 | Full 98-control disk round trip, old 56-control roster, invalid/protected state, cabinet transforms and physics, reconstruction and teardown |
| Apartment batch | 17140 | Existing household interaction/material/supply coverage with the expanded light roster and lower-switch isolation against upper fixtures |

**25,446 checks pass.** `receipt.json` binds final logs, source hashes and capture
hashes. Replay the source/retained-output verification without starting Godot:

```powershell
python design/astra/work/v2_upper_lighting_01/check.py
```

The first upper-light test used the wrong native group name and expected energy
to become numerically zero before the fixture's existing fade settled. That
8,081-check/126-failure attempt remains in `runtime_01.log`. The corrected
8,081-check run is retained as `runtime_02.log`; the final suite adds explicit
render visibility checks. No fixture fade or floor-gating implementation was
changed to satisfy the test. The household pre-extension run is also retained.

## Rendered review

`rooms_02` contains fifteen unedited 1280x720 frames: five matching viewpoints
with the room switched off, switched on, then room light plus carried lamp.
The production atmosphere, native fixture shadowing, materials and carried voxel
lamp run normally. No ceilings or walls are hidden. The capture scene sets the
isolated campaign to November 10, 1928 at 20:00, and freezes player movement/input.
The scene clock and fixture/lamp presentation continue normally.

The first capture (`rooms_01`) allowed only one second for the carried filament
to cool, so some room-off images contained its residual light. It is retained
as an intermediate capture. The final scene waits three seconds and refuses a
room-only image if the carried spotlight is still visible. Only `rooms_02` is
used for the final comparison. `comparison.png` is a labelled, resized contact
sheet; originals are retained separately.

Inspected all fifteen final frames. Nadia's tables, Iris's bed fabric and wood,
Cal's stove/fridge, Sacha's desk, and Mae's sitting area are readable under their
room fixtures. Switching off produces a visible reduction; the carried lamp
adds a local pool in the combined view. Spill from adjoining lit spaces remains
visible through their actual openings. Strong reflected fixture highlights in
the windows, fine appliance shadow banding and Mae's faint glass tabletop remain
material/lighting review items, not evidence of finished art. Descriptive image
luma values in `image_observations.json` are not lux or a performance benchmark.

## Remaining V2 scope

Next upper-home category batches: kitchen preparation/storage, accessories,
installed heat, and remaining resident equipment/props. Eight other numbered
residential programs plus B1/shared/service work remain. Physical utility routing,
resident migration, played routes, representative performance and human visual
acceptance remain separate gates. Existing program-stage records retain their
source-program provenance; this packet records the later circuit integration.

V2 is incomplete. V1 remains the default and S2J remains open. The pre-existing
`dream_exposure_field.gd` overlay was present and is hashed in the receipt, but
was not edited or included in this change.
