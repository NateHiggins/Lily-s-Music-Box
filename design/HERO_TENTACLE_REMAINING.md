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

### H2. No behavior state machine — **blocking §2 and §11**
§2 names fifteen states (`MEMBRANE_BULGE` … `WITHDRAW`). The hero currently
has one continuous searching motion. Without states it cannot emerge, flinch,
withdraw, watch the player, or participate in the margin's social system —
which is most of what makes it "individually intelligent" rather than a
moving prop.

### H3. No contact at all — **blocking §27, §28, and the saliva direction**
Nothing detects a surface, nothing compresses against one, nothing tastes or
caresses. The distal club and the suckers are geometry with no behavior. This
also blocks `DREAM_SALIVA_DIRECTION.md` entirely, since residue needs contact
events to exist.

### H4. No secondary motion — **§12 of the menagerie brief**
One layer moves: bones. There is no muscle lag, flesh settle, gold reseating,
cilia spring, sucker compression, membrane follow-through or vascular pulse.
The brief's cascade — *bone moves first, muscle follows, flesh settles, gold
reseats, cilia oscillate, wet highlight stabilises* — is what produces
apparent mass, and none of it exists.

### H5. ~~The eye does not perform~~ — DONE
The rig had carried `CTL_EYE` and three lid controls since it was built and
**nothing was weighted to them**: every rider inherited the flesh's bones, so
rotating the eye control moved nothing. The globe, iris, pupil, cornea and
three lids now bind to their own controls, and the eye is driven saccadically
— it fixes on a thing, holds while the body moves under it, and jumps. The
lids run on separate clocks, the nictitating membrane faster than the other
two, because three lids moving together are one lid. Measured across two runs
at 0.73-0.93 rad of gaze and 0.75-0.83 rad of lid.

### H6. No hyperdimensional event
§1 lists "special hyperdimensional events" as hero-owned. It has none. The
field's cross-sectional withdrawal exists in `DreamFieldState` and the hero
does not use it.

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

H1 and H5 are done. **H3 → H2 → H4** next: contact first, because §2's
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
- **Hyperdimensionality** — still fails. No signature impossible event.
- **Sensory logic** — now passes behaviourally as well as structurally: the
  eye fixes, holds and jumps, and the lids run on their own clocks.

Passing: silhouette, anatomy, integration, sensory logic, restraint, family
resemblance.
