# THE APPLIANCE BIBLE

*What is plugged in, in whose flat, and why it is theirs. The Orison is
a prewar block that electrified in stages, so its appliances are a
sediment: 1927 iceboxes that were never replaced, 1950s replacements
bought on credit, and a 1970s superintendent's parts bin holding it all
together. Nothing here is a modern box.*

*Grounded in `apartment_life_profiles.json` (kitchen_set, cleanliness,
maintenance, hero_object, contradiction) and the temperaments in
`resident_routines.gd`. Placement rule: an appliance earns its spot by
saying something true about the tenant that nothing else says.*

---

## I. THE PERIOD REFERENCE

Real products the generic designs derive from — shape language only, no
badges, no trademarks.

| Archetype | Real reference | The silhouette that matters |
|---|---|---|
| **Monitor-top fridge** | GE Monitor Top, 1927–36 | Steel drum compressor sitting proud on a rounded cabinet, cabinet on slim splayed legs, single latching door with a long chrome handle. Reads as furniture, not a box. ([design history](http://www.industrialdesignhistory.com/node/148)) |
| **Sheer-look fridge** | Frigidaire / Kelvinator, mid-1950s | Full rounded shoulders, one continuous door face, vertical chrome pull, plinth to the floor, badge at chest height. |
| **Enamel range** | Chambers / Roper, 1930s–40s | Porcelain enamel body, four burners on a raised deck, **oven door about 45 cm tall on a 90 cm body**, towel rail across the door, clock in the backsplash, knob row on the apron. |
| **Wringer washer** | Maytag, 1930s–50s | Cylindrical tub on four legs, wringer arm over the rim, single agitator dome. |
| **Console radio** | Zenith / Philco, 1930s | Bakelite or veneer cabinet, cloth grille, illuminated dial glass, chrome pointer. |
| **Toaster** | Chrome pop-up, 1940s | Mirror-chrome curved body, bakelite ends, single lever. |

**The oven-door bug**: the current `asm_stove` draws its door from 0.30
to 0.72 m — 42 cm on an 80 cm body, which is right — but the broiler
drawer beneath (0.115–0.275) and the door read as one continuous face
from the front, so the oven appears roughly twice its height. The fix
is separation, not shrinking: a visible 3 cm reveal between drawer and
door, and the door's towel rail moved to its true top edge.

---

## II. THE MASTER LIST

Interactive appliances that make sense in this building. `[E]` names the
interaction; **possession** names what the poltergeist does with it.

### Kitchen

| Appliance | Units | `[E]` | Possessed |
|---|---|---|---|
| **Enamel range** | every kitchen | Oven door drops open, one burner ticks and blooms | All four burners light at once, dials spin against their stops |
| **Monitor-top fridge** | 1A, 3A, 5B, 6C (never replaced) | Door swings, interior lamp, compressor sighs | Door beats open and shut on the motif, contents rearrange between glimpses |
| **Sheer-look fridge** | 1D, 2A, 2B, 4A, 4B, 5A | as above | as above |
| **Kettle** | 1A, 3D, 4B, 6C | Lifts, sets down, whistles when hot | Boils dry and whistles a held note |
| **Chrome toaster** | 4B, 4A, 6B | Lever down, elements glow, pops | Ejects nothing, repeatedly |
| **Icebox (dead)** | 4D, 4C-Noel side | Door opens on a dry, ringing cavity | Drips water that is not there |

### Utility and comfort

| Appliance | Units | `[E]` | Possessed |
|---|---|---|---|
| **Cast iron radiator** | all | Valve turns, knock travels the riser | Hammers the motif through the whole stack |
| **Console radio** | 5B (three), 2C, 6B | Dial sweeps, stations bleed | Tunes itself to WORS 1610 |
| **Box fan** | 2C, 5C, 6A | Speed steps 0-1-2-3 | Runs unplugged |
| **Wringer washer** | B1 laundry (four) | Agitator starts, tub sloshes | Wrings on empty, arm swinging |
| **Sewing machine** | 2B | Treadle turns, needle drops | Stitches a seam with no cloth |
| **Reel-to-reel deck** | 2C, 5B | Reels spool, playback | Plays take 18 (web §II.7) |

---

## III. PER-APARTMENT, FROM HOW THEY LIVE

*One line of appliance evidence per tenant, argued from their profile.*

| Unit | Tenant | The appliance that tells the truth about them |
|---|---|---|
| 1A | Evelyn | Monitor-top kept immaculate at 0.92 clean; a **second teacup** beside the kettle, never used. Her contradiction, in porcelain. |
| 1D | Teresa | Range cold, thermos on the counter, fridge full of leftovers in labelled tins. The **silenced alarm clock** sits on the fridge top where she can't hear it from bed. |
| 2A | Mina | Everything labelled — including the fridge shelves, in her own hand. One box conspicuously unlabelled. |
| 2B | Lena | The biggest pots in the building, for people who don't live here. Sewing machine in the front room, oiled and true (maint 0.90). |
| 2C | Juno | Range unused as a range; **used as a shelf** for tape boxes. Takeout cartons, one percolator, and the recording rig where a table should be. |
| 3A | Malcolm | Jars, not tins. Compost pail under the sink. The **empty memorial pot** on the windowsill above it, holding soil and nothing. |
| 3B | Omar | Two of every appliance: one working, one **half torn down** on newspaper — his sacrificial teardown, the thing he keeps not declaring unrepairable. |
| 3D | Rhea | Kettle, honey, lemon. The range is spotless because it is never used. |
| 4A | Peter | Identical weekday meals means identical tins in identical rows, and a toaster with a **form taped to it** about a replacement he never filed. |
| 4B | the player | Kettle and toaster on a counter otherwise bare. The desk is the tidiest thing in the flat. |
| 4C | Cam / Noel | **The negotiated dining table**: Cam's fridge side is quick food, Noel's is a museum shelf with a dead icebox nobody empties. One kitchen, two centuries. |
| 4D | Guests | Inadequate cookware — one pan for everything, hotel-issue, and a fridge that was never turned on. |
| 5A | Nadia | Batch cooking, efficient, and a **corrected floor plan of this building** magneted to the fridge door. |
| 5B | Cal | Forgets to eat: the range is a stand for **three console radios**. Fridge holds batteries and film. The reel deck is the only thing warm. |
| 5C | Iris | Meals between coats — the kitchen surfaces carry paint, the fridge handle is thumbed with it, one burner is a **brush-drying rack**. |
| 6A | Sacha | Eats standing. The kitchen counter is a **contact-sheet light table**; the fridge hums against a wall of prints. |
| 6B | Jonah | Cold drinks and rings: every horizontal surface carries a ghost ring, and the wastebasket by the fridge is full of paper. |
| 6C | Mae | Careful and spare, 0.90 clean. Everything period-correct and **nothing after 1935** — she has never replaced a thing, which is its own kind of certainty. |

---

## IV. TEXTURE IDENTITY PROMPTS (planned)

Per-appliance wear, slot format (see `MATERIAL_PROMPT_SHEET.md`). Each
is the same enamel, aged by a different life:

- `enamel_pristine.png` — Mae and Evelyn: "aged white porcelain enamel,
  meticulously kept, fine crazing but no chips, faint polish swirl"
  (anchor `#F2EEE2`)
- `enamel_paintflecked.png` — Iris: "white enamel with scattered dried
  oil-paint flecks in ochre, viridian and lead white, thumbprints of
  colour at the handle zone" (anchor `#E9E3D2`)
- `enamel_dented.png` — Cam: "white enamel with shallow dents, chipped
  edges showing dark steel and rust halos, courier-bag scuffs"
  (anchor `#E4DDCC`)
- `enamel_greasy.png` — Juno and Jonah: "white enamel gone amber with
  cooking film, fingerprints, a tide line of grime at the handle"
  (anchor `#DCD2B8`)
- `enamel_workshop.png` — Omar: "white enamel with masking-tape
  residue, marker numbering, one panel replaced in mismatched paint"
  (anchor `#E6E1D4`)

---

## V. BUILD NOTES

- Curved bodies come from `F.lathe` (revolved profile), not stacked
  `F.box`. The Monitor Top's drum is a lathe; the sheer-look shoulder
  is a lathe cap over a box body.
- Interaction and possession live in the Godot props
  (`fridge_prop.gd` etc., `FunctionalProp` base), with the poltergeist
  vocabulary in `poltergeist_library.gd`.
- Assembly geometry lives in `build_orison.py` (`ASM`), placement in
  `gen_layout.py`.
- **Law**: an appliance may only be unique where its uniqueness tells
  the tenant's story. Everything else is the same enamel range, because
  a landlord bought forty of them at once.
