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
