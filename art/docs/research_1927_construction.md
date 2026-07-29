# How Orison Apartments Would Really Have Been Built (Midwest, 1927)

Research notes grounding the procedural model in period construction
practice, and the mapping of each finding into `gen_layout.py` /
`build_orison.py`.

## The typology

Orison is a **courtyard apartment building** — the dominant middle-class
multifamily type of the 1890s–Depression Midwest: three to six stories of
brick bearing-wall construction organized around a central light court,
with a decorated street front and plain sides. Chicago alone had dozens of
brickyards feeding the type at its 1920s peak.

## Findings → implementation

| # | Period fact | Source basis | Applied as |
|---|---|---|---|
| 1 | **Two bricks, one building**: cheap local "common" brick wraps three-quarters of the structure; harder, evenly colored **face brick** covers the street facade only (sometimes wrapping the corner one bay). | Chicago common brick histories; courtyard-building surveys | South (street) facade uses `face_brick`; west/east/north walls, light court, parapet rear and chimney use `common_brick` with pinkish-buff irregular tone |
| 2 | **Bearing walls step with height** (empirical masonry rule, descended from 1920s codes): ~12 in for the upper ~55 ft, 16 in below. Outer face stays flush; the step is inside. | empirical masonry provisions (Technical Note 42 lineage; NYC admin code §27) | Exterior walls: 16 in (0.41 m) at basement + first floor, 14 in (0.35) floors 2–3, 12 in (0.30) floors 4–6; outer face flush at the property plane |
| 3 | **Limestone dressings**: sills, water table at the base, a belt course at the second-floor line, and coping on the parapet; window heads spanned by **soldier-course brick lintels**. | courtyard/two-flat detail surveys | Limestone window surrounds + projecting sills on all brick walls, water table at grade, street belt course at the F2 line, parapet coping, corbelled cornice band under the parapet |
| 4 | **Structure**: plaster-protected dimensional-lumber joists on masonry walls; interior partitions wood stud + lath and plaster (~4¾ in) — corridor walls often clay tile (~7 in). | ACSA courtyard-building study | Already matched (0.12 partitions / 0.18 corridor); basement gains the visible structure: brick piers + timber beam lines carrying the first floor |
| 5 | **Heat**: single coal-fired boiler, one-pipe steam risers, cast-iron radiators under windows. A coal boiler needs a **chimney** and a **coal bin with alley chute**. | steam-heat histories (ACHR News, Vital City) | Brick chimney stack (0.9 m square) rising from the boiler room through all floors past the parapet with a corbelled cap; coal bin room + pile beside the boiler; radiators/risers already modeled |
| 6 | **Second egress, Midwest-style**: since 1906 Chicago code required two exits; the rear **open wooden porch-and-stair stack** off the kitchens satisfied it and became the region's signature. Lumber was the cheap local material. | WBEZ / Fire Engineering porch histories; Moss Design courtyard essays | Rear wood porch stack on the north facade serving the B-stack kitchens: posts, decks with railings at each floor, steep straight runs between decks, kitchen door onto each deck |
| 7 | **Interior finish**: 9-ft ceilings, thick plaster, hardwood strip floors, painted wood trim, high baseboards. | pre-war finish surveys | 2.72 m ceilings already; baseboards (140 mm) now generated along every plaster wall; 1-over-1 double-hung reading via a meeting rail across each glazing pane |
| 8 | Windows: tall 1-over-1 double-hung, radiators tucked beneath. | pre-war surveys | 1.35 × 1.70 openings kept; meeting rail added; radiators under windows kept |

## Deliberate deviations (documented)

- The interior rear **service stair** remains (our building's residential-
  hotel origin story); the wooden porch stack is added alongside it rather
  than replacing it. Porch runs are steep period-accurate (~50°), so they
  are modeled physically but are not the player's intended route.
- Sealed 2D has no second egress — a violation Nadia Quell would flag,
  which is the point.
- Face brick wraps only the south facade, not a corner bay (blockout
  simplification).

## Sources

- [ACSA: The Chicago Courtyard Apartment Building](https://www.acsa-arch.org/proceedings/Annual%20Meeting%20Proceedings/ACSA.AM.98/ACSA.AM.98.60.pdf)
- [Chicago magazine: The Redemption Tale of Chicago Common Bricks](https://www.chicagomag.com/chicago-magazine/may-2026/the-redemption-tale-of-chicago-common-bricks/)
- [Block Club Chicago: Chicago's Unique Bricks](https://blockclubchicago.org/2019/11/19/chicagos-unique-bricks-once-hidden-from-view-and-shunned-now-front-and-center/)
- [Wikipedia: Chicago common brick](https://en.wikipedia.org/wiki/Chicago_common_brick)
- [Moss Design: Chicago Building Types — the Courtyard Apartment](https://moss-design.com/courtyard-apartment/)
- [WBEZ Curious City: Chicago's flammable "fire escapes"](https://www.wbez.org/shows/curious-city/chicagos-flammable-fire-escapes/b53874e6-1c66-42c6-b705-8fd9f2c482c0)
- [Fire Engineering: Chicago's Wooden Fire Escapes](https://www.fireengineering.com/fire-safety/focus-on-chicago-s-wooden-fire-escapes/)
- [Vital City: Why Your Pre-War Radiator Runs Hot](https://www.vitalcitynyc.org/radiator-steam-heat-history-nyc/)
- [ACHR News: The 1920s — Ushering In The Modern Age Of Heating](https://www.achrnews.com/articles/87034-the-1920s-ushering-in-the-modern-age-of-heating)
- [Mammoth: guide to pre-war apartments](https://www.mammothnewyork.com/blog/pre-war-apartments-nyc)
- [Empirical masonry thickness provisions (NYC Admin Code §27 / BIA TN42)](https://codelibrary.amlegal.com/codes/newyorkcity/latest/NYCadmin/0-0-0-55214)
