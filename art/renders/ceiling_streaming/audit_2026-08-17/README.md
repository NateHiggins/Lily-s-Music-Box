# The storey rule culled the Passage out from under itself

*2026-08-17. Harness: `game/tests/CeilingStreamingAudit.tscn`.*

Two owner reports arrived pointing at the same constant, and nobody had
pointed a camera at either. One of them was a real defect. The other was not,
and the hypothesis offered for it is now closed with numbers.

```bash
SHOT_DIR=<abs> godot --path game res://tests/CeilingStreamingAudit.tscn
```

The audit drives the **real** `BuildingRoot` streaming path through
`view_override` and then reads `is_visible_in_tree()` off the **real** nodes.
Nothing in it re-implements `_visibility_signature`. That was deliberate: a
re-implemented rule that agrees with itself is how this project has produced
confident wrong numbers four times already.

---

## 1. "Ceilings sometimes don't render" — hypothesis DEAD, report unexplained

The offered hypothesis was the seven atrium half-landings: a body ~2.0 m up
fails `absf(p.y - z) < 1.75`, hiding the floor that owns the ceiling
overhead. It fails twice over, independently.

**The landings are inside `in_eye`.** All seven sit on the same rect,
`x -3.16..3.16, y 1.46..3.16` (Blender). The `in_eye` exemption is
`|x| < 3.7 and -3.7 < z < 6.9`, and the well only reaches ±3.16. Every
half-landing is inside the box, so the storey rule never runs there — which is
exactly what `in_eye` was written to do.

| landing z | in_eye | floors hidden |
|---:|:--:|---:|
| -1.40, 1.60, 4.80, 8.00, 11.20, 14.40, 17.60 | true | **0** |

**And `p.y` is the feet, not the eye.** `PlayerController` puts the collision
shape at `Vector3(0, STANDING_HEIGHT * 0.5, 0)`, so `global_position` is the
sole of the shoe and the camera rides `STANDING_EYE = 1.41` above it. A body
on the 1.60 m landing supplies `p.y = 1.60`, and `|1.60 - 0| = 1.60 < 1.75`
keeps F01 anyway. The hypothesis needed feet at 2.0 m; the landings are at
1.60 and the origin is at the floor.

**The general question, since the specific one failed.** All 246 authored
ceiling faces were checked from beneath, at the feet height a body really has
and at the eye height a shot camera really gets parked at:

| probe | ceiling faces whose owner floor was hidden |
|---|---:|
| feet on the owning slab | **0 of 246** |
| free camera at eye height (1.41 m up) | **0 of 246** |

**Floor streaming is exonerated for ceilings.** Culling a ceiling with its
owning floor is *intended* — `gen_layout.py` keeps a plain-plaster buffer
specifically to prove it — so "a ceiling vanished" is only a bug when the floor
beneath the viewer went with it, and that never happened in 492 probes.

### The real ceiling defect, found by asking a different question — FIXED

The report was right; the rule was the wrong suspect. A ceiling is the
**underside of the slab above it**, so the openings it must be cut by are the
ones in *that* slab. `ceiling_pass()` subtracted `fl["slabs"][0]["holes"]` —
the storey's own floor.

From F01 up the two sets are identical (atrium well, lift shaft and flue punch
every storey), so the mistake was invisible. **B1 is where they part.** Its own
slab is the ground and carries no holes; F01's slab overhead carries all three.

| ceiling face | sealed | finish |
|---|---:|---|
| `B1_CEILING_B1_ATRIUM_00` | **39.94 m²** | `tin_ceiling` |
| `B1_CEILING_B1_BOILER_01` | 0.49 m² | `plaster_stained` |

The atrium light court was **lidded at the bottom**, and the switchback stair
climbed out of the basement into a sheet of pressed tin.

**Why it survived.** `_validate_ceilings()` exists precisely to catch open
ceilings, and it passed — because it made the *same* substitution, in the same
words. Its comment says "slab holes are lawful absences" and it read them off
the wrong slab, three lines after correctly taking `expected_z` from the floor
above. The generator and its validator held one wrong idea between them and
confirmed each other. A sealed opening is exactly what "no open ceiling" looks
like when you subtract the wrong holes.

Both were fixed. B1 goes 10 → 15 ceiling faces (subtracting a hole splits a
rect into a frame of strips); **every other storey is byte-identical**, as is
all non-ceiling layout data. Of the built assets only `floor_b1` changed.
Atrium eye re-measured at 38.69 ms against 39.57 before — the station where B1
is actually submitted, since `in_eye` is true there.

| file | |
|---|---|
| `b1_atrium_before_sealed_by_tin.png` | the lid, with the stair running into it |
| `b1_atrium_after_open_well.png` | the same camera; the shaft, balustrades and landings all the way up |

---

## 2. The arcade lunette — SOLVED, and it was never the vault

`VantryDepthShot` station `06_south_gable_lunette_UNRESOLVED` returned night
sky from three aisle placements. That was read as the nave vault failing to
roof the south end of the hall.

It was the camera. Sweeping the station's own eye through the threshold:

| Blender z | in_passage | F01 visible | passage shell draws |
|---:|:--:|:--:|---:|
| 1.30 … 1.70 | true | true | 25 |
| **1.75** … 2.40 | true | **false** | **5** |

F01 disappears at exactly 1.75, the rule window. **Station 06 stood at 2.00.
The five stations that work stand at 1.50–1.62.** Exactly one of six crossed
the line, and it was the one that failed.

The whole Passage — shell, vault, ribs, shopfronts — is parented into the F01
floor node (`_index_passage_geometry` walks `floor_nodes["F01"]`), and Godot
visibility is hierarchical. Hiding F01 hides the arcade whatever each arcade
node's own `visible` flag says.

### The defect was one missing clause, two lines from its twin

`_apply_visibility` computed the two rules differently:

```gdscript
var should_show := show_all_floors or in_eye or outside \
        or absf(p.y - z) < 1.75 or (fid == "ROOF" and p.y > 15.0)
        #  ^ no in_passage term
var show_props := show_all_floors or in_eye \
        or ((outside or in_passage) and fid == "F01") \
        #      ^ has one
        or absf(p.y - z) < 1.75 or (fid == "ROOF" and p.y > 15.0)
```

Props are root-owned and were exempted in the Passage. The architecture was
not. **That asymmetry is the whole symptom**: above 1.75 m the props stayed
and the building left, which is why the frame was an aisle pendant hanging
alone in the night sky rather than an obviously empty one.

Meanwhile `_point_is_in_passage` admits an eye from -0.50 to 5.80 m, because
the glass crown reaches 5.55. So the zone predicate deliberately covers a
height band that the storey rule was culling. The two disagreed by 4.05 m.

**Fix:** give the floor rule the same `in_passage and fid == "F01"` term the
prop rule always had, in both `_apply_visibility` and `_visibility_signature`
(they duplicate the rule, and a signature modelling a different rule than the
one applied would let the cache skip a frame that needed applying).

It costs nothing at standing height — a body's origin is its feet, so a player
in the hall already satisfied the 1.75 window and the new term never fires for
them. The three Passage perf stations stand at 1.68, also below it.

After the fix, F01 survives the full 1.30–2.40 sweep with all 25 shell draws
held. The audit now asserts that as a regression guard.

---

## Frames

| file | what it shows |
|---|---|
| `arcade_station06_z2.00_reported.png` | the reported failure, reproduced exactly: night sky, one pendant |
| `arcade_station06_z1.60_under_threshold.png` | same camera, same aim, 40 cm lower — the vault is right there |
| `arcade_south_gable_z1.60.png` | the gable framed: stepped parapet, vault arch, brick end wall, and the lunette as a dark recessed panel |
| `half_landing_z1.60_looking_up.png` | a half-landing, for the hypothesis that did not survive |

`../../vantry_arcade_v4_depth/06_south_gable_lunette.png` is the repaired
station in its own series.

**The lunette is visible from the aisle and it is dark.** So V4's open
question — whether `PassageLunetteKey` is lighting something no player can
see — is now answerable, and the answer is that they *can* see it. Whether it
should read brighter from the aisle is a lighting decision, not a geometry
one, and it belongs to the owner.

---

## What this cost, recorded because it generalises

Both reports were "nothing pointed a camera at it", which is already this
project's second recurring lesson. Two more came out of it.

**A rule and its validator can be wrong together.** The ceiling coverage check
was not weak or missing — it was thorough, and it enforced the same mistake the
generator made, so it certified a sealed shaft as correctly covered. This is
the third recurring lesson ("re-implemented logic lies") wearing a new face:
the danger is not only re-implementing logic *under test*, it is a check that
shares the author's misconception. `CeilingStreamingAudit` deliberately does
not ask the generator anything — it compares the emitted ceiling rects against
the emitted slab holes and would have failed on day one.

The narrower one, worth naming:

**A streaming rule calibrated for feet was being fed eye heights by every
shot harness.** `p.y` is a body origin — the floor. Shot cameras are placed
where a head goes. The margin between them is 1.41 m against a 1.75 m window,
so a harness camera has only 34 cm of headroom before it silently deletes its
own floor, and it fails *quietly*: you get a plausible frame with a wrong
conclusion attached, and in this case a written-down claim that the vault did
not roof the south end of the hall.
