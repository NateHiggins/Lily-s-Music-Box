# PHASE 1 — WHAT THE HERO TENTACLE STILL OWES

> Ecology architecture §35, Phase 1: *"Keep current Hero Tentacle branch
> active. Document its remaining quality tasks."*

This is that document. It is deliberately unflattering: the hero is the bar
every other Dream organism will be measured against (`DREAM_MENAGERIE_REBUILD.md`
§29), so a generous account of it would raise nothing and excuse everything.

## What is actually done

| | evidence |
| --- | --- |
| Layered anatomy, 108 systems on one cage | `build_dream_tentacle.py`; 109 meshes in game |
| Bound and deforming as one creature | bind gate **0/108 drift**, `check_dream_tentacle_bind.py` |
| Survives seven extreme poses | clearance **PASS**, `check_dream_tentacle_clearance.py` |
| Membrane as a thick socket with anchors and nodules | §13; `blender_grey/11_membrane.png` |
| Straight-strip UVs and six anatomical masks reaching Godot | `tentacle_asset_probe.gd` |
| Instantiated, dressed and animated in a real room | `DreamHeroTentacle`; tip travels 0.203 m in 2 s |
| Cage normals outward | asserted every clearance run |

## What it owes — ordered by how much it costs the bar

### H1. ~~No baked maps at all~~ — PARTLY DONE
`T_dream_hero_anatomy.png` now carries AO, curvature and thickness, baked
from the geometry and wired into the skin. Still owed: albedo, normal and
detail normal, and the riders have no UVs so none of them are baked. See
`art/renders/dream_tentacle/bake/README.md`.

Three things came out of chasing "the texture is not great" that were not
about baking at all, and all three were consequences of the same fact: **the
cage is the only mesh with UVs.** Every one of the ninety-four riders exports
with POSITION, NORMAL, JOINTS and WEIGHTS and nothing else.

- **One seed for ninety-four riders.** Every gold plate carried identical
  noise, every crystal the same fracture: one surface copied over a body.
  Each rider now takes its phase from its own name. Keep the offset SMALL —
  the shared stack's noise loses precision at large coordinates, and scaling
  it to ~40 turned the creature into white and blue blocks.
- **One heartbeat for the flesh and another for the metal.** The shared stack
  reads the vascular clock off uv.y, so every rider read it as zero and the
  whole mineral system pulsed in unison while the flesh had a wave travelling
  along it. The creature now measures its own long axis and tells each rider
  where it sits.
- **glTF flips V.** Blender writes v = 0 at the root; the file carries 1
  there. Emergence, skin tension and the pulse direction were all reading
  backwards off it — the limb filled in from the tip, and the riders ignored
  `grow` entirely, so the metal hung in the air along a limb that had not
  arrived. Fixed and photographed; see the ladder below.

**And the surface was fixed to the ROOM, not to the creature.** The shared
stack samples every one of its mesostructure fields — the vascular clouds, the
pores, the gold's ridged field, the crystal fracture — at the fragment's world
position. So the pattern belonged to the flat and the creature moved through
it: a gold plate's grain slid across the plate as the limb swept, which is a
thing no surface does. This is a large part of what "the texture is not great"
was pointing at, and it is invisible in a still frame, which is exactly why it
survived every photograph taken of the creature.

A rider is rigid and bound to one bone, so its rest position can be recovered
exactly — undo the bone's current pose, reapply its rest one, one matrix does
both. Measured: pieces travelled 850 mm through the room while their sampling
position moved 0.0004 mm. **The flesh is NOT fixed this way and still swims:**
it is weighted across twenty-eight bones and genuinely deforms, so there is no
single transform that undoes its pose.

Rebuilding a canonical cylinder from the cage's own UVs was tried and
REVERTED. It does remove the swimming — nothing about such a coordinate refers
to where the body is — but the noise gradient comes out directional in it, and
a directional gradient drives a directional normal perturbation, so the wet
highlight broke into stripes running the length of the animal. Trading organic
blotching for streaks is a worse picture than the defect it fixes. It wants a
second UV set carrying rest position, or a bake, and it is now the largest
thing left on this creature's surface.

**The instrument for all of this: `SHOT_MODE=emerge` on the staged room.**
A limb filling in from the tip and a limb extruding from the root are the same
picture in any single frame, and `grow` runs its whole range in 2.4 seconds.
The ladder stops the state machine and drives `grow` by hand, nine rungs, from
`side_stand` — perpendicular to the creature, because the stand composed to
hold the hero *and* a palp cluster looks straight up the limb's axis and the
whole ladder reads as one frame repeated. The apartment cannot take this
picture at all: every flat puts a partition across the limb about a third of
the way along.

```bash
SHOT_DIR=/tmp/ladder SHOT_MODE=emerge SHOT_WARM=8 godot --path game res://tests/DreamStageShot.tscn
```

### H2. Behaviour states — DONE
All fifteen of §2's states exist and run, plus the three the cross-sectional
withdrawal needed. The eight added last:

- **`MEMBRANE_BULGE` → `EMERGING` → `ORIENTING`** — it *arrives* now. Until
  these existed the creature was simply present in frame one, which is the
  one thing a thing coming through from somewhere else should never be. The
  membrane swells, the limb extrudes (the un-emerged part collapses onto the
  membrane, so it comes out rather than switching on), and it takes stock.
- **`TASTING`** — short repeated contact in one place, distinct from tracing.
- **`WATCH_PLAYER`** — it stops and looks. The most unsettling thing it can do
  when you come near is nothing at all.
- **`INTERACT_MARGIN`** — it notices when enough appendages have collected on
  it (§11).
- **`INTERACT_CRITTER`** — it minds an animal anywhere on it, which is §22's
  own example of a critter clinging to a gold plate.
- **`FLINCH`** — fast, then still, and it does not resume where it left off.
  Driven by `startle()`, which the player's own actions call.

Reactive states interrupt whatever errand it was on, because a creature that
finishes tracing a skirting board while somebody walks up to it is a machine
running a program. Contact outranks approach: with the player checked first, a
critter on the hero's own club was starved out entirely.

### H3. Contact — DONE (first pass)
The creature picks a real point on real architecture, reaches for it with a
CCD solve, touches it, traces along the surface, and withdraws. Measured: 2
touches in one run at 25 mm closest approach, all seven states visited. It
emits `touched(where, normal)` and `released()`, which is the hook
`DREAM_SALIVA_DIRECTION.md` needs.

`TASTING` now exists as a state distinct from `CARESSING` — short repeated
contact in one place rather than a sustained trace. And the suckers COMPRESS
on contact (see H4): a pressed one flattens along its own axis by 0.42 while
one two and a half centimetres away reaches 0.27, so the club reads as a row
of organs meeting a surface rather than as one soft pad.

§10's contact list is COMPLETE: compress, spread, deform, grip and release.
A sucker is split into rim and cup by how far a vertex lies from its own
axis — the outside flares against the surface while the inside withdraws
from it, and the hollow that leaves is the whole difference between a grip
and a press.

All three are a matter of TIMING, which is why none of them can be judged
from a frame: at their settled values they are identical. The cup arrives
*behind* the rim because a grip is something that takes hold, and letting go
is faster than either, because nothing in an animal releases at the speed it
gripped. Measured a sixth of a second into a press: rim 0.81, cup 0.40. Held,
the cup reaches 1.00; released, 99% of it is gone in 0.3 s.

### H4. Secondary motion — DONE
The solve and the search now produce INTENT; a separate pass carries the
flesh's answer to it, running behind with a time constant that lengthens
distally and overshooting slightly before it settles. Measured: the root lags
its intent by 0.0012 rad — effectively rigid, which is right, the collar holds
it — and the tip by 0.1333 rad, a hundredfold gradient along the body. The wet
highlight is the cascade's last layer and now settles after the body does,
driven by a `body_motion` signal that rises instantly and decays slowly.

**The riders answer the flesh a beat late.** Every rider is bound to the
cage's own weights, so it went exactly where the flesh went and did nothing of
its own — skinning is precisely the part that moves a rider AS IF it were the
flesh. Each is now sprung against the LOCAL velocity of the bone it sits on,
which is the whole point: the club can whip while the collar is still, and one
number for the body cannot say that. Measured peaks: cilium 14.3 mm, sucker
6.0, gold and crystal 3.0 at their caps, membrane 1.8.

The membrane is NOT dragged by the collar — the root is the one anchored part
of the creature and never translates, so seated on its own bone it measured
0.02 mm of follow-through. What pulls a membrane about is the limb passing
through it, so it answers to the limb a quarter of the way down.

**And rigid pieces rock and press.** A translation slides a gold plate along
the flesh; it does not TIP it, and tipping is most of what seating a hard
thing in a soft one looks like — the flesh bends, the plate cannot, so it
rocks and lifts at one edge. A sucker meeting a surface flattens rather than
trailing. Both need a pivot, which each piece now carries in its seat bone's
own frame. Measured: gold rocks to 4.1°, crystal 3.3°, sucker 1.5°; a pressed
sucker flattens 0.42 while one 2.6 cm away reaches 0.27.

Two things worth keeping:

- **The pivot is the part that can be silently wrong.** If it drifts off its
  bone the piece is not rotating, it is being sheared, and on a lumpy organic
  sculpture that reads as "the shader is a bit odd" rather than as a bug. The
  sweep asserts the bone-to-pivot distance never changes: currently 0.0001 mm.
- **The press had to be constructed.** Waiting measured nothing — across four
  and a half seconds in a real flat the creature touched nothing at all, and a
  flat zero from an unfired mechanism looks exactly like a flat zero from a
  broken one.

**And every one of the organism's clocks was stopped.** The shared stack
carries `attention`, `pulse_phase`, `breath_phase`, `startle` and
`dream_phase`; the procedural limb has pushed all five every frame since it
existed, and the modelled hero pushed none of them. It rendered at a fixed
attention of 0.3, with a vascular wave standing still on its body and a breath
that never came — the whole coupled-state layer inert on the creature it was
written for. "Not animated at all" was true of the material as well as the rig.

It now runs on the same periods as the procedural limb, because it is the same
animal: pulse 1.47 s, breath 5.3 s, deliberately not sharing a period so
nothing in the body beats with anything else. And the bolus MOVES the flesh —
a pressure wave that tints the skin and leaves the silhouette alone is a
texture effect; one that swells the body as it passes is circulation.

A frozen clock is invisible in a still frame and very nearly invisible in
motion, because the body is moving anyway, so the sweep reads the phases back
off the material: pulse ranged 0.972 and breath 0.478 over 2.4 s.

### H5. ~~The eye does not perform~~ — DONE
The rig had carried `CTL_EYE` and three lid controls since it was built and
**nothing was weighted to them**: every rider inherited the flesh's bones, so
rotating the eye control moved nothing. The globe, iris, pupil, cornea and
three lids now bind to their own controls, and the eye is driven saccadically
— it fixes on a thing, holds while the body moves under it, and jumps. The
lids run on separate clocks, the nictitating membrane faster than the other
two, because three lids moving together are one lid. Measured across two runs
at 0.73-0.93 rad of gaze and 0.75-0.83 rad of lid.

### H6. Hyperdimensional event — DONE
**Cross-sectional withdrawal.** It does not retract, shrink toward its root or
fade: its cross-section closes everywhere along its length at the same instant
while its length does not change. `r_visible = sqrt(r² − w²)` — the field's own
law applied to the hero's body. Fires on every third ordinary withdrawal, so
most departures are unremarkable and this one is not. Measured and
photographed in `art/renders/dream_tentacle/cross_section/`.

### H7. No corrective shape keys
Extreme poses pass the clearance gate on penetration and collision, but
nothing corrects volume loss at hard bends. TB-13's original scope.

### H8. Placement is a first-wall raycast
The creature takes the first vertical surface it finds, which in testing put
it in a bathroom. It should emerge where the *case* is, from a surface chosen
for the shot and the fiction.

### H9. Known smaller faults, recorded honestly
- Some gold `spur` pieces still read as sharp thin points (they are exempt
  from the end-seating envelope by design, but a few are sharper than
  "biomineralized anatomy" wants).
- The membrane aperture's worst point stands 12.6 mm off the flesh, where a
  fold pushes the ring outward. Median is 0.0 mm.
- No LODs. §29 gives the hero one fully detailed asset, so this is lowest
  priority, but the 2.2 MB glTF is drawn at 109 separate meshes and the frame
  is draw-call bound (`DT4_PERFORMANCE_REAUDIT.md`).

## Recommended order

H1, H2, H3, H5, H6 done; H4 partly. The hero no longer outright fails any
§26 test. What remains is depth rather than absence: **H4's** unfinished
layers (gold reseating, cilia springs, sucker compression), **H2's** eight
unbuilt states — most of which need the margin and critters to interact with
— and **H1's** albedo/normal bakes: contact first, because §2's
interesting states (`TOUCHING`, `CARESSING`, `TASTING`) are meaningless
without it and it is the hard prerequisite for
`DREAM_SALIVA_DIRECTION.md`; then the state machine those states belong to;
then secondary motion. H6–H9 after.

## The rule this document exists to enforce

The hero is not finished, and the menagerie brief makes it the standard. Any
claim that a procedural palp or critter "meets the bar" is meaningless until
the bar itself does. Where the hero fails one of the §26 acceptance tests,
say so rather than measuring others against a gap.

Against §26, updated as work lands:

- **Motion** — still fails. The body has one motion language and no secondary
  motion, and there is no contact. The eye now performs, which is part of it.
- **Materials** — partly. Geometry facts are baked (AO, curvature,
  thickness) and visibly separate the flesh from itself; albedo, normal and
  detail normal are still procedural, and no rider is baked at all.
- **Hyperdimensionality** — now passes. Cross-sectional withdrawal, used on
  one departure in three.
- **Sensory logic** — now passes behaviourally as well as structurally: the
  eye fixes, holds and jumps, and the lids run on their own clocks.

Passing: silhouette, anatomy, integration, sensory logic, restraint, family
resemblance.
