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
