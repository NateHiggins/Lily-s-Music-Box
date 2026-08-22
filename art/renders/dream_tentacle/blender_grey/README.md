# The grey test

`design/DREAM_TENTACLE_BLENDER_BUILD.md`, the rule that gates the whole
programme:

> The finished Blender model should look impressive with flat grey
> materials… Shaders should reveal the anatomy. They should not be
> responsible for inventing it.

The model is judged in flat grey clay under a raking key, a fill and a rim
— sculptor's light, nothing flattering — from ten angles, including the
ruling's own explicit test (§4): **from 45° the complete sphere of the eye
must not be reconstructible.**

    "/c/Program Files/Blender Foundation/Blender 5.2/blender" -b \
        -P art/blender/scripts/build_dream_tentacle.py
    "/c/Program Files/Blender Foundation/Blender 5.2/blender" -b \
        art/blender/dream_tentacle.blend \
        -P art/blender/scripts/render_dream_tentacle_grey.py

## TB-1 … TB-11 (2026-08-22)

**The body** (§1–§4) is built from authored cross-sections, not a taper:
broad asymmetric root and shoulder, a hard compressed neck at 0.16, the
ocular station swelling to 104 mm at 0.42, a flattened ribbon at 0.57, a
ribbed shaft that swells and pinches, an articulated knuckle, a dexterous
narrowing and a tactile club — 150 sections × 28 around. The §3 sculpt
forms are in the GEOMETRY, because that is what this test looks at: three
longitudinal muscular cords out of phase so no cross-section is round; six
authored asymmetric bulges, never mirrored, never evenly spaced;
compression folds only where the anatomy actually narrows; tension creases
along the flanks; a softer, flatter ventral field for the suckers. The
orbit is cut into the cage as a real bowl with a heavy dorsal brow, a lower
cushion and lateral walls raised around it.

**Every other system is a separate object** (§24), in its own collection:
the eye in four parts (irregular globe, a physically recessed iris with
radial fibres, a pupil that is a real funnel catching no light, a separate
corneal cap); three lids on three vectors with resting closures so none is
invisible; 18 cilia in three classes from modelled follicles, swept rather
than radial; 26 hero suckers in five variants with base mound, raised rim
and a genuine cup, staggered over the ventral field and growing toward the
club; 28 individually generated gold pieces in seven classes — plate,
crescent, knuckle, branch, rib, spur, brow, support — none repeating;
dendrites as connective detail at the roots; 7 flat-shaded faceted crystals
each with an inner core mesh; and a root membrane that can bulge and cling.

**The gold's sockets are in the flesh** (§9): every root presses a hollow
into the cage and raises a lip at its rim, so the metal comes out from
inside rather than resting on the skin — and the same function fills the
`gold_root` mask.

Exported to `game/assets/dream/tentacle/dream_tentacle.glb` (2.3 MB) with
every system a separate object, so Godot can drive them independently.

## What this test found, and what it still says

Four faults it caught and that are now fixed: the dendrites were 9 cm
thorns over the whole body (they are millimetre roots lying along the flesh
now); a crystal was sitting across the eye socket (the orbital pair moved
to the rim); the globe was buried completely because `frame_at` already
returns the socket FLOOR and it was being sunk a second time; and the
socket was a 110 mm crater around a 36 mm eye, so it now hugs the globe
with the brow and cushion beyond.

**It still does not pass.** The gold reads as thin fins rather than
skeletal plates with mass; the three lids are present but not
distinguishable in a still; and the distal half of the limb is still too
uniform to hold interest. Those are the next corrections, and none of them
is allowed near a shader until this sheet says otherwise.

## TB-12 and the corrections the test forced (2026-08-22, second pass)

Three faults from the previous sheet, and what each turned out to be:

**The gold read as thin fins.** Correcting it by raising the pieces turned
them into HORNS — the sheet caught that immediately. The mistake was
dimensional: a plate is *long, wide and thick*, never tall. Rise is only how
far the crown stands proud of the skin (1–2.5 cm), and the mass has to come
from the footprint and the section. The pieces are wider and longer now,
with a rounder crown, a subtle spine ridge and a genuinely thick underside
that stays below the skin, seated so only the crown shows.

**The lids were not distinguishable.** They are scaled to the ORBIT rather
than the globe now, with resting closures that leave real geometry
overhanging at full open — the ruling's requirement that a still contain
evidence of three closure systems.

**The distal half was uniform.** The profile past the station is now a
rhythm rather than a taper: pinch, swell, pinch, swell, pinch, swell, the
knuckle's waist, the knuckle, the narrowing, and a club that flares.

**The rig (§14–§15).** Twenty-eight deform bones — five heavy proximal, six
ocular, nine flexible mid/distal, eight highly flexible tip — as B-Bones
with four segments each, so the flesh bends smoothly between few controls.
Nine secondary bones for the eye, the three lids, the orbital gold and the
membrane, each parented to whichever spine bone actually covers its place
on the body. Twist is distributed on the bones as the ruling specifies —
root 10 %, mid 30 %, distal 60 % — rather than dumped into one joint. The
cage takes automatic weights; the 95 separate system objects ride as
armature-bound rigid pieces, because a lid or a gold plate is a rigid thing
on flesh, not something that stretches.

Exported at 3.0 MB and **verified importing into Godot** with no errors.

**Where the test stands.** The three-quarter view now reads as an animal:
an ocular station with the eye in a real socket under a brow, gold plates
lying along the flesh with visible mass, swept cilia, a ribbed shaft with a
swell-and-pinch rhythm, a sucker row on the ventral club, and a membrane
bowl at the root. It is not finished — the flesh wants the sculpt pass
(§3's tertiary scale), the crystals are still sparse punctuation rather
than organs, and nothing has been posed through §23's clearance tests — but
it is past the point where a shader would be inventing the anatomy.
