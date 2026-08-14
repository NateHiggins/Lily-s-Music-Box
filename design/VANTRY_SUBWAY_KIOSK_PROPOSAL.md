# The Vantry subway kiosk — a historical detail without a subway level

*Proposed 2026-08-14. This is a scoped art, fiction and implementation
proposal, not production permission. It does not reopen the approved M0.5
map. The final world remains ORISON, STREET and PASSAGE, and the level walk
from STREET into the Vantry Arcade remains the playable route.*

---

## 1. Decision in one sentence

Build a compact, photo-faithful **exit-only rapid-transit kiosk beside the
Vantry Arcade entrance**, not in place of it, and model only the upper stair
and a visibly one-way gate; imply the railway below the map with sparse sound
and a masked reflected glow.

This is the cheapest version that earns the historical detail without adding
a false door, a compulsory transition, a fourth zone or an unusable miniature
station. It also helps the gateway composition: the kiosk gives the street a
strong inhabited foreground object while the separate Vantry host facade
solves the floating black portal.

The kiosk is a companion to the gateway correction in
`design/VANTRY_GATEWAY_AND_SUBWAY_PROPOSAL.md`. It does **not** replace the
host facade, parapet, recess and backed vestibule required there.

---

## 2. What the owner's image gets exactly right

The supplied image is the correct visual family:

- a civic object small enough to sit on the pavement rather than become a
  building;
- a tall cast-iron head bay carrying the transit word at pedestrian height;
- ornate iron posts, capitals, brackets and a strongly capped roof;
- high opaque panels below dirty translucent glazing;
- an enclosure whose roof and side panels follow the descending stair;
- enough visual mass to conceal almost everything below pavement.

The last two points are the production trick. The object can look complete in
the street frame even though the modeled stair stops after a shallow landing.
Opaque wainscot, misted glass, the falling roofline and the gate hide the
termination honestly.

There is one important historical and gameplay caveat. The owner's image is
an **entrance** form: the large domed head and `ENTRANCE TO TRAINS` band invite
the viewer to go through it. The c.1905 photograph in the Library of Congress
shows the entrance and exit as different companion objects: the entrance has
the domed, leaf-shingled head; the exit is smaller and has a four-sided peaked
wire-glass top. A beautiful entrance whose door never works would be a strong
false affordance.

The historically strict treatment is therefore the smaller **EXIT** kiosk.
The owner's domed silhouette remains an explicit alternative in section 9;
it must be explained as a closed or converted entrance rather than silently
relabeled.

The supplied image should guide composition and mood, but should not be copied
into the repository until its source and rights are known. The production
trace reference should be the Library of Congress record marked with no known
restrictions on publication.

---

## 3. Historical basis

This is a synthesis of documented New York transit architecture, not a replica
of a named station.

### 3.1 Exterior form

The Library of Congress photograph
[Subway entrance and exit kiosks, New York City](https://www.loc.gov/item/2016804671/)
records the paired c.1905 forms: ornate cast iron and glass; paneled lower
walls; descending enclosures; a domed entrance roof; and a smaller peaked-glass
exit. It is the principal silhouette and detail reference.

The documented IRT kiosk family used cast-iron frames and glass, with the
entrance and exit made visually distinct. Entrance heads used domed roofs with
leaf-like cast-iron shingles; exit heads used peaked wire-glass skylights. The
standard objects were narrow and long rather than room-sized, which is exactly
what the residual strip beside the Vantry portal can accept. The historical
dimensions summarized in
[Architectural Designs for New York's First Subway](https://www.nycsubway.org/wiki/Architectural_Designs_for_New_York%27s_First_Subway_%28Framberger%29)
include widths from 4 feet 3 inches and common lengths from 17 feet 2 inches.

The
[1904 account of the subway and its stations](https://www.nycsubway.org/wiki/The_Subway_and_Its_Stations_%281904%29)
also explains why entrance and exit stairs were separated: passenger flow was
part of the design. `EXIT` is therefore not a convenient modern excuse for a
locked prop; it is faithful to the original operating logic.

### 3.2 Interior glimpse

The Landmarks Preservation Commission's
[IRT underground interior designation report](https://s-media.nyc.gov/agencies/lpc/lp/1096.pdf)
documents the useful palette: small white glazed or glass wall tiles above a
low Roman-brick or marble wainscot, terra-cotta/faience borders and individual
mosaic or name plaques. The Vantry stair needs only a short suggestion of that
system, not an entire station kit.

### 3.3 Queens plausibility

The
[Queensboro Bridge underground trolley terminal kiosk](https://www.loc.gov/pictures/item/ny0942/),
designed in 1909, is direct borough precedent for a highly finished street
pavilion leading to transit below grade. The New York Transit Museum's
[Flushing Line history](https://www.nytransitmuseum.org/wp-content/uploads/2024/04/Worlds-Fair-Tour-Guide.pdf)
places the first segment in service in 1917 and its final three Queens stations
in January 1928. A surviving 1910s transit exit in the game's 1928 Queens is
therefore plausible.

Do not assign it a real line, station or street. The game's exact location is
deliberately unspecified, and a station name would establish more geography
than the story needs. The large sign says **EXIT**; a small subordinate plate
may say **RAPID TRANSIT**. That is enough.

The black-and-white evidence does not establish one authoritative paint
colour. Use historically plausible material behavior—painted iron, dirty
wire glass, stone and tile—without claiming that a guessed green or bronze is
the documented original colour.

---

## 4. Fiction and relationship to the Vantry Arcade

The arcade opened in 1912. The cleanest fiction is that a later rapid-transit
exit was cut into the east residual strip when rail reached the district in
the 1910s. It shares the Vantry frontage but is not a door into the shops.

What the player should understand from one frame:

1. **VANTRY ARCADE** is the broad, level, usable entrance.
2. **EXIT / RAPID TRANSIT** is the narrow stair from somewhere below.
3. The exit gate works in the outward direction and is not the player's route.
4. Trains continue beneath the neighbourhood whether or not the player sees
   one.

The kiosk adds ordinary city infrastructure, not a supernatural clue. Its
interest comes from specificity, age, weather and coexistence with errands.
It should look as though generations of commuters have touched the handrail
and rain has worried the iron, not as though it is a mysterious sealed portal.

---

## 5. Placement and dimensioned blockout

The approved portal and throat do not move:

- portal: Blender `x 11.000..17.000`, `y -28.316`;
- throat: `x 11.000..17.000`, `y -28.316..-38.600`;
- approved east stage edge: `x 20.600`;
- east residual width beside the throat: 3.600 m.

Trial the kiosk in that east residual strip, parallel to the throat:

| element | trial envelope | purpose |
|---|---:|---|
| complete kiosk | `x 18.10..19.75`, `y -27.80..-33.25` | 1.65 m wide × 5.45 m long; close to the documented narrow kiosk family |
| separation from arcade portal | 1.10 m from `x 17.00` | keeps the broad arcade mouth visually and physically unambiguous |
| separation from east stage edge | 0.85 m to `x 20.60` | leaves architecture/weather margin rather than touching containment |
| visible stair | 0.90–1.05 m clear width | convincing single-file exit flow; never a player route |
| modeled descent | 6–10 risers, approximately 1.05–1.70 m | enough parallax to prove a stair without building a concourse |
| head height | approximately 3.25–3.65 m | subordinate to the 4.38 m Vantry portal head |

These are **blockout dimensions**, not a new spatial ruling. Before detail,
project the volume into the accepted street cameras and verify it against the
actual generated furniture, pavement, weather paths and collision. If the
east strip contains an unrecorded conflict, mirror the same narrow kiosk into
the larger west residual strip; do not narrow or move the fixed portal.

The kiosk may cross the ownership plane visually because it is a STREET
foreground object, like the existing passage proxy. Its collision and stair
void remain entirely outside the approved playable throat. It must never make
the level route narrower.

---

## 6. What is actually modeled

### 6.1 Exterior kit

- one granite or dark stone plinth and curb return;
- four main painted-cast-iron posts with simplified capitals;
- paneled iron wainscot, approximately 0.85–1.05 m high;
- dirty, rippled or wire-reinforced translucent glass above it;
- sloped side rails and roof following the stair;
- the recommended exit-type four-sided peaked wire-glass head;
- two or three repeatable low-relief rosettes/brackets, not unique sculpture;
- one large `EXIT` sign band and one small `RAPID TRANSIT` enamel plate;
- gutter lip, downpipe or chain, splash staining and a small pavement drain;
- worn brass/iron handrail and a visible one-way exit gate.

Ornament should live in silhouette only where it matters—the roof edge,
capitals and two brackets. Rosettes, rivets and panel relief should be a trim
atlas or shallow repeated stamp. Do not sculpt every capital at hero-prop
density.

### 6.2 Shallow below-grade diorama

- 6–10 real stair treads;
- tiled side returns and one narrow border course;
- one partial mosaic or enamel direction plaque with no station name;
- the one-way iron gate across the stair, visibly owning collision;
- a dark lower landing/backstop angled so no accepted camera sees its end;
- an optional wet floor strip and drain at the landing.

There is no platform, track, tunnel, train, fare-control room or traversable
underground space. The high wainscot prevents street cameras from seeing most
of the stair; obscured glass prevents them from solving its depth; the lower
landing turns or terminates behind an opaque wall before the illusion breaks.

The pavement opening exists only inside the closed kiosk footprint. It must
have its own simple sealed collision lid/gate arrangement and must not expand
SafetyNet or create a fall volume. The visible ironwork, not an unexplained
invisible wall, prevents entry.

---

## 7. Sound, light and weather sell the unmodeled railway

### 7.1 Sound

Use one positional source at the hidden landing and an event-driven timer. At
long, irregular intervals—trial 45–120 seconds—it may play one short cue:

- a low rail rumble arriving through masonry;
- a restrained wheel-flange curve;
- a brief brake or air release;
- a gate rattle or change in the stairwell draft after the train passes.

No constant train loop. No audible public-address system unless later research
establishes a period-faithful one. The sound should be missable slice-of-life
texture, not a quest marker or proof that a full level exists.

The cue should attenuate rapidly inside the Passage so it does not become a
hall ambience tax. If it competes with dialogue, the kiosk loses.

### 7.2 Light

Add no real-time light. A rare warm or pale reflection may climb a narrow
masked strip on the tiled landing at the same moment as the train cue, then
fade. It is an emissive/material event visible only through the glass, not a
light that illuminates the street or consumes the 16/16 budget.

The kiosk itself relies on the existing street/weather illumination. Any sign
lamp must reuse a currently budgeted street fixture or remain an unlit painted
sign.

### 7.3 Weather

The overcast driving-rain system should make the kiosk better, not necessary:

- rain beads and streaks on the upper glass;
- a hard drip line from the eave;
- localized runoff at the downpipe/drain;
- wet iron highlights and a darker splash band at the plinth;
- slightly clearer interior glass immediately under the roof, where less rain
  hits it.

The historical form must still read with weather disabled. Fog cannot be used
to conceal an unfinished back or open floor cut.

---

## 8. Gameplay and affordance contract

The kiosk has no interaction prompt and no usable door. It is legible as an
exit because all of the following agree:

- `EXIT`, not `ENTRANCE TO TRAINS`, is the dominant word;
- the visible gate/turnstile faces the outward flow;
- stair and door hardware indicate egress rather than invitation;
- the broad named Vantry entrance remains the brighter, clearer shopping
  route;
- player collision coincides with the physical gate and iron enclosure;
- nothing glows, highlights or uses the interaction reticle on the kiosk.

Do not add an NPC emerging from the stair in this pass. That would require
spawn provenance, schedule, occlusion and persistence logic and would turn a
static urban fact into a system. The exit can be operational in fiction while
quiet in the minutes the player is looking at it.

Do not hide a collectible, shop, dream entrance or case clue below it. Those
uses would convert a clear background boundary into a promise of future access.

---

## 9. Tiered treatments

| tier | visible result | cost and risk | ruling |
|---|---|---|---|
| **K0 — shell** | Exit kiosk exterior, opaque lower panels and black-backed glass; no visible stair, sound or light. | Lowest art cost, but closer views may expose it as a scenic box. | Safe fallback. |
| **K1 — shallow working exit** | Historically strict peaked-glass exit, 6–10 steps, one-way gate, tiled turn, rare sound and masked reflection. | Small static diorama plus one timer/audio source. No route or zone changes. | **Recommended.** Maximum historical and urban value per unit of work. |
| **K2 — converted domed entrance** | The owner's large domed entrance silhouette. Old `ENTRANCE TO TRAINS` lettering remains as a ghost or original band, overlaid by a later `EXIT ONLY` or `ENTRANCE CLOSED` enamel plate. | Strongest image, but establishes a local history of conversion and needs signage art that defeats the false affordance from every approach. | Valid only by explicit owner ruling. |
| **K3 — active entrance or NPC exit** | Open stair, commuters, or implied player access. | Needs a destination, actor schedules, traversal and persistence. Makes the missing station content conspicuous. | Defer/reject for this milestone. |
| **K4 — station or train cutscene** | Concourse/platform/train or a transition to another map. | Project-scale content and repeated interruption to errands; contradicts the continuous Vantry route. | Reject as a gateway solution. |

K2 should not be presented as an exact historical exit. Its interest is the
fictional adaptation: the old entrance survived while its use changed. If the
owner chooses K2, add one mundane reason to the environment—a replacement
plate, welded one-way gate and mismatched paint—and nothing more.

---

## 10. Production ownership and budget

Build the static kiosk through `art/data/gen_layout.py` or the existing
generated-architecture path, not as dozens of runtime props. Reuse current
material families wherever possible: metal, glassish, limestone/stone,
subway tile and common masonry. One small trim/sign atlas is preferable to
many unique materials.

Initial production budget:

- 3–5 merged visible material buffers;
- one combined architectural collision shape plus the gate collision;
- one event-driven Timer and one `AudioStreamPlayer3D` if K1 ships;
- zero `_process` methods;
- zero new real-time lights;
- zero navigation or interaction nodes;
- no separate World3D, SubViewport, train scene or underground ownership zone.

The kiosk should be indexed with the STREET/`passage_proxy` population so it
remains coherent in the street-facing threshold frames. It must not be counted
as Passage shop geometry and must not stay alive as a foreign light or caster
inside the hall.

The canonical-night Passage northbound station already has an accepted
approximately 1.2 ms blocker. Any measurable regression outside repeat-run
noise fails. If ornament cannot merge cleanly, remove ornament before relaxing
that gate.

---

## 11. Proof gates

### A. Geometry and route

1. Dimensioned top-down blockout proves the complete kiosk and its collision
   remain outside `x 11..17` throughout the fixed throat.
2. `FinalMapRouteTest` passes both directions with its existing walked route;
   no waypoint or teleport moves to accommodate the kiosk.
3. A player capsule cannot enter or fall into the stair; every collision hit
   corresponds to visible iron, glass base, gate or masonry.
4. `StreetContainmentTest`, `PassageNavTest`, `PassageVisibilityTest`,
   `PassageOwnershipAudit` and WalkTest FULL remain green.

### B. Affordance

Take dry-control and driving-rain renders from:

- the accepted street portal camera;
- northbound and southbound pavement approaches;
- the roadway arrival angle;
- immediately before, on and after the `z = 28.316` ownership boundary;
- the return-facing-street view from the throat.

In an unprompted review, the arcade must read as the usable entrance and the
kiosk as an exit-only transit object. If reviewers try to enter it or mistake
it for the Vantry door, revise the sign/flow or drop to K0. Do not solve the
confusion with UI text.

### C. Historical fidelity

Compare the final against the c.1905 LOC entrance/exit photograph and the
Queensboro kiosk record. Verify:

- entrance and exit roof types were not accidentally conflated;
- lower panels are high enough to hide the stair plausibly;
- the glass reads as old translucent/wire glass, not modern frameless glazing;
- lettering avoids modern subway bullets, roundels and contemporary fonts;
- no unsupported real station/line name has entered canon.

### D. Performance and audio

- repeat paired canonical-night station measurements with the kiosk on/off;
- prove no extra real-time light or shadow caster entered the 16/16 budget;
- verify the rare audio event sleeps between cues and is inaudible where
  Passage dialogue happens;
- capture one deterministic diagnostic render with the emissive reflection
  forced on, then return it to event-driven operation.

---

## 12. Build order

1. Add a dimensioned grey block in the east residual strip; render the five
   approaches before cutting pavement.
2. Block the separate Vantry host facade at the same time. Judge the combined
   composition, because the kiosk cannot make the black portal architectural
   by itself.
3. Build K0 exterior with opaque panels and EXIT typography. Prove route,
   ownership, containment and submission cost.
4. If close-view renders justify it, cut only the sealed kiosk footprint and
   add K1's shallow stair, gate and tiled turn.
5. Add rare positional sound; add the masked reflection only if sound alone
   does not communicate below-grade life.
6. Run the full proof gates and commit the production source, regenerated
   products, tests and evidence by explicit path.

No subway asset work begins before the blockout proves that this companion
object improves the gate without crowding the Vantry entrance.

---

## 13. Owner ruling requested

Approve **K1, the historically strict exit-only kiosk**, as the first
blockout. It is the best answer to “how do we add the subway cheaply?” because
it depicts exactly the part of a subway a street pedestrian would encounter,
uses the historical enclosure itself to hide the unmodeled world, and leaves
the player's shopping loop completely uninterrupted.

If the domed object in the supplied image is the non-negotiable hero shape,
approve K2 instead and treat it honestly as a converted/closed entrance. Do
not combine the domed entrance roof, `ENTRANCE TO TRAINS` invitation and an
unusable door without the conversion story.

---

## 14. 2026-08-14 Gate A execution record

**Gate A passes as a reversible massing checkpoint. It does not authorize the
pavement cut, stair diorama, sound, reflected train light or production
ornament.** The owner accepted the recommendation and authorized continued
work; the historically strict K1 exit remains the target.

### 14.1 What was built

The generator now owns one separate `passage_proxy_gateway` batch containing
50 records:

- six records form the Vantry host: two 350 mm brick piers, low parapet,
  limestone cornice and name band, and a shallow rain hood;
- 44 records form the kiosk shell: exact
  `x 18.10..19.75`, `y -33.25..-27.80`, with plinth, high wainscot, segmented
  glass, raked/peaked roof trace, dark backstop and a visible barred gate;
- all 50 are explicitly STREET-owned and remain eligible on both sides of the
  existing Passage ownership plane;
- the two existing portal cage bulbs moved 0.70 m streetward onto the new
  facade plane. No fixture, light slot or energy was added.

The batch imports as six buffers rather than the proposed five: the five box
material families plus the builder's separately realized pipe geometry for the
rake and peak. The separation is retained during blockout because it permits a
true same-build performance control. K0/K1 production must either bring this
back to five or prove that the sixth remains below measurement noise.

### 14.2 The render found and corrected a failure

The first blockout used 6.0 m piers and 1.62 m of solid parapet above the old
head. At night it became another large black billboard—the defect this work
was meant to remove—and its outer pier swallowed the east oblique approach.
It was not accepted.

The surviving revision:

- lowers the pier top to 5.10 m and the parapet to 720 mm;
- narrows each pier from 500 to 350 mm;
- trims the hood projection;
- moves the existing bulbs in front of the face so the masonry, lintel and
  customer floor are illuminated by the light budget already paid for.

The portal now reads as a capped, recessed piece of architecture from the
front, road and west approach. The kiosk stays visibly separate and the six
metre mouth remains dominant. The east approach still turns the unfinished
kiosk side into a broad dark foreground shape. That is acceptable only for
Gate A massing: **K0 historical finish must break this side into readable iron,
wire glass, panel and roof structure before any pavement opening is allowed.**

Rendered evidence:

- `art/renders/vantry_gateway_blockout/after_dry/` — seven canonical-night
  dry controls: front, east, west, road, before-plane, on-plane and return;
- `art/renders/vantry_gateway_blockout/after_weather/` — the identical seven
  camera transforms with production weather enabled;
- the ruled before frame remains
  `art/renders/map_final_acceptance/01_street_portal.png`.

Against that before frame, the final dry front changes 26.52% of pixels beyond
delta 3, at mean absolute channel delta 8.35/255. The share of the complete
frame below luma 16 falls from 79.79% to 77.68%; below luma 32 falls from
86.74% to 83.70%. This is a lighting and architecture improvement, not a claim
that the street has become bright. The dry/weather frontal pair differs by no
more than 0.01% of pixels beyond delta 3; threshold pairs sit at that floor.
Oblique weather views differ as expected where live rain crosses the camera.

### 14.3 Exact geometry and gameplay proof

`VantryGatewayTest` executes ten checks against both the generated records and
the imported collision:

- exactly 50 records, all STREET-owned, split six host / 44 kiosk;
- exact kiosk x and y envelopes, including the radius of every iron pipe;
- no player-height record enters the open `x 11..17` route;
- a player capsule crosses the portal centre unobstructed;
- the same capsule is stopped by the visible front gate and side wainscot.

It passes 10/10. The terminal roof-post pair initially exceeded the written y
envelope by 45 mm; this test caught it and the source was clamped before the
checkpoint.

Regression proof on the final build:

- `PassageVisibilityTest`: PASS, zero failures;
- `PassageOwnershipAudit`: PASS, nine proxy buffers and zero visible
  unclassified F01 draws;
- `StreetContainmentTest`: PASS, zero failures;
- `PassageNavTest`: PASS, every scheduled shop route capsule-clear;
- `FinalMapRouteTest`: PASS outbound and loaded return;
- WalkTest FULL: PASS at `WALKTEST_FULL=1`, `WALKTEST_SCALE=8`, 48.4 seconds.

### 14.4 Performance proof

`PERF_GATEWAY_OFF=1` hides exactly the six separate blockout buffers in
`Perf.tscn`; ordinary runs submit them and production has no toggle.
Fresh-process canonical-night northbound pairs at 16/16, repeated after the
final pipe-radius envelope correction and its rebuild, were:

| state | run 1 | run 2 | mean |
|---|---:|---:|---:|
| gateway visible | 18.39 ms | 17.80 ms | 18.10 ms |
| six buffers hidden | 17.59 ms | 17.62 ms | 17.61 ms |

The apparent +0.49 ms visible cost is smaller than the visible condition's
0.59 ms repeat spread; objects and calls also move in both directions with the
live scene. It is not measurable attribution. Both visible runs remain at the
already accepted canonical-night blocker range, and the gate does not change
the standing 7/11 station result.

### 14.5 Next gate

Proceed only to **K0 historical exterior finish on the same envelope**:

1. replace the stepped grey roof/glass read with the documented exit-type
   peaked wire-glass canopy, iron posts and high paneled wainscot;
2. add unlit `EXIT` / subordinate `RAPID TRANSIT` typography and a blank
   `VANTRY ARCADE` name field for composition testing;
3. solve the east oblique dark-side failure without a new light;
4. keep the separate batch until the same-build performance control is taken;
5. repeat the seven dry/weather renders and the focused proofs.

Only after that exterior reads correctly at all approaches may a later change
cut the sealed kiosk footprint and add K1's 6–10-step diorama. A station,
train, cutscene, interaction prompt and fourth zone remain out of scope.

---

## 15. 2026-08-14 K0 historical exterior execution record

**K0 passes. The kiosk may proceed to K1's shallow stair diorama, subject to
the unchanged scope limits below.** No pavement opening, stair, station,
train, sound cue, reflected train light, cutscene, interaction or fourth zone
was built in this pass.

### 15.1 What was built

The accepted `x 18.10..19.75`, `y -33.25..-27.80` envelope, six-metre portal
and ownership plane did not move. The source batch now contains 228 records:

- the same six host records, including the deliberately blank Vantry Arcade
  name band;
- 222 kiosk records: four recessed soot-and-cast-iron lower panels per side,
  high rails and stiles, four wire-glass side bays, four transparent canopy
  strips, continuous iron rakes, transverse roof ribs and the peaked street
  head;
- geometric, unlit `EXIT` and subordinate `RAPID TRANSIT` lettering, merged
  into the existing soot buffer rather than spawning a runtime text owner;
- a barred, visibly colliding front gate. The gate stops at `z 2.34`; the sign
  is instruction, not an implied player entrance.

The reflective blockout `metal` is gone from the kiosk. Its five box-material
families remain `cast_iron`, `common_brick`, `glassish`, `limestone` and
`soot`; the separately realized pipe geometry remains the sixth buffer. The
east of the two already-budgeted portal cage bulbs moved from `x 16.52` to the
kiosk's street head at `x 19.88`. Fixture count, range, energy and the resolved
16/16 light/shadow budgets are unchanged.

### 15.2 The east mass was not the kiosk

The first K0 beauty pass improved the roof but appeared to leave the large
east-oblique black rectangle intact. That inherited visual attribution was
wrong. Two same-build controls establish it:

1. hiding all six `passage_proxy_gateway` buffers removes the complete host
   and kiosk while the rectangle remains pixel-identical;
2. hiding all five `passage_shell` buffers also leaves it intact.

The corrected ID pass uses the exact approach-02 camera and resolves every
sampled rectangle pixel to the 137-instance exterior-detail box buffer. A
per-instance ray then identifies index 128, world AABB
`(20.420, 0.000, 23.894) + (0.360, 2.400, 4.422)`: the generated
`EastSouthWorks` construction-hoarding collision at the accepted `x 20.60`
stage edge. Its wet-board shader had only an inward quad; camera 02 is outside
the playable boundary and saw the raw back of the collision box.

`StreetEndHoardingFaces` now carries inward and outward faces for all four
pavement boards: eight instances in the same one draw. No collision, stage
edge, light or material family moved. This is the intended visible
architecture/weather answer to a containment surface, not another invisible
wall and not subway scope smuggled into the street-end system.

Diagnostic evidence is under
`art/renders/vantry_gateway_k0/id_east/`; the ordinary shot harness also owns
bounded `GATEWAY_OFF` and `PASSAGE_SHELL_OFF` controls so this attribution can
be repeated without changing a build.

### 15.3 Render proof

Final canonical-night evidence is:

- `art/renders/vantry_gateway_k0/dry/` — seven dry approaches;
- `art/renders/vantry_gateway_k0/weather/` — the same seven cameras with
  production weather live.

Against the Gate A blockout, K0 changes 11.35% of the front frame, 26.22% of
the east approach and 9.68% of the road arrival beyond delta 3. In the exact
east silhouette region, mean luma rises from 2.53 to 17.88; pixels below luma
16 fall from 98.10% to 60.96%. The result remains appropriately dark but now
reads as battered boards, posted paper, iron ribs and glass rather than a
featureless void. Dry/weather pairs remain identical at the front and
threshold views; the 4.20% east difference is live rain crossing the oblique
camera, not geometry drift.

### 15.4 Exact proof and regressions

`VantryGatewayTest` passes sixteen source/runtime assertions:

- 228 records, all STREET-owned, split six host / 222 kiosk;
- both geometric sign strings, four canopy strips and four transverse ribs;
- no blockout `metal` in the kiosk;
- exactly two reused portal lights, with the east fixture at the kiosk;
- exact x/y envelope and no player-height intrusion into `x 11..17`;
- eight visible faces on the four containment boards;
- clear portal capsule traversal and visible collision at the kiosk gate and
  side panels.

The final visual check also caught the initial box-glyph layout reading
backward from the street approach. The generator now lays both character order
and glyph columns in the player-facing direction, and the focused test asserts
that direction rather than merely counting boxes. That correction exposed an
external-buffer import hazard: its `.bin` changed while the `.gltf` descriptor
did not, so Godot kept rendering the cached old word. The canonical Blender
builder now fingerprints every sibling buffer in
`asset.extras.orison_bin_sha256`; geometry-only rebuilds therefore invalidate
the imported scene deterministically.

Fresh production-scene regressions are green: `LightingAudit`,
`StreetContainmentTest`, `PassageVisibilityTest`, `PassageOwnershipAudit`
(zero visible unclassified F01 draws), `PassageNavTest`, and
`FinalMapRouteTest` outbound plus loaded return. WalkTest FULL passes at
`WALKTEST_FULL=1`, `WALKTEST_SCALE=8` in 46.3 seconds on the final canonical
Blender 4.5 export.

### 15.5 Same-build performance control

At canonical night and the pinned 16/16 budget, one fresh-process pair gives:

| northbound state | objects | calls | ms |
|---|---:|---:|---:|
| K0 visible | 6,592 | 8,428 | 17.73 |
| six gateway buffers hidden | 6,578 | 8,420 | 17.34 |

The apparent 0.39 ms delta is below Gate A's already measured 0.59 ms repeat
spread. Only eight calls separate the northbound conditions. K0 therefore
does not create a measurable regression, does not change the accepted 7/11
canonical-night result, and earns retention of the pipe buffer through K1.

### 15.6 Next gate

K1 may cut only the sealed kiosk footprint and build the proposed 6–10-step
non-enterable stair diorama: tiled cheeks, iron handrail, landing plane and a
dark terminus. It must preserve the six-metre route, exact external envelope,
three-zone world, visible collision and two-light budget, then repeat these
seven views and focused tests. Sound, reflected train light and any implied
service below remain later, separately proved gates.

---

## 16. 2026-08-14 K1 shallow stair execution record

**K1's physical diorama passes. The Vantry route remains the only playable
route and the subway remains a historical foreground detail, not a fourth
zone.** Sound and reflected train light were not bundled into this pass; they
remain optional, separately measured gates.

### 16.1 Exact built section

The approved external envelope remains exactly `x 18.10..19.75`,
`y -33.25..-27.80`. Inside it, K1 replaces the sealed stone plinth with a
three-sided curb and cuts only the kiosk footprint through both covering
substrates: the south sidewalk's overlapping `1.65 x 0.516 m` tongue and the
asphalt below it. The pavement beside the kiosk remains unchanged.

The finite section is:

- eight real `0.38 m` treads in a `1.05 m` clear stair;
- `0.16 m` vertical increments, from a first tread at `z -0.14` to the eighth
  at `z -1.26`, followed by a `1.10 m` lower landing at the same level;
- two tiled cheeks, a transverse tiled return leaving only a narrow suggestion
  of an east turn, and a full-width soot backstop inside the accepted kiosk
  footprint;
- paired sloping cast-iron rails and four standards in the existing pipe draw;
- the retained barred gate as the visible, one-way collision owner.

There is no platform, tunnel, station room, train, interaction target,
cutscene, route edge, service schedule, fourth zone or new real-time light.
The two already-budgeted Gate A cage bulbs, 16/16 light/shadow budgets and
six-metre Vantry portal do not move.

The generated Gate A batch now owns 249 records: the unchanged six-record host
and 243 kiosk records. K1 adds only one material buffer, `subway_tile`; the
modified limestone, soot and cast-iron pipe work reuse K0 buffers.

### 16.2 Physical and visual proof

`VantryGatewayTest` now proves the exact record count and ownership, eight
ruled tread positions and heights, 1.05 m clear width, two tiled cheeks, tiled
turn, finite terminus, two rails, four standards, three-piece south sidewalk,
unchanged envelope and route clearance. Its production-scene rays hit the
first stair tread at `y -0.1400` while the adjacent sidewalk remains at
`y +0.0100`; the gate and wainscot retain visible collision and the portal
centre remains capsule-clear.

Final evidence is under `art/renders/vantry_gateway_k1/`: eight dry and eight
weather-live canonical-night frames. Cameras 01–07 repeat K0 exactly. The new
camera 08 stays on the public pavement and looks through the barred gate, where
the descending treads, tiled returns, rails, landing and deliberately finite
dark end all read together. Against K0 dry, the seven established views change
by 1.53%, 5.52%, 3.53%, 2.98%, 7.25%, 8.15% and 0.001% of pixels beyond delta
3 respectively: the opening is legible on its street approaches while the
return view through the actual Vantry throat remains effectively unchanged.

### 16.3 Same-build cost and regressions

At canonical night and the pinned 16/16 budget, one fresh-process pair gives:

| northbound state | objects | calls | ms |
|---|---:|---:|---:|
| K1 visible | 6,584 | 8,417 | 17.69 |
| seven gateway buffers hidden | 6,568 | 8,404 | 17.40 |

The 0.29 ms difference is below Gate A's measured 0.59 ms repeat spread. The
thirteen-call delta includes the one new tile buffer; K1 does not change the
accepted 7/11 canonical-night performance ruling.

Fresh production-scene regressions are green: `VantryGatewayTest`,
`StreetContainmentTest`, `PassageOwnershipAudit` (zero visible unclassified F01
draws), `PassageVisibilityTest`, `PassageNavTest`, `FinalMapRouteTest` outbound
and loaded return, and `LightingAudit`. WalkTest FULL passes at
`WALKTEST_FULL=1`, `WALKTEST_SCALE=8` in 46.4 seconds.

### 16.4 Next map gate

The physical subway-kiosk answer is complete and no longer blocks map work.
Rare sound and a masked reflected-light suggestion, if pursued, require their
own authorship, privacy, visual and performance proofs; neither is needed to
make the exit credible. The next already-approved map/environment package is
T8, `ORISON_DRIVING_RAIN_SKY_PROPOSAL.md`. Do not reopen the three-zone world
or turn this shallow section into playable subway content.
