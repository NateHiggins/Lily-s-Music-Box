# The Vantry gateway — arcade entrance, subway language, and actual transit

*Proposed 2026-08-14. This is a tiered design proposal, not a ruling and not
permission to reopen the approved map. The final world remains ORISON, STREET
and PASSAGE; the Passage remains the Vantry Arcade in fiction. No production
geometry changes in this document.*

---

## 1. The finding

The gateway is genuinely jarring in
`art/renders/map_final_acceptance/01_street_portal.png`.

The problem is not that the entrance is dark. It is that it does not yet read
as a place with a building around it:

- the current STREET proxy is only a limestone head, thin glazing, iron jambs
  and two lamps on the exact portal plane;
- the 6.44 m head appears as a floating black rectangle, with open skyline
  above and visible distance behind the glass;
- nothing gives the opening side walls, depth, a roof mass, a recessed landing,
  a name or a reason to exist at this address;
- the two large white lamp globes become the strongest forms in the elevation;
- after the player crosses the plane, the view cuts immediately to a flat,
  straight 10.284 m brick throat and then the glass hall.

That is why it reads as a pasted portal or a black billboard rather than the
front door of the Vantry Arcade. Fog will soften it, but fog cannot supply the
missing architecture. This must still read correctly with weather disabled.

The current source confirms the visual diagnosis. `_passage_shell()` in
`art/data/gen_layout.py` gives the STREET proxy only 35–125 mm of depth around
`BLDG_S = -28.316`; the real throat is PASSAGE-owned and hidden from the
street. The proxy therefore has nothing substantial behind it when STREET owns
the frame.

---

## 2. What is already fixed

This proposal does **not** reopen the M0.5 spatial ruling:

- exactly three zones: ORISON, STREET and PASSAGE;
- portal `x 11.000..17.000` on `y -28.316`, centre `x 14.000`;
- throat `x 11.000..17.000`, `y -28.316..-38.600`, length 10.284 m;
- hall `x 4.000..24.000`, `y -38.600..-64.600`, 20 × 26 m;
- all eleven shops remain in the Vantry Arcade;
- the exact ownership plane remains STREET at Godot `z = 28.316` and PASSAGE
  immediately beyond `z = 28.317`;
- the outbound and loaded return journeys remain continuous and reversible;
- residents, the player and eventually carried goods must fit the route;
- visible architecture owns containment. No new unexplained invisible wall;
- the accepted canonical-night performance blocker may not be made worse by
  decorative submissions or new real-time lights.

The original Passage brief also makes a transition cut binding in spirit:
“You walk in. Nothing fades.” The physical route, visibility gate and M1 golden
loop now prove that promise in code. A subway cutscene here would be a change
to the game's topology and loop, not a cosmetic way of hiding the entrance.

---

## 3. Recommendation — use subway *language*, not a subway journey

Build the entrance as a **Vantry Arcade stair-house / concourse pavilion**:
a period transit-like piece of civic-commercial architecture that marks a
descent into the block, without claiming that a train carries the player ten
metres from the street to the hall.

The strongest version has three layers.

### 3.1 Give the portal a host building

Use the unplayable residual strips around the fixed throat — approximately the
west strip between the Harukiya's east edge at `x 6.4` and the portal at
`x 11`, and the east strip from `x 17` to the approved stage edge at `x 20.6`
— to form one shallow two-storey masonry frontage. The opening then belongs to
a facade instead of floating between unrelated masses.

The facade should have:

- brick or buff terracotta piers tied into the neighbouring party-wall line;
- a real cornice/parapet above the existing 4.38 m portal head, closing the
  skyline gap;
- a recessed entrance plane 1.2–1.8 m behind the street face;
- a modest iron-and-glass or greened-copper rain hood projecting over the
  pavement;
- a mosaic or enamelled lintel reading **VANTRY ARCADE**, with **SHOPS / MARKET
  HALL** as the subordinate promise;
- smaller, shielded entrance globes. Reuse or replace the existing two portal
  fixtures; add no lighting slot merely for decoration;
- gutters, a chain or downpipe, wet splash marks and a drain so the driving
  rain belongs to the architecture rather than passing through it.

The facade mass is the main fix. It removes the billboard silhouette and the
open sky above the gate before any fiction is added.

### 3.2 Give STREET an honest shallow vestibule

Extend the STREET-owned visual proxy roughly 1.8–2.4 m into the throat with a
bounded, low-cost vestibule: tiled returns, stained plaster ceiling, threshold,
an opaque map or notice board, and one strong piece of ironwork. It remains
visible on both sides of the ownership plane, so the street frame never looks
through empty proxy glass into distant skyline and the first Passage frame does
not abruptly conjure an entire corridor.

Place a narrow tiled information pier on the `x = 14` sightline just beyond the
doors. A pier about 0.8–1.0 m wide leaves two routes of roughly 2.5 m each in
the six-metre throat: more than enough for the player and a carried crate, but
enough to break the rifle-shot view from roadway to hall. It should advertise
the shops, carry hours and old notices, and make the reveal happen around an
object rather than at a render toggle.

This changes the local walk from a straight line to a choice around a pier, but
does not move the portal, throat, expansion or hall. The route tests must follow
the real path rather than delete the pier to preserve the old `x = 14` probe.

### 3.3 Let the throat perform the transition

Keep the floor continuous. Use architecture and sound to imply descent:

- the entry ceiling compresses, then the glass vault rises at the expansion;
- glazed tile or a dark dado climbs the brick walls toward the hall;
- the street rain becomes canopy hammer, drain chatter, then a filtered hiss;
- traffic loses its high frequencies over the 10.284 m throat;
- warm arcade sound and shop voices arrive before the hall is fully visible;
- a shallow floor border or terrazzo pattern can point down-slope without
  moving the hall vertically.

This is transit architecture as a visual and acoustic vocabulary. It solves
the ugly gate while preserving the thing the Passage was built to do: make an
ordinary shopping errand one uninterrupted trip out and back.

Historical cues are available without copying a single station. The 1905
[subway entrance and exit kiosks](https://www.loc.gov/item/2016804671/), the
1910–20 [Atlantic Avenue entrance](https://www.loc.gov/item/2016815535/), the
1909 [Queensboro Bridge underground trolley kiosk](https://www.loc.gov/pictures/item/ny0942/)
and the Landmarks Commission's [72nd Street control-house record](https://s-media.nyc.gov/agencies/lpc/lp/1021.pdf)
support the period vocabulary: cast iron, glazed or tiled surfaces, masonry
control houses, strong name panels and a small civic object planted in a busy
street. The Vantry version should remain commercial and slightly overpromoted,
not become a replica IRT station.

---

## 4. The tiers

| tier | proposal | gameplay value | production consequence | ruling |
|---|---|---|---|---|
| **0 — Facade correction** | Host mass, parapet, recessed entry, named lintel, canopy and a backed vestibule. Straight route remains. | The gate becomes legible; rain has something to strike. | Low. Mostly generated static records; target a few merged material draws and no new light. | Safe fallback, but leaves the abrupt straight throat. |
| **1 — Concourse reveal** | Tier 0 plus the STREET-owned shallow vestibule, central information pier, split walk and acoustic handoff. Uses subway/stair-house language without promising trains. | Makes entering an authored beat; preserves walking, carrying, residents and immediate return. | Moderate. Local collision/nav/test updates and portal-transition renders; no map-envelope change. | **Recommended.** Best ratio of story, image and system integrity. |
| **2 — Real sunken arcade** | Lower the Passage floor roughly one storey and fit a genuine stair within the existing 10.284 m throat; the Vantry hall is a sunken market concourse, not a ride. | Uphill return while carrying goods is real gameplay; descent materially separates weather from hall. | High. Every Passage z, floor cut, shop door, light, collision, route, camera, SafetyNet and ownership height must be rebuilt and re-proven. The current glass vault must become a believable lightwell/skylight. | Consider only if stairs are meant to be a recurring mechanic, not a view fix. |
| **3 — Subway cutscene** | Descend at STREET, show a short train montage, emerge at a second entrance beside the hall. | Time passage and travel mood, but no play during the ride. | Very high in continuity: carried objects, NPC schedules, save state, traffic state and return position cross a teleport. Repeated shop errands acquire two compulsory cutscenes. | **Reject for this gate.** It contradicts adjacency and “nothing fades” to move the player a distance already represented by a ten-metre throat. |
| **4 — Modeled subway** | Concourse, platforms, track, train, operations and one or more destinations. | Potentially a new social venue, transport network and story machine. | Project-scale: a fourth playable environment, streaming/ownership, schedules, train logic, safety, audio, characters, animation and destination content. | **Not worth it under the approved three-zone world.** Revisit only for a real expansion. |

---

## 5. Would modeling the subway ever be worth it?

Not to conceal this gateway. A full subway earns its cost only if the player
uses transit for recurring verbs that cannot be delivered by the existing
street and Passage. Require all of the following before reopening the idea:

1. at least one genuine destination outside the approved three-zone map;
2. at least three repeatable uses across cases — for example commuting with a
   resident, transporting an awkward object, and a time-sensitive encounter;
3. a reason for the player to wait, board, ride and arrive rather than select a
   destination from a menu;
4. a persistence contract for carried objects, companions, schedules and time;
5. a measured streaming/performance plan that never submits the station with
   the Passage hall.

If those conditions appear later, the subway belongs at a world boundary or
future chapter exit. A six-to-ten-second ride montage could then be a legitimate
loading and time-passage device. It still should not replace the present
STREET-to-PASSAGE walk.

There is one smaller lore option: make the Vantry pavilion resemble an entrance
built in anticipation of a transit connection that never arrived. A sealed
**TO TRAINS** mosaic or bricked service arch would perfectly echo “built for a
future that did not arrive.” It is also a conspicuous promise to the player, so
it needs an owner ruling and eventual narrative acknowledgement. Do not smuggle
it in as set dressing.

---

## 6. Implementation sequence for the recommended tier

### Gate A — prove the diagnosis cheaply

Make one blockout replacing the current flat proxy with:

- flanking host masses and parapet;
- 1.5 m recess and rain hood;
- one opaque vestibule backstop;
- a central sightline pier.

Render the existing `01_street_portal` camera with weather disabled and with
the canonical driving-rain proposal enabled. The architecture must solve the
first frame; weather may improve it but may not be the only thing hiding it.

### Gate B — choose the fiction from images

Present three treatments on the same blockout:

1. **commercial arcade:** limestone/brick, VANTRY ARCADE, no transit reference;
2. **civic stair-house:** iron, glazed tile and globe vocabulary, still labelled
   only VANTRY ARCADE;
3. **aborted connection:** the civic version with one sealed transit remnant.

Only treatment 3 changes lore. No subway code or train asset is needed for any
of the three.

### Gate C — production and proof

After a treatment is selected:

- keep the exact portal plane and all M0.5 envelopes;
- assign the shallow facade/vestibule to the existing STREET proxy ownership;
- keep deeper throat, shell, shop and actors PASSAGE-owned;
- merge static pieces by the smallest existing material families; do not add
  a forest of individual trim submissions;
- add no new real-time light. Re-author the two existing portal fixtures if the
  new elevation needs a different light read;
- update `FinalMapRouteTest` to walk around the real pier in both directions;
- keep `PassageNavTest`, `PassageVisibilityTest`,
  `PassageOwnershipAudit`, `StreetContainmentTest` and WalkTest FULL green;
- add a focused gateway test proving a player capsule and a carried-width proxy
  have a continuous route on both sides of the pier;
- take transition renders immediately before, at and after `z 28.316`, plus
  street portal, throat reveal and return-facing-street shots;
- repeat the canonical-night performance stations. Any worsening beyond the
  repeat-run noise floor fails, because northbound already carries an accepted
  approximately 1.2 ms blocker;
- verify the final facade at morning, day, evening and night under the weather
  system, but also in a dry/debug control.

---

## 7. Owner decision requested

Choose a tier and, if Tier 0 or 1, choose one of the three facade treatments in
Gate B.

**Recommendation: Tier 1, civic stair-house treatment, no operational subway
and no `TO TRAINS` sign.** It gets the visual thrill of a period station
entrance, makes the Vantry Arcade feel like a deliberately buried piece of the
city, gives the rain and soundscape a memorable threshold, and preserves every
approved spatial and gameplay decision. If that render still feels too level,
Tier 2 is the honest way to add stairs; a train cutscene is not.
