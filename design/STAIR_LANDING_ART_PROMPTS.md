# STAIR LANDING ART — seven half-landings, seven prompts

*The dog-leg stair turns seven times between the cellar and the roof, and
every half-landing is a wall nobody has claimed. P1 #5 asks for a unique
piece on each. These are not decoration: a stair landing is where a
building hangs the things it wants everyone to walk past, so each piece
carries a thread from `ORISON_RELATIONSHIP_WEB.md` without explaining
it. A player who never reads one loses nothing; a player who reads all
seven has the Price conviction before anyone says the name.*

## Delivery

One **contact sheet, 2048×2048, a 3×3 grid** (seven used, two blank) —
same workflow as the material sheets. Save as
`art/textures/ai_sources/stair_landing_art.png`. Cell order is reading
order: row 0 = pieces 1–3, row 1 = 4–6, row 2 = piece 7 then two blanks.
Single images are fine too, named `landing_1.png` … `landing_7.png`.

**Format, every piece:** the artwork ONLY, filling its cell edge to edge
— no frame, no wall around it, no perspective. These land on unit-mapped
quads, so the cell IS the picture. Flat-on, even diffuse light, no cast
shadows, no glass glare. A century of fading, foxing and damp is *in*
the artwork; the frame and the cracked glass are geometry, not texture.

---

## 1 — cellar to first: the station that had no transmitter

```
Aged paper radio station card for a small local station, 1962, printed in two colors on cream card: large call letters "WORS 1610" at the top, a weekly programme grid below in small dense type, a decorative sunburst device. Water-damaged along the bottom edge with a brown tide line, foxed with age spots, one corner torn away, thumbtack holes at the top corners. Flat artwork only, filling the frame edge to edge, no picture frame, no wall, no perspective, even diffuse lighting, no glare, no cast shadows. Square 1:1, high resolution.
```

## 2 — first to second: signed "Management"

```
Aged typewritten tenants' notice on yellowed foolscap, 1928, headed "NOTICE TO OCCUPANTS" in bold capitals, below it a numbered list of house rules in uneven typewriter type with a few characters struck over, and at the foot a hand-signed line reading only "Management". Rust rings from two paperclips, a coffee ring across one corner, edges browned and brittle. Flat artwork only, filling the frame edge to edge, no picture frame, no wall, no perspective, even diffuse lighting, no glare, no cast shadows. Square 1:1, high resolution.
```

## 3 — second to third: the doors were locked from the outside

```
Aged memorial handbill for garment workers, 1911, letterpress on grey stock: a black-bordered rectangle, a small engraving of a nine-storey factory building, and dense small type listing names, most of them illegible with age. Heavily foxed, one horizontal fold worn nearly through, damp staining in the lower left. Flat artwork only, filling the frame edge to edge, no picture frame, no wall, no perspective, even diffuse lighting, no glare, no cast shadows. Square 1:1, high resolution.
```

## 4 — third to fourth: a cutting kept alive

```
Aged horticultural society exhibition print, 1920s, a hand-coloured botanical plate of a pelargonium in flower with its root ball exposed, latin name in copperplate script beneath, a small society seal in the corner. Paper toned to warm ivory, colours softened, a water bloom across the lower third, pin holes top and bottom. Flat artwork only, filling the frame edge to edge, no picture frame, no wall, no perspective, even diffuse lighting, no glare, no cast shadows. Square 1:1, high resolution.
```

## 5 — fourth to fifth: the record shows a pause

```
Aged formal group photograph, sepia, 1950s: eleven court stenographers standing in two rows behind their machines in a panelled courtroom, all looking at the camera, faces small and slightly soft. A printed caption strip along the bottom in small serif type, half of it lost to a water stain. One face in the back row is obscured by a bloom of damp. Flat artwork only, filling the frame edge to edge, no picture frame, no wall, no perspective, even diffuse lighting, no glare, no cast shadows. Square 1:1, high resolution.
```

## 6 — fifth to sixth: preserved by preventing an ending

```
Aged black and white club photograph, 1930s: seven men and one woman seated around a table crowded with valve radio chassis, coils and test meters, a banner behind them reading "RADIO COLLECTORS ASSOCIATION" in painted letters. Silver-gelatin print gone slightly bronze, corners bumped, a vertical crease left of centre, one figure at the edge cut off by the print's own trim. Flat artwork only, filling the frame edge to edge, no picture frame, no wall, no perspective, even diffuse lighting, no glare, no cast shadows. Square 1:1, high resolution.
```

## 7 — sixth to roof: the building photographing itself

```
Aged black and white architectural photograph taken at night, 1930s: the glazed roof monitor of an apartment building seen from the roof deck, its panes lit from within, chimney pots and a water tank behind it, city haze beyond. Long-exposure grain, deep blacks, halation around the lit glass. Print surface scratched, one corner foxed, a thumbprint developed into the emulsion at the edge. Flat artwork only, filling the frame edge to edge, no picture frame, no wall, no perspective, even diffuse lighting, no glare, no cast shadows. Square 1:1, high resolution.
```

---

## What each thread is (for the record, not for the wall)

| # | Landing | Thread |
|---|---|---|
| 1 | B1↔F01 | WORS 1610 broadcast from the laundry, 1962–99; Cal is the transmitter |
| 2 | F01↔F02 | The Kessler Estate's house rules; Nadia signs herself "Management" |
| 3 | F02↔F03 | Triangle Shirtwaist, 1911; Lena's layer, and locked doors |
| 4 | F03↔F04 | Malcolm's cutting, taken the morning of an unfinished goodbye |
| 5 | F04↔F05 | Court reporters; Mina's four seconds and Peter's dead appeal |
| 6 | F05↔F06 | Cal's collection; presence is not preservation |
| 7 | F06↔ROOF | Sacha documenting the building; experience can precede proof |

**Law:** none of these captions appear in game. The art is evidence, not
exposition (bible law 7 — the world explains itself diegetically or not
at all).

---

## Placement note (read before wiring)

The existing hallway-art spawner (`building_root._spawn_hallway_art`)
hangs a piece by naming a ROOM, and half-landings are not rooms — they
live in the layout's top-level `stairs` list as `{"kind": "landing"}`
parts with a z, not as room rectangles. So these seven need either a
landing room per turn or a small dedicated spawner that reads the stair
parts and hangs on the known half-flight wall (the x = ±2.31 line).

That work is deliberately left until the art exists: the wall a piece
lands on has to be judged by eye at the landing, and inventing the
placement blind is how the wall-art family got misplaced the first time.
Once `stair_landing_art.png` is in `ai_sources/`, wiring is one pass:
slice to a 3×3 atlas, add seven catalog rows, spawn against the stair
parts, then verify with FreeCam at each landing.
