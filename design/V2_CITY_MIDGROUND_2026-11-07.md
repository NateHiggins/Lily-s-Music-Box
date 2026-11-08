# V2 mid ground: walkable streets out to the limit — November 7

Evidence class: **INERT**. Plan and build record for the mid-ground batch. It is not runtime acceptance,
whole-city qualification or Lily's artistic acceptance.

Lily's direction (2026-11-07): "Do another pass, consider what we need in the mid ground to make the streets
around the orison walkable with a fully realized environment." Lily's ruling **city_finish_owner** stands:
Claude authors in Blender, Canonical Codex keeps integration and qualification.

## Lily's rulings, 2026-11-07

- **barrier_distance:** she passes out 200 m from the front door, and no further. The mist gathers over the
  stretch before it, about 150–200 m, and she wakes in bed. "Reasons to explore, not a hike." The mist and the
  bed return are a separate build (work orders **w9bef4824daf3** and **w36b9de3d6db7**). They replace the
  invisible 450 m wall.
- **midground_street_ends:** street ends stay open. The mist is now their limit, so no street works are placed.
- **midground_street_names:** corner signs carry the 1929 Long Island City names around Queens Plaza,
  researched before they go in. They are lettered as Label3D only. This is reserved for the next batch.

These rulings change the job. **Inside 200 m**, the walkable work is filling the bare ground between the
installed near city and the horizon buildings with streets and frontage that have collision. **Beyond
200 m**, the same fabric continues out to the old ring as backdrop seen through the mist. It has no
collision there; a 15 m margin past the edge keeps the passing-out stretch solid underfoot.

## What the player could reach before

The only outer barrier is the invisible **TemporaryExteriorLimit**, a 450 m ring
(orison_v2_street_boundaries.gd). Inside it:

- **Real streets** (city_streets.glb, 366 parts with collision) reach about 150 m west and 207 m east of the
  building, along the main avenue and two short side districts.
- **Neighbour buildings:** 25 city shells within about 140 m, and 124 horizon buildings standing in three
  rings at 150–272 m. They are facades with collision and lit fake interiors, but most have no street in
  front of them.
- **Everything else is bare apron.** From the street ends, the canal and the rail cut, the lower half of
  every view is a dark plane out to the skyline. The player can walk it all the way to the ring and meet
  nothing.
- **No life:** four street lamps in all, no hydrants, mailboxes, signs or trees, no pedestrians, and no
  trams.

The street-end and canal frames in C:/ov/reports/city_finish_20261107/integration_native_01/views show it.

## What "fully realized" needs

1. **A street network to the edge.** Every direction a player can walk is a street: roadway, granite curb,
   sidewalk, crossings and gutters. The avenue grid continues the installed main avenue's bearing. Side
   streets are Belgian block, and the avenues are asphalt.
2. **Continuous block frontage.** Every street is walled by buildings whose ground floors face it:
   - shopfronts with glazing, a recessed door and an awning
   - stoops on the walkups, cellar doors and areaways
   - loading docks on the lofts and factories

   Backs and side walls are closed, and the gaps are alleys with board fences. Building masses carry
   cornices, parapets, fire escapes and roof clutter (water tanks, chimneys, bulkheads).
3. **An edge you believe.** By Lily's rulings this is the mist at 200 m, not a wall. The streets run on
   past it, so the city does not visibly stop.
4. **Street furniture,** placed by rule along every curb:
   - lamps lit from the existing dusk and dawn tables
   - hydrants and police and fire call boxes
   - mailboxes and trash barrels
   - telegraph poles with wires
   - street-name signs, lettered as Label3D only
5. **Life,** from the owners that already exist or are ordered:
   - parked vehicles and pushcarts, drawn from the period traffic stock
   - pedestrians (**K-V2-BACKGROUND-STICKFIGURES**)
   - trams on the boulevard side (**T-V2-TRAMS**, Codex's order)
   - laundry lines and pigeons
6. **Landmarks:** the elevated viaduct continued along its avenue from the installed station, and one bank
   tower accent at a plausible corner. Both are reserved for a later batch.
7. **Cost.** The frame is draw-call bound, so:
   - buildings are merged per block per material
   - furniture is MultiMesh
   - collision is simple boxes for buildings and trimesh only for ground
   - distant blocks fade by visibility range

## Ownership

Everything here is additive, the pattern PR 170 set: it composes new scenery and leaves the native
loaders bound. The installed streets, shells, horizon buildings, station, bulkhead, rail cut and Orison
building keep their owners and are not edited. New blocks are laid out around a collision survey of the
running world (tests/V2MidgroundOccupancyProbe.tscn), so nothing new overlaps an existing owner.
Generated glTF is never hand-edited.

## This batch

Items 1, 2 and 4: the street network, the block frontage and the static furniture. Collision stops at 215 m
from the front door. Item 3, the mist, is the separate build named above. Items 5 and 6
follow once the fabric exists for them to live in.

## What the survey showed

The collision survey of the running world (art/blender/data/city_midground_survey, plan.png) shows Lily's 200 m
circle sitting almost entirely inside the composed near city, the square inside the near horizon ring. New fabric
is kept out of that square (world x -178..178, z -190..166) because it is Codex's composition, routes and stations.
So the new streets and blocks are walkable only in thin slivers where the circle passes the square at the east and
west sides. Everywhere else they are the backdrop seen beyond the mist: the corridor between the near and far rings,
and the plane out to the old ring. Who fills the bare patches still left inside the near city is Lily's ruling
**midground_inside_200**.

First generation from the real survey: 93 street segments and 552 buildings, about 670k triangles and 16,800
window panes, with collision only inside 215 m.

## 1929 street names (research for ruling **midground_street_names**)

Research of 2026-11-07, read from published sources only; no archive image is a game asset. The rule it gives
is that in 1928–29 Long Island City had the numbered Queens grid officially, approved in 1925, while people still
used the old names. Signs carried the new name or number large, with the old name small underneath, for example
"40TH AVE" over "Payntar Ave". The Queens dating of that sign style is an inference.

- **The plaza.** The bridge plaza streets are **Queens Plaza North** and **Queens Plaza South**, the former North
  and South Jane Streets (LPC designation report LP-2570). "Queensboro Plaza" was the elevated station's name, and
  "Bridge Plaza" was older and informal.
- **North–south streets:**
  - 21st St / Van Alst Ave
  - 22nd St / Sunswick St
  - 23rd St / Ely Ave
  - 24th St / William St
  - 28th St / Radde St
  - 30th St / Academy St
- **East–west avenues:**
  - 38th Ave / Freeman Ave
  - 40th Ave / Payntar Ave
  - 42nd Rd / Henry St
  - 43rd Ave / Harris Ave
  - 44th Dr / Nott Ave
- **Kept names:** Jackson Ave, Thomson Ave, Queens Blvd, Court Square, Hunters Point Ave and Skillman Ave.
- **Disputed; not to be used until checked against the 1928 E. Belcher Hyde atlas:**
  - 41st Ave's old name (Wilbur Ave or Hunter Ave)
  - the date Jackson Ave became Northern Blvd east of the plaza
  - Court Square's change from Anable Ave
- **Sign form.** Most likely dark enamel with white serif capitals, two names stacked, on lamp posts. That is
  the documented Manhattan and Bronx form; for Queens it is unconfirmed. Lettering is Label3D only (RUL-008).

Sources: Powell, *American City* (Feb 1928), reprinted by Juniper Park Civic Association; Forgotten New York (the
Long Island City necrology, side streets and humpback-sign pages); LPC LP-2570; the 1930 census street-conversion
list (stevemorse.org).

**Open.** The mid-ground grid is a fictional layout, so giving its streets these names also fixes the Orison's
own avenue, which is an open canon question (the façade address). The mapping is ruling **midground_sign_mapping**.

## The el out of Queensboro Plaza (2026-11-08)

Lily's ruling **el_viaduct_route**: east only. The el leaves the station's east end and curves onto the cross
street away from the Orison, running out to the mist and keeping the horizon buildings.

The station's own east junction, at x 68.8, lies under the station. So the line uses the first cross street east
of the station, at x 142.9:
- The two middle upper tracks (world z −0.8 and 4.8, rail top 15.55) leave the station at x 104.
- They run east along the avenue, then curve north on a 30 m radius onto that street.
- They run up the street into the mist.

The survey found the corridor clear. The only nearby structure is a 13.2 m horizon block at z 138, about 199 m
out, and it sits under the deck.

The construction is plate girders, stringers, rails and ties on two-column bents at the station's 15 m pitch. The
columns collide only inside the walkable edge.

Batch 5 (`C:/ov/reports/city_midground_20261107/batch5`):
- compile, views (33 frames, including **el_curve**), spatial ownership and the horizon bench pass
- composition keeps main's same 78 failures

