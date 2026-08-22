# The Dream tentacle — the antagonist's first manifestation

Rulings: `design/DREAM_TENTACLE_DIRECTION.md` (the encounter, the systems)
and `design/DREAM_TENTACLE_DIRECTION_2.md` (the hero material and anatomy —
carnal flesh, biomineralized gold, the ensconced eye). Concept and build
notes: `design/DREAM_TENTACLE_BRIEF.md`.

## Built so far (direction 1, phases 1–5)

- **Rig** (`dream_tentacle_rig.gd`): sixteen joints, damped springs after a
  cubic from the root to the tip's goal, root heavy / tip precise; the
  length kept (the bow takes up slack and is fitted to the body); a distal
  curl that bends the run without moving the aim; the antenna tremor
  (6 Hz, 3.5 mm) on the distal quarter while sampling; parallel-transported
  sides; a per-joint silhouette profile (radius, flatten, twist, rib) —
  muscular root, compressed section, rounded segment, ribbed section,
  flattened ribbon span, articulated narrowing, fine distal limb, club; a
  ventral roll that brings the suckers to the surface without twisting the
  body (the impossible twist).
- **Behaviour** (`dream_tentacle_behavior.gd`): DORMANT, MEMBRANE_BULGE,
  EMERGING, ORIENTING, SEEKING, APPROACHING, HOVER_INSPECTION, TOUCHING,
  CARESSING, TASTING, RESTING, WATCH_PLAYER, FLINCH, RESUME, WITHDRAW, with
  its timings in `DreamBehaviorProfile` and the player's three zones (far,
  near, arm's reach; a rush makes it flinch).
- **Contact** (`dream_contact_sensor.gd`): objects expose a
  `DreamTargetProfile` (the radiator's is its top rim, traced along the
  sections); the contact slides in figure-eights while caressing and
  traverses the edge while tasting, landing on the real surface by ray.
- **Conversion** (`dream_surface_transformer.gd`, `DreamContactProfile`):
  the touch deposits the Dream's substance into the living field at the
  contact and a ring around it, so the layered surface shows it and the
  organism follows.
- **Eye** (`dream_tentacle_eye.gd`, `dream_eye.gdshader`), **halos**
  (`dream_halo_controller.gd`), **suckers** (`dream_sucker_controller.gd`,
  `dream_sucker.gdshader`), **membrane** (`dream_membrane.gd`,
  `dream_membrane.gdshader`), **material stack**
  (`dream_entity_surface.gdshaderinc`), **body**
  (`dream_tentacle.gdshader`), **debug panel** (`dream_tentacle_debug.gd`,
  `TENTACLE_DEBUG=1` or F8; every system on its own switch).
- Tended by `ApartmentEncroachment` at the organism's strongest nodes on the
  player's storey. `TENTACLE=0` off, `TENTACLE_FORCE=1` at each forced
  case's source, `TENTACLE_HOLD=1` keeps it out, `TENTACLE_ANCHOR=x,y,z,nx,ny,nz`
  places it, `TENTACLE_GRAY=1` the gray tests, `TENTACLE_BONES=1` the rig.
- `DreamTentacleTest` 20/20 (mesh, anatomy, anchor, the radiator chosen by
  its profile, the profile varying, the state sequence, the tip on the
  contact, the eye open, the suckers engaged, the membrane clinging, the
  conversion in the field, the lights, the rig's length, the flinch, cost
  0.9 ms/frame, the withdrawal).

## `wip1/` — where it stands before direction 2

`tentacle_2a__current.png` (the room), `tentacle_2a_close__current.png`
(the close stand), `gray_close.png` (the silhouette/motion test).

Honest read against direction 2's targets: the body is still **translucent
gel**, not dense meat — the gold reads as **bands and patches painted on**
rather than mineral grown through flesh; the eye is a sphere **on** the
limb rather than in a socket, and at this size and distance it does not
carry; the membrane washes the wall. That is the work direction 2 orders,
and it is the next pass: the flesh's opaque multi-scale skin with a
thickness-driven scatter in a custom light pass, the gold rebuilt as
structural plates + dendrites + microscopic mineralization with sockets,
and the eye moved to 35–50 % and ensconced with its orbital skeleton,
three lids and orbital cilia — starting with the 20–30 cm hero patch
around the eye (direction 2 §H).

## Forward+ and the hero material (2026-08-22, directions 2 and 3)

**The renderer moved.** Owner ruling: *"fuck compatibility, let's make it
cool first."* `forward_plus` is canonical; `compat-renderer-final` (29ca673)
is the tagged fallback. The migration record and both baselines are in
`art/renders/renderer_migration/` — and the surprise is that **Forward+ is
2–3× FASTER on this building** (corridor 13.6 → 4.6 ms GPU, lobby 13.6 →
6.0, 4B kitchen 9.5 → 3.8), because the frame is draw-call bound and
clustered lighting costs less than Compatibility's per-object light loop.
`BuildingRoot._announce_renderer()` prints `[RENDER] forward_plus` and
shouts if the driver ever silently falls back.

**The flesh is meat now.** `dream_entity_surface.gdshaderinc` was rebuilt on
the real stack: `sss_mode_skin` with `SSS_STRENGTH` /
`SSS_TRANSMITTANCE_COLOR` / `_DEPTH` / `_BOOST` driven by a **thickness**
the host computes per vertex (the muscular root is opaque; the distal limb,
the club's rim, the socket's lids and skin stretched over a vein or a
mineral root are membranes, and only they give up fuchsia). Four colour
frequencies; mesostructure (branching vessels at two scales, cords along
the limb, nodules) seen *through* the tissue rather than painted on it;
three independent normal scales; the wet film as **clearcoat with its own
normal and its own drift**, so what reflects off the liquid does not move
with what scatters through the flesh; sparse iridophores; papillae that
rise with attention. Several clocks that do not share a period (vascular
1.47 s, breath 5.3 s).

**The gold is grown.** The collars are deleted. `DreamGoldSkeleton` places
eight irregular structural plates whose ends sink under the skin, five
dendritic struts each rooting them into tissue, and the shader's
microscopic mineralization around every root; the flesh answers with a
compressed lip, a pressed hollow, scarring and veins that bend around the
socket. Every plate has its own sub-millimetre mechanics — lift on the
beat, slide, lock on a startle — and the seam under it brightens as it
moves. `dream_gold.gdshader` varies roughness by how the piece grew
(polished crown, satin flanks, crystalline facets, rough buried ends) with
anisotropy along the growth direction, and a reflection probe on the
creature gives the metal a room to reflect.

Three faults found and fixed by photographing masks rather than guessing:
the root mask was ~90° wide per plate (eight plates turned the whole limb
metallic); the gold field summed two broad noise thresholds and saturated;
and every sub-pixel field aliased into glitter — now every fine field fades
against the **screen-space footprint** (`de_pixel_m` / `de_resolvable`),
which any future Dream material inherits.

`wip2_forward_plus/`: the close and room stands, plus the gold mask that
found the first fault. Gates: parse, DreamTentacleTest 20/20,
ApartmentEncroachmentTest 13/13, OrganismIncidentsTest 18/18,
LivingFieldTest 14/14, WalkTest FAST, LightingAudit 127 spaces.

**Not done, and ruled:** the ocular assembly (eye at 35–50 %, deep socket,
orbital gold skeleton, three lids, 12+ cilia), the crystal organ, the hero
patch's frame set and its 10–15 s flashlight sweep (DIRECTION_2 §C/§H,
DIRECTION_3 §H–§J, §N); DT-4's quality audit now that the old performance
ceiling is gone; DT-5's "bobbing for apples" — the tentacle emerging along
the encroachment's edge, swelling it locally, searching the building for
the case's resident.

## The ocular organ (2026-08-22, DIRECTION_2 §C, DIRECTION_3 §H–§J)

`DreamOcularAssembly` replaces the sphere-on-a-limb. Seven parts, all real
geometry:

- **The orbital mass.** The eye sits at **42 %** of the limb, and the limb's
  own silhouette profile now SWELLS there (1.34× radius) — the organism had
  to evolve anatomy to carry it. The distal end is tactile; the intelligence
  sits back in the mass.
- **The socket.** The flesh shader cuts a real orbit: a bowl, a heavy
  overhanging brow on one side, a cushioning fold opposite, lateral folds
  and compression wrinkles radiating out of it, with rim mass that closes
  over the globe so the whole sphere is never inferable.
- **The globe** (36 mm), sunk to just over half its radius, with the **iris
  physically recessed** — the view ray parallaxes it against the pupil's
  rim — under a **separate corneal cap** carrying the tear film, and a pupil
  darker and deeper than the globe can hold, opening on the interior.
- **The orbital skeleton**: ten asymmetric gold pieces ringing the socket
  (one heavy brow, nine smaller supports at uneven angles), tensing by
  fractions of a millimetre when the eye is about to move.
- **Three lids** on three vectors — an oblique dorsal lid, a ventral/lateral
  lid that twists round the orbit, and a partly translucent nictitating
  membrane with gold vascular filaments and its own muscular leading edge.
  They overlap for a fraction of a second and no two share timing.
- **Eighteen cilia** in three classes (flesh whisker, gold filament, crystal
  needle with a lens bulb) from visible follicles, each a damped spring with
  its own stiffness and phase. **They feel a stimulus and orient before the
  eye turns** — cilia → orbital gold tenses → lids anticipate → globe moves.
- **The crystal organ** in the rim's gold: a faceted growth whose interior
  is marched in local space (fracture planes, inclusions, a core that
  carries the pulse) with no transparency at all, and a glint that only
  happens when view, facet and light line up.

`wip3_ocular/`: the macro and the 45° oblique. `_before_globe_engulfed_limb.png`
is kept as the instructive failure — the globe's radius (46 mm) was larger
than the limb's radius there (41 mm) AND it was seated at the limb's axis,
so a "sunk" eye swallowed the arm. Sizing it as an organ and giving the limb
orbital mass fixed it. Two more found the same way: the cilia at three
globe-radii read as urchin spines (now 0.55–1.45 radii), and the halo rings
— direction-1 language — fight a real orbital skeleton, so they are OFF by
default (`TENTACLE_HALOS=1` restores them) per §29, never every effect at
once.

Gates: parse, DreamTentacleTest 20/20, encroachment 13/13, incidents 18/18,
WalkTest FAST.

**Still open on the organ:** the lids need to read in a still (they are
animated and present, but at rest they sit inside the orbit); the §N frame
set — direct and grazing flashlight, backlight through thin tissue, macro,
gameplay distance, direct eye contact, tracking, a full three-lid blink,
cilia reaction, vascular pulse, gold articulation, crystal glint — and the
10–15 s flashlight sweep that is the actual review asset.

## Hero pass P0–P3 (2026-08-22, `design/DREAM_TENTACLE_HERO_PASS.md`)

The brief's diagnosis was right and its acceptance rule is the one that
matters: *if a feature cannot be perceived in the canonical images, it does
not count.* Everything below was judged from photographs, several of which
proved my own previous claims wrong.

**P0 — macro silhouette.** The rig's profile now carries fifteen knots with
real regional identities instead of a taper: a broad muscular root and
shoulder, a **hard compressed neck** at 0.16, the **ocular station at 0.42
swelling to 1.92×** (2.8× the neck), its shoulder falling away, a flattened
transitional **ribbon** at 0.56, a ribbed mineralized shaft that swells and
pinches twice, an articulated knuckle waist, a dexterous narrowing, and a
**sensory club** at the tip. `silhouette_gray.png` is the honest test —
`_before_silhouette_gray.png` is the same stand before the push, and the
difference is the point. A new `tentacle_broadside` stand was added because
every earlier judgement had been made from a nearly end-on camera, where a
silhouette cannot be judged at all.

**P1 — the clean gold stripes are gone.** The skeleton was a MultiMesh, so
every piece necessarily had the same shape, and wide shells wrapped the
limb into bands — that is exactly how the painted-jewellery read happened.
It is now **twelve individually generated meshes in five classes**:
CRESCENT (an arc that thins to nothing at both ends and bows off-centre),
PLATE (broad, lobed on one flank, asymmetric termination), KNUCKLE (two
masses and a waist — an articulation), BRANCH (splits and buries one fork),
SPUR (emerges from under the skin). None repeats; none closes a ring; the
ocular station is deliberately bare so its own gold reads.

**P3 — flesh separation.** Two mistakes of mine, both found by camera:
my specular-anti-aliasing term used a gain of 900 and a cap of 0.35, which
pushed the entire surface to roughness 0.8 and *flattened the flesh into a
smooth tube* — it is now a proper small Toksvig-style nudge (gain 45, cap
0.05). And the film was near-continuous, so everything read glossy; the
wet mask now has large dry islands, runs downhill, and pools only in
creases, sockets, sucker fields, contact and the underside. The pores read
as **darkening and AO**, not as specular sparkle, so they survive. Colour
now follows depth: crests bruised rose-violet, hollows aubergine
approaching black.

Gates: parse, DreamTentacleTest 20/20, encroachment 13/13, incidents
18/18, WalkTest FAST.

**Honest state.** The silhouette test passes now. The flesh reads as meat
at macro and as dense purple mass at distance. What still does NOT read,
and is next: the ocular station faces away from the broadside stand so its
authority is unproven at gameplay distance (P2); the gold articulation,
vascular pulse and lid systems exist but have never been photographed in
motion (P4); and the §15/§16 review set — the fifteen frames and the
10–15 s player-lamp sweep — has not been captured. ffmpeg is available, so
the sweep can be a real video rather than a contact sheet.
