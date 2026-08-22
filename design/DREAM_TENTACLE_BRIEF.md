# DREAM TENTACLE — concept brief and build

Owner direction 2026-08-22: *"manifest a detailed 3D mesh tentacle of
purple flesh / molten gold with an angel's eye embedded in it that reaches
through the surface of the crawling encroachment and explores the surface
of objects nearby, in a disturbingly sensual way, briefly spreading the
dream substance on the new surface. It should cast light from the glowing
golden parts of its skin while being wet and plump organic matter on the
fleshy bits, veins that pulsate, suckers that grip… alien, organic,
metallic-mechanic, hyperdimensional and magical in luminance and movement.
Model it on insect antennae and octopus tentacles, like a curious
intelligence exploring a new thing. It is a hyperdimensional dreamworld
entity reaching into our fleshy three dimensions."*

## 1. Concept (for art)

**What it is.** A hyperdimensional dreamworld intelligence putting one limb
through the crawling encroachment into the building's three dimensions. Not
an attack — curiosity. An insect's antenna crossed with an octopus's arm: it
comes out of the wall slowly, hovers, trembles, approaches an object,
touches it, caresses along its surface with deliberate, unhurried
attention, then withdraws back into the wall, leaving the dream's substance
where it touched.

**Scale and silhouette.** About 1.6 m fully extended; 15 cm across at the
root tapering to a finger-width tip with a rounded, slightly bulbous end
like an antenna's club. It does not emerge from a hole: the wall's surface
— already a living violet sheet of the organism — bulges and the tentacle
pushes out through it as through a membrane, the sheet clinging to its
base. Its length is segmented like an antenna: every ~9 cm a raised collar
of molten gold rings the flesh, so it reads as articulated and mechanical
although the flesh between flexes continuously.

**Skin — two materials fighting for one body.**
- *Flesh*: purple, plump, wet. Deep aubergine `#24081F` in the hollows, a
  bruised magenta-violet body `#6B1640`, crests of lighter rose-violet
  `#9E3A78` on the ridges. Subsurface glow; a wet film with tight
  specular highlights. Overfull, under pressure; it breathes (a slow
  plumping every few seconds) and a peristaltic wave runs root to tip.
- *Molten gold*: seams and patches of liquid gold `#DBA84C` flowing slowly
  along the length, cracked with hotter veins glowing amber `#FF9E2E` from
  inside like cooling lava. The collars are solid gold. The gold emits
  light — warm light on the wall and on what it touches — and the light is
  not steady: it flickers like something slicing through from a fourth
  direction, not like flame.

**Veins.** Three dark crimson `#80101F` veins spiral along the flesh in a
loose helix, raised like cords under the skin. A brighter pulse travels
along them tipward every second and a half.

**Suckers.** Two staggered rows of small pale-pink `#C77590` suckers on
the ventral side, soft domes with darker rims, antenna-small (1–2 cm).
When the tip finds a surface the suckers near it flatten and their rims
brighten to luminous pink — gripping, tasting.

**The angel's eye.** Set in the flesh four-fifths of the way to the tip,
dorsal, ~8 cm across: ivory-gold sclera, an iris of gold streaked with
radial filaments like a halo in a Byzantine icon, a dark pupil that
dilates with the pulse and tracks — it looks at the player when they are
near, otherwise at what the tip is touching. Lids of flesh close over it
sometimes. Around the eye, floating slightly off the skin, two thin rings
of light: an inner ring of slowly rotating gold beads and an outer ring of
sparser points — the halo of the old kind of angel, the wheel-with-eyes
kind, reduced to one eye and its rings.

**Hyperdimensional tells.** A thin rim of iridescence on the flesh's edges
in colours no pigment has (oily violet-green-gold). A faint shimmer in the
outline — small parts flicker out of position for a frame, as if only a
slice of it is ever fully here.

**Motion.** Emergence 3 s, the sheet bulging, the tip nosing through
first. Seek: an arc out from the wall, fine tremor at the tip (5–7 Hz,
small), the eye opening. Approach: slowing within 10 cm of the object,
hovering, tilting — considering. Touch: the tip lays along the object and
slides in slow figure-eights, the last third curling gently around an
edge — an octopus curl. Where it has touched, a violet-gold stain spreads
on the object and the living sheet follows. Recoil: if the player comes
within arm's reach it flinches back and coils tighter, the eye fixed on
them, then resumes. Withdrawal: it draws back into the wall, the suckers
releasing last.

**Framing for art.** (1) 2A's west wall at night, the organism's violet
sheet over the wallpaper, the tentacle out of it reaching for the sofa,
gold light on the cushions, the eye turned to camera. (2) Close on the tip
caressing the rim of a radiator, suckers flattened, the pulse in the
veins, gold light on the iron. (3) Emergence: the membrane stretched over
the club of the tip as it pushes through.

## 2. Build

- `game/shaders/dream_tentacle.gdshader` — the mesh is a unit tube (UV.x
  around, UV.y along). The script animates a 16-point spine in world space
  with a parallel-transported side vector per point; the vertex stage bends
  the tube along it (Catmull-Rom) and adds the flesh's relief: profile
  taper, peristalsis, breathing, the veins' ridges with the pulse, the
  suckers' domes (flattened under `grip`), the antenna collars, a 4-D
  flicker. `grow` collapses the part not yet through onto the point where
  it leaves the surface, so it extrudes from the wall. The fragment stage
  is the skin: flesh (fbm + cells, backlight, wet), molten gold seams
  flowing tipward with hot cracks (emissive), the veins' pulse, the
  suckers' rims (brighter under grip), the eye (sclera / streaked gold
  iris / tracking, dilating pupil / lids) and its two floating halo rings,
  the hyper shimmer on the emission, the rim iridescence; a bump from the
  relief's finite differences.
- `game/scripts/reality/dream_tentacle.gd` — `DreamTentacle`: builds the
  tube (64 rings × 24 segments), animates the spine (a cubic from the
  anchor along its normal to the tip with tremor, sway and the curl),
  parallel-transports the sides, chooses a target among nearby meshes,
  slides the contact along its surface, recoils from the player, deposits
  the dream substance into the living field where it touches
  (`LivingField.deposit`), carries two gold OmniLights (the eye, a mid
  seam), withdraws after its exploration.
- `ApartmentEncroachment` tends up to two per storey at the organism's
  strongest nodes (anchored to the nearest surface by raycast), only on
  the player's storey; `TENTACLE=0` off, `TENTACLE_FORCE=1` spawns at each
  forced case's source at once, `TENTACLE_HOLD=1` keeps them out for
  frames.
