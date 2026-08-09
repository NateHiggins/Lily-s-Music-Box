# THE ELEVEN SHOPS — INTERIOR BUILD GUIDE

Research and build instructions for the eleven shop interiors on the
Orison's block. Companion to `PROP_ART_BRIEF.md` (which governs prop
modelling generally) and `ORISON_BIBLE.md` §VIII (which governs what may
exist at all).

The shells are built and walkable: floor, ceiling, party walls, a door
hinged at the jamb, a lighting run and a first pass of fittings. **This
document is the second pass** — what each trade actually was in 1927
New York, the one object that makes each shop legible from the doorway,
and the specific thing that makes it worth walking into twice.

---

## I. THE SHELLS YOU ARE FURNISHING

Every dimension below is what is already generated. Build to these, not
to a guess.

| Shop | Trade | Width | Depth | Area | Cabinets | Front |
|---|---|---:|---:|---:|---:|---|
| MODEL LAUNDRY | laundry | 5.40 | 7.00 | 37.8 | 1 | awning |
| SHOE REBUILDING | cobbler | 5.40 | 6.00 | 32.4 | — | blade |
| KEYS CUT | locksmith | 3.40 | 5.00 | 17.0 | — | blade |
| RADIO SERVICE | radio | 3.00 | 5.00 | 15.0 | 1 | awning |
| LUNCHEONETTE | diner | 5.00 | 7.00 | 35.0 | 2 | awning |
| NEWS & CIGARS | news | 2.10 | 4.00 | 8.4 | 1 | blade |
| PAWNBROKER | pawn | 4.40 | 6.00 | 26.4 | 1 | blade |
| FUNERAL PARLOUR | funeral | 4.40 | 7.00 | 30.8 | — | awning |
| HARDWARE & PAINT | hardware | 5.20 | 6.50 | 33.8 | — | blade |
| PHOTO SUPPLIES | photo | 5.00 | 6.00 | 30.0 | 1 | awning |
| OTIS & SON | druggist | 4.10 | 7.00 | 28.7 | — | awning |

Shared: **3.30 m clear height** with the slab above to 3.55. Floor
finish at 0.01, flush with the pavement. Party walls are raw brick, so
any plaster or panelling is something the trade added. Doors are 0.95
wide, hinged at the jamb; the four trades that keep the light on
(laundry, diner, news, plus the druggist's awning) have theirs open.

**NEWS & CIGARS IS 8.4 m².** It is not a small shop, it is a *booth*.
Do not attempt a room in it. See §IV.6.

---

## II. THE SHARED LAW OF A 1927 SHOP

Six things are true of nearly every shop on this street, and getting
them right does more than any amount of detail.

**1. THE COUNTER IS THE BUILDING'S MOST IMPORTANT LINE.** A shop of this
period is divided, absolutely, into *customer side* and *trade side*,
and the counter is the border. Self-service is brand new in 1927 (Piggly
Wiggly is 1916 and still a curiosity in the east) — in every shop here
except the hardware store, **the customer touches nothing and asks for
everything**. Build the counter first and let the plan follow from which
side of it the player is standing on.

**2. GOODS ARE BEHIND, ABOVE AND UNDER.** Because the customer cannot
reach, stock goes on the back wall from waist to ceiling and is fetched
with a stepladder or a grabber pole. The high shelf is real and should
be full. Under the counter is drawers and the ledger.

**3. EVERY SHOP HAS A LEDGER.** Credit was how a working street ate.
A bound book, on the counter or under it, with a pencil on a string.
In a building whose whole horror is *being recorded*, eleven shopkeepers
each keeping a written account of everyone's private business is not a
neutral detail. **Put one in every shop.** It costs four primitives.

**4. THE BACK IS NOT MODELLED, BUT THE DOOR TO IT IS.** Every trade has
a back-of-house — stockroom, yard, the stair to the flat above. Model a
closed door or a curtained opening in the back wall. It does two jobs:
it says the shop has depth it is not showing, and it gives the eye
somewhere to stop that is not a flat plane.

**5. LIGHT COMES FROM THE FRONT AND HANGS LOW.** A shop this deep is lit
by its window and by pendants on flex, hung at about 2.4 m — low enough
to be a thing in the room. The generated run gives you one every 2.4 m
already. Anything you add should be a *task* light: a shaded bulb on the
bench, a lamp in the window, a bracket over the till.

**6. THE WINDOW DISPLAY IS THE SHOP'S ARGUMENT.** It faces out, so the
player sees it from the pavement before ever entering, and it is where
the trade puts its most explicable object. Model it as a raised platform
behind the glass, 0.30–0.45 above the stall riser, with a backboard so
the shop's interior is not the window's background.

---

## III. THE RULES THAT WILL BITE

- **NO LETTERS, NUMBERS OR WORDS IN ANY GENERATED TEXTURE.** This is the
  most-broken rule in the project and these eleven shops are the most
  tempting place to break it: every one of them is historically covered
  in printing. Signage and labels get **Label3D**, exactly as
  `shop_sign_prop.gd` does for the fascias. Everything else stays
  illegible — a label is a coloured rectangle at this distance and
  should be modelled as one.
- **THE PLAYER IS 1.41 m AT THE EYE.** Counters at 0.90–1.05, high
  shelves readable to about 2.1, anything above that is texture. A
  display case whose contents sit below 1.0 shows the player its top,
  not its goods.
- **MESH BUDGET.** Every prop family now carries a WalkTest assertion
  and the frame is CPU-bound on draw calls (#28). Shop fittings are
  `fb` boxes in the site pass, so they merge into the floor buffers and
  are cheap — **keep them as furniture boxes, not as props**, unless
  the thing genuinely moves or is interacted with. A shop with sixty
  boxes costs nothing; a shop with sixty FunctionalProps costs the
  frame.
- **THE RULE OF SIGNAL APPLIES PER SHOP, NOT PER STREET.** Ten of these
  trades are 1927 and second-hand. One — the radio service — is forty
  years ahead on its bench and nowhere else. Getting that contrast right
  is most of the street's character.

---

## IV. THE ELEVEN

Each entry: **what it was** · **the hero object** (the one thing that
makes the shop legible from the doorway — build this first and build it
well) · **fittings** · **the flair** (what makes it worth a second
visit) · **do not**.

---

### 1. MODEL LAUNDRY — hand laundry · 5.40 × 7.00

**What it was.** In 1927 New York there were roughly three and a half
thousand hand laundries, the overwhelming majority Chinese-run, and they
were the neighbourhood's laundry. Not a coin wash — a counter, a ticket,
and three days. Shirts done by hand, starched, and ironed on a long
padded table with irons heated on a stove.

**Hero object: THE TICKET RAIL AND THE PARCEL WALL.** Behind the
counter, floor to ceiling, brown-paper parcels tied with string, each
with a paper ticket under the string. Hundreds. And a wire strung across
the shop at head height, hung with the torn halves of tickets for work
finished but never collected.

**Fittings.** Counter with a hinged lift-up flap at one end (the only
way through). Long ironing table, 2.4 × 0.75, padded and scorched, along
one wall. Cast-iron sad irons on a small gas ring, several, so one heats
while one works. A sleeve board. A hand-cranked mangle. Wooden drying
racks on a pulley to the ceiling. Washtubs at the back under a tap.
A stove. A shirt rail with finished work on wooden hangers, sleeved in
paper.

**The flair.** *The unclaimed parcels are dated.* Some of the tickets on
that wire are years old. A laundry keeps a parcel for a long time before
it accepts that nobody is coming, and this one has accepted nothing.
In a building about people who cannot leave, a wall of other people's
clothes waiting to be collected is free.

**Do not** put a machine in it. There is no washing machine and no
tumble dryer here — that is the *building's* basement, and even there
the dryer had to be removed as impossible. This is hands, water, a
mangle and heat.

---

### 2. SHOE REBUILDING — cobbler · 5.40 × 6.00

**What it was.** Not a cobbler in the craft sense — a **repair shop**,
and by 1927 a mechanised one. Half the floor is one machine.

**Hero object: THE FINISHING MACHINE.** A cast-iron powered stand about
1.2 m long and chest high, carrying a line of brushes, sanding drums and
buffing wheels on a common shaft, with a big sheet-metal dust hood and
an exposed belt to a motor below. It is loud, it is filthy, and it is
the reason the whole street smells of this shop.

**Fittings.** A curved-needle outsole stitcher (Landis or McKay) on its
own stand. A Singer 29K patcher — a small treadle machine with a rotating
presser foot, for uppers. A bench with lasts: a cast-iron stand with the
iron feet on it, and a rack of more, in sizes, like a bone collection.
Racks of customers' shoes in pairs, each tied together with a paper tag.
A shelf of leather soles, stacked. Bins of heel lifts and nails. Cans of
dye and polish. A low seat with a footrest for a customer waiting.

**The flair.** *Ground leather dust over everything.* The finisher
throws a fine black felt that settles on every horizontal surface, and
the only clean shapes in the room are where things have been picked up
recently. Model it as a darkening on upper surfaces and a clean rectangle
where the ledger sits.

**Do not** make it tidy. This is the dirtiest interior on the street and
should read that way from the pavement.

---

### 3. KEYS CUT — locksmith · 3.40 × 5.00

**What it was.** A narrow shop, mostly a workbench, with the window
display doing the advertising. Locksmiths of the period cut keys,
repaired mortise locks, opened safes, and — this matters — **kept
records**.

**Hero object: THE KEY BOARD.** The back wall, hundreds of blank keys on
small brass hooks in numbered rows, sorted by profile. It is already in
the shell as a 7 × 14 grid; keep the grid and make the blanks vary in
tone between brass and nickel so the rows read as sorted rather than
tiled.

**Fittings.** A key duplicating machine — a small cast-iron machine with
two vices, a cutter wheel and a guide stylus, bolted to the bench. A
grinding wheel. A bench vice. Dismantled mortise locks laid out on a
cloth. A roll of picks, unrolled. A second-hand fire safe in the corner
with the gold-leaf name of a company that no longer exists. Padlocks on
a rail. A stepladder.

**The flair.** *The ledger is a register of every key cut in the
building.* Address, date, how many. In a building that listens, a bound
book listing who has copies of which door is the most quietly frightening
object on the street, and it needs no supernatural dressing at all.

**Do not** over-fill it. 17 m² is the second smallest shop here and its
character is *concentration* — one bench, one wall, one man who knows
everything.

---

### 4. RADIO SERVICE — radio · 3.00 × 5.00

**What it was.** 1927 is the peak of the radio boom — the Radio Act
passed that February. A service shop sold sets, sold valves, charged
batteries (most domestic sets ran on wet A cells and dry B batteries),
put up aerials, and repaired everything.

**AND IT IS THE ONE SHOP ON THIS STREET THE DIVERGENCE TOUCHES.** Bible
§VIII.2: anything that carries, captures, switches, stores or reproduces
a signal is forty to sixty years early. Everything in this shop that
handles a signal should be *impossibly good* — and the shop itself,
the shelves, the counter, the man's cardigan, should be 1927 and
second-hand. That contrast, in one 15 m² room, is the clearest statement
of the world's rule anywhere in the game.

**Hero object: THE SERVICE BENCH.** A set with its back off on a wooden
cradle, chassis exposed, valves standing proud. Beside it a signal
generator and an oscilloscope with a round green screen — objects that
have no business existing in 1927, built in the only materials this
world has: crackle-black enamel, brass fittings, Bakelite knobs, cloth
flex.

**Fittings.** A valve cabinet: a shallow case of small square pigeonholes,
each with a boxed tube. A battery charging bench with wet cells in glass
jars on a rack, connected in series with heavy leads. A horn speaker and
a cone speaker on the counter. Spools of aerial wire and insulators. A
soldering iron resting on a gas ring. A demonstration set playing quietly.
Coils, condensers and a drawer of salvaged parts.

**The flair.** *One receiver on the bench is tuned to 1610 and there is
nothing there.* The bible has WORS broadcasting from the Orison's laundry
room, on a carrier nobody ever found a transmitter for; the shops table
already says this man **knows about the carrier at 1610 and will not
say**. Leave the set on, the dial at the top of the band, the speaker
producing nothing but the hiss of an open channel. No note, no label,
no explanation. It is the best single object on the street.

**Do not** license anything else in the shop forward. The chair is 1927.
The kettle is 1927. Only the signal path is early.

---

### 5. LUNCHEONETTE — diner · 5.00 × 7.00

**What it was.** A counter and eight stools, which is what the shops
table says and what a luncheonette *is*: the counter is not furniture in
the room, it is the room. Quick food for people between shifts —
sandwiches, coffee, pie, a soda fountain.

**Hero object: THE BACK BAR.** Twin nickel-plated coffee urns with gas
heaters under them, a mirror behind, a pie case on the counter with a
domed glass lid, and a shelf of everything above. The urns are the
silhouette — two tall polished cylinders with brass taps and a small
gauge glass each.

**Fittings.** Terrazzo or marble counter with a chrome kick rail; eight
stools on chrome posts with oxblood vinyl tops. A soda fountain: marble
top, nickel dispensing taps, a row of syrup pumps, a carbonator below.
A milkshake mixer on a green enamel base. A griddle and a hot plate.
A cash register — heavy, ornate, nickel-plated, on a stand at the door
end. A cigar case beside it. A menu board with sliding letters (Label3D,
not texture). Ceiling fan. Napkin dispenser, sugar shakers, a jar of
pickled eggs.

**The flair.** *The two arcade cabinets in the corner the counter leaves
free* — already placed, and they are the joke the street tells about
itself: a 1927 luncheonette with two machines that reproduce a signal
and are therefore forty years ahead, standing next to a pie case.
Nobody comments on it. Nobody ever will.

**Do not** make the stools rotate as props. Eight rotating stools is
eight FunctionalProps for no gameplay.

---

### 6. NEWS & CIGARS — news · 2.10 × 4.00

**What it was.** 8.4 m² is a booth, not a shop, and the trade is built
around that: **the customer never comes in.** Everything faces out
through a hatch or over a counter that runs along one side, and the
proprietor sits in a chair he does not leave for ten hours.

**Hero object: THE PAPER RACK, SEEN FROM OUTSIDE.** Slanted wooden
shelves under the window with papers held down by dowels, magazines in
wire racks above. Build it to be read from the *pavement*, because that
is where it will be seen from most.

**Fittings.** A glass cigar case, cedar-lined, with sliding rear doors
and boxes inside; a cigar cutter and a small gas lighter chained to the
counter. Candy jars with glass lids. Pipes on a rack. Plugs of chewing
tobacco. A **punchboard** on the counter — a thick card of holes with
foil seals, a nickel a punch, technically not gambling. A cash drawer,
no register. A stool. A racing form under the counter, face down.

**The flair.** *The proprietor's chair has worn a hollow in one floor
tile.* And the punchboard is half-punched, so you can see how the day
has been going. This is the shop where the player learns that the street
has small vices in it and nobody minds.

**Do not** put a room's worth of furniture in 8.4 m². Two things and a
chair. The narrowness IS the design.

---

### 7. PAWNBROKER — pawn · 4.40 × 6.00

**What it was.** The block's bank. Three golden balls outside, a grilled
counter inside, and a back room stacked with other people's lives in
numbered brown-paper parcels. Pledges ran twelve months; the unredeemed
went into the window.

**Hero object: THE UNREDEEMED SHELF.** Floor to ceiling behind the
grille, parcels and objects with numbered tags — a violin case, a
sewing machine, a camera, a set of surgical instruments, an overcoat on
a hanger, a mantel clock, a wedding ring in a tiny envelope. Every one
is somebody's worst month, in order, with a number on it.

**Fittings.** Glass display cases down both walls with brass-topped
frames: watches, rings, small instruments. A wall of clocks, none
agreeing. A grilled counter with a brass wicket and a shelf to pass
things through. A jeweller's balance under a glass dome. A loupe on a
cord. A pledge ledger, heavy, with a pen. A safe.

**The flair.** *The clocks do not agree with each other or with the
building.* The Orison's own clocks are all set from a master that is
subtly wrong; a wall of twenty pawned clocks, each stopped or running at
its own rate, is the same idea said in a different key — and it is
period-correct, because a pawnbroker's clock wall genuinely was a wall
of unwound movements.

**Do not** make the goods precious. This is not an antique shop; it is
poverty with a counter.

---

### 8. FUNERAL PARLOUR — funeral · 4.40 × 7.00

**What it was.** By 1927 the undertaker had moved the funeral out of
the family parlour and into his own. A front room for viewings with
folding chairs, drapes, and a coffin on trestles; the preparation room
behind, never seen.

**Hero object: THE FRONT ROOM ITSELF, ARRANGED AND EMPTY.** Sixteen
folding wooden chairs in four rows facing a low bier, heavy oxblood
drapes across the back wall, palms in brass pots either side, and
nothing on the bier. The emptiness is the object.

**Fittings.** A register stand — a lectern with an open book and a pen,
which visitors sign. A wreath stand. A coffin on trestles under a purple
pall, or three sample caskets in a corner at three obvious price grades.
Electric candles, new and slightly wrong. A small desk with a telephone.
Crepe on the door.

**The flair.** *The price cards on the sample caskets are turned face
down.* It is what a good undertaker did — you ask, he tells you quietly.
It also means the player can turn one over. And the bible says **Dorothy
Ash went from here**, so the register book should be open at a page with
one signature on it and a lot of blank lines.

**Do not** put a body anywhere. Nothing in this room is a shock. It is
the most orderly, best-kept, most comfortable interior on the street,
and that is what makes it awful.

---

### 9. HARDWARE & PAINT — hardware · 5.20 × 6.50

**What it was.** The only shop on the street where the customer is
allowed to touch things, and it is packed to the ceiling. Sold by
weight, by the foot, and by the piece.

**Hero object: THE DRAWER WALL.** Floor to ceiling behind the counter,
a hundred and more small wooden drawers with brass label frames, each
holding one size of one thing. It is the single most photographed
feature of any period hardware store and it is cheap to build: one
drawer front repeated, with the frames catching light.

**Fittings.** Nail bins with a brass scoop and a hanging scale. A rope
spool on a spindle with a cutter. Galvanised buckets and washtubs hung
overhead. Stovepipe sections in a barrel. A paint bench: cans of white
lead and linseed oil, a hand-cranked shaker, a stirring paddle, a rack
of colour cards (Label3D or blank). A glass rack with sheets of window
glass on edge, and a cutter. A pegboard with tools on hooks and their
silhouettes painted behind them.

**The flair.** *The painted tool silhouettes.* A shadow board tells you
what is missing at a glance, and one hook should be empty with its
outline still there. And the shops table says this is **the only ladder
on the block** — so the ladder must be present, obvious, and clearly
the shop's own.

**Do not** organise it. The drawer wall is ordered; everything else has
accreted for thirty years.

---

### 10. PHOTO SUPPLIES — photo · 5.00 × 6.00

**What it was.** Plates, film, developing and printing, and cameras
under glass. But **read §VIII.4 before building this shop**: in this
world *recording is cheap and photography is dear* — inverted from ours.
Everyone owns a means of recording sound. A photograph is an occasion.

That changes the whole room. This is **not** a cheerful consumer shop.
There are few cameras and they are expensive, kept under glass and
locked. The portrait display is aspirational rather than ordinary. And a
shelf of prints nobody collected is not a small sadness — it is money
somebody could not go back for.

**Hero object: THE DARKROOM DOOR.** In the back wall, with a red lamp
above it that is lit, and a light-trap — either a revolving drum door or
a double curtain. It says there is a working process behind this counter
that the player cannot see, and the red lamp is the only saturated
colour in the shop.

**Fittings.** A glass counter with three or four cameras on velvet.
Shelves of plate and film boxes by size. Enlargers on a high shelf, cast
iron, second-hand. Developing tanks and enamel trays stacked. A print
dryer. A tripod rack. Tins of **flash powder** with a hazard tag —
flashbulbs do not arrive until 1929, so 1927 is powder, and it is
genuinely dangerous. A framed portrait display on the wall.

**The flair.** *The rack of finished, unclaimed portraits.* Faces of the
neighbourhood, printed and mounted and never collected. It rhymes
deliberately with the laundry's unclaimed parcels at the other end of
the street — two shops holding things for people who did not come back,
and the player walks past both. **Nadia is in here more than she is
upstairs**, per the shops table, so one of the mounted portraits should
be of a building.

**Do not** put a modern-feeling camera anywhere. Folding plate cameras,
a box camera, one press camera. No prism, no meter.

---

### 11. OTIS & SON — druggist · 4.10 × 7.00 · NORTH SIDE

**What it was.** The only reachable shopfront on the near side, and the
one the building actually needs. A long room with the dispensing counter
at the far end, a soda fountain halfway down, and everything else in
drawers.

**And in this world it is quietly the grimmest shop on the street,**
because §VIII.1 is explicit: signal technology ran forty years ahead and
*nothing else did*. There is no penicillin. A druggist in 1927 sells
tonics, patent medicines, poultices and opiate cough syrups, and the
shop is full of things that do not work. Play it bright, orderly and
well kept. **The wrongness is that it is orderly.**

**Hero object: THE SHOW GLOBES.** Two or three large glass carboys of
coloured liquid — red, green, amber — in the window, lit from behind.
They are the international sign of a chemist, they predate literacy as
signage, and they are the most beautiful object on the street. Build
them properly: ground-glass stoppers, a turned wooden pedestal, and a
lamp behind so they throw colour onto the pavement at night.

**Fittings.** A dispensing counter with a raised section at the far end.
A wall of small drawers with porcelain label plates. Shop rounds — glass
bottles with ground stoppers — on shelves, in graded sizes. A marble
mortar and pestle. A balance in a glazed case. A **locked poison
cupboard** with ribbed and blue bottles, which were ribbed *so they could
be identified by touch in the dark*. Cartons of patent medicine. A soda
fountain with marble top, nickel taps and four stools. A telephone.

**The flair.** *The ribbed bottles.* Explain them once, through
placement rather than text — the poison cupboard is the only locked
thing in the shop, and its bottles are the only ones you could tell
apart with your eyes shut. In a game about a building that listens, an
object designed to be identified without looking is exactly the right
kind of resonance, and it is a real 1927 object doing a real job.

**Do not** put anything modern behind the counter. No pharmacy-white,
no pill bottles, no branded packaging. Dark wood, glass, porcelain and
brass.

---

## V. MATERIALS

Everything here is already in `MatLib.SETS` with a runtime path. **No new
material key should be needed for these interiors**, and a request for
one should be justified against this list first:

`wood_dark` · `oak_quartered` · `enamel` · `porcelain` · `chrome` ·
`nickel_plated` · `brass_dull` · `brass_bright` · `brass_mesh` ·
`bronze` · `copper_aged` · `cast_iron` · `metal` · `bakelite_black` ·
`bakelite` · `milk_glass` · `terrazzo` · `terrazzo_dark` · `marble_lobby`
· `subway_tile` · `linoleum` · `quarry_tile` · `linen` · `paper` ·
`timber` · `plywood` · `vinyl_oxblood` · `fabric_warm` · `rubber_aged` ·
`mica_heater` · `zinc_liner` · `soot` · `fx_grease`

`glassish` is **Blender-only** and must not be used as a runtime
material. Clear glass on a GDScript-built fitting is an optical
StandardMaterial3D, not a bitmap.

---

## VI. BUILD ORDER AND VERIFICATION

**Order.** Hero object first, in isolation, rendered in the warehouse
before anything else goes in the room. If the hero does not make the
trade legible from six metres, no amount of fittings will.

Then: counter → back wall stock → window display → task lights → the
flair object → the ledger.

**Build them in this order across the street**, because it front-loads
the ones the player meets first and the ones that carry the most:

1. **RADIO SERVICE** — smallest, and it is the shop that states the
   world's rule. Get the 1610 set right and the street has a thesis.
2. **LUNCHEONETTE** — biggest footfall, already has the cabinets.
3. **OTIS & SON** — the only near-side shop, thirty seconds from the
   Orison's door.
4. **PAWNBROKER** and **MODEL LAUNDRY** — the two "unclaimed" shops,
   built as a pair so the rhyme lands.
5. The rest, in any order.

**Verify each with:**

- A **warehouse render of the hero object alone**, under flat light,
  against the 1 m grid.
- An **in-situ render from the doorway**, `SHOT_LIGHTS=1 SHOT_TORCH=1`,
  because that is the shot the player actually gets.
- A **render from the pavement through the glass**, which is how most
  players will see most of these shops and is the only view that tests
  the window display.
- **Player clearance**: a walkable route from the door to the counter
  and back, with no fitting inside the door's swing. Every prop family
  audited so far has had a clearance defect; assume these do too.
- **Mesh count**, as furniture boxes in the site pass rather than props.
  A shop should cost tens of vertices, not draw calls.
