# V2 shop mechanics and appearance overhaul: proposal

Evidence class: **INERT**. A proposal with the owner's rulings in section 9, dated
2026-10-30. Nothing here is built, rendered or accepted. All stock and prices are in
**design/V2_SHOP_CATALOGUE_2026-10-30.md**.

Owner direction, 2026-10-30: every shop needs a gameplay purpose; fill out each
shop's inventory; plan how it can be simulated and displayed.

## 1. The short version

Thirteen premises exist and four do anything. This proposal gives each shop one
job no other shop does and one physical thing the hand does there. They all share
one catalogue, one way to pay and one stock simulation, so thirteen shops cost
about one system plus thirteen small data files and props.

Three rules hold everything together:

1. **A shop sells a change in how you play, not just a thing.** Boots change how
   loud you are. Earplugs change what you can hear. A ladder changes what you can
   reach.
2. **Money never buys the solution.** Shops hold evidence you can read, ask about
   or develop. No clue has a price, and being broke never blocks the mystery.
3. **The shops are people's lives.** Stock, windows and hours react to the year,
   the papers and what the residents buy.

| Shop | Its one job | What the hand does |
|---|---|---|
| Hardware & Paint | Parts for the work, and the only ladder | Pull a drawer, weigh on the scale, carry the ladder |
| Keys Cut | Access, with permission | Clamp a blank and draw it past the cutter |
| News & Cigars | The news, and mail order | Lift a paper off the tier, tear a coupon off the back page |
| Bodega & Notions | Food and errands for residents | Hand over the list, take the bag |
| Otis & Son | Medicine errands, and earplugs | Pass a prescription across, pull the soda tap |
| Luncheonette | Where to find people, and overhear them | Take a stool, lift the cup |
| Model Laundry | Your uniform, and the wall of unclaimed parcels | Match a ticket to a parcel on the wall |
| Shoe Rebuilding | How loud you are | Set a boot on the bench and choose a sole |
| Radio Service | What your set can do | Turn the dial until the needle peaks |
| Photo Supplies | Evidence, and Adela's window | Rock the tray under the safelight |
| Pawnbroker | Fast money, and who is in trouble | Slide an object under the grille |
| Funeral Parlour | Paid quiet work, and the book of who came | Set out chairs to the count |
| Harukiya | The evening, and wagers | Slide a glass, chalk the slate, throw |

## 2. What exists now

From a code survey of main at **fb6851f2**. It was a static read; the game was not
run for it.

- **Working:** Hardware has three settlement levers, Keys Cut cuts permitted
  spares free through a button panel, News & Cigars gives papers free through a
  dialogue chooser, and Harukiya has songs, darts, point ball, a sink and a speaker.
- **Walk-in only:** Laundry, Cobbler, Funeral, Photo, Radio, Pawn, Otis,
  Luncheonette and Bodega. The Bodega counter has no collision in V2.
- **Nobody works anywhere.** No shop has a staff assignment or a clerk actor.
- **Money:** one ledger in cents (**CaretakerEconomy**), starting at $1.00. The
  only income is job tips of about 25 cents. Rent is $5.00 per 30 days with no
  penalty.
- **Stock:** only the Bodega has a simulated bucket. It holds 24 units with no
  restock, so it probably empties within days and hides its shelves. No Arcade
  shop has one.
- **Catalogues:** the only real sale-goods list is **game/data/kitchen/groceries.json**,
  73 priced ingredients used only by residents, and their spending is just a log
  line. **hardware_stock**, **radio_stock** and **photo_stock** are art manifests.
- **Item limits:** **MaintenanceInventory** is one-use-per-campaign facts.
  **PersonInventory** takes only keys and groceries. Neither can hold a bought
  pair of earplugs.

## 3. The research

The recent research on shops is **C:/ov/reports/storefront_research_20261028** (six
reference cards, a source register, a kit drawing and a dimension schedule), plus item 7
of **C:/ov/reports/research_agenda_20261028/RESEARCH_AGENDA.md**. The owner confirmed on
2026-10-30 that this is the research there is: historical cards and authored adaptations
for frontages, with no comprehensive interior packet.

**What it gives this proposal:** six distinct frontage compositions (grocery =
canopy and crates; hardware = tall tools; news = hatch and paper tiers; pharmacy =
paired globes and order; lunch = low sightline and stools; bar = opaque door and
depth), one shared kit and dated exclusions. Section 7 adopts them whole.

**Where this proposal departs from it.** The cards and
**design/V2_STOREFRONT_REFIT_PLAN_2026-10-29.md** say no new shop mechanics, and the
agenda says no delivery economy or shop systems. Those were limits on that research
scope. The owner's new direction overrides them for this work only. Their other
exclusions stand (no second ladder authority, no new sign material in maps).

**Gaps:** the cards cover six of thirteen. Keys, Laundry, Cobbler, Radio, Photo,
Pawn and Funeral have no reference card, and Photo matters most. No source has
gameplay research on period shops. My own two price searches came back thin, so
the catalogue's new prices are authored guesses and are labelled so.

## 4. The shared systems

These are the first slice and everything else depends on them.

**4.1 One catalogue.** **game/data/shops/<shop>.json**, literal paths for the reader
gate. Each item has an id, name, cents, a kind, a stock group and what it does.
Groceries stay where they are and the Bodega reads them, so residents and player
share one price.

**4.2 One place to carry things.** Add a **goods** kind to **PersonInventory**, with
stack counts and a bound. MaintenanceInventory stays as it is. The player's goods
stay in pockets and are listed on the pocket ledger, which is already there.

**The carried case.** Owner direction, 2026-10-30: goods live in a physical case, in
the spirit of the Resident Evil attache case. Tab opens a forward-folding dispensary
valise over the live world (**art/blender/carried_case.md**). The fold-down shelf is
stitched into a 10 by 6 grid, and each good has one of eleven shapes and footprints.
Click grabs a stack, motion carries it, the next click sets it down, and right click
or R turns it. The arrangement saves in **carried_case**. Only bought goods take up
room: keys, parts, groceries, cash and rent are on the lid's card, so a full case
cannot block a job or the mystery.

Carrying a stack off the front of the shelf uses one: food, tobacco and medicine are
spent, with one remark from the set per kind, and earplugs lower the mix for a shift.
Marked goods can be given at a door, one a day to each resident. Hardware's goods and
other things with no use stay in the hand, because jobs do not yet draw on carried goods.

**4.3 One way to pay.** The owner already ruled that every point of sale settles
over the handheld by radio (**design/V2_RADIO_SHOP_NETWORK_2026-10-22.md**). So:
extend **RadioClearingNetwork** past its hard-coded hose items, and mount
**radio_sale_terminal** at every counter. Take the thing, push the lever, a slip
prints. That is the existing RUL-013-compliant model. The refusal slips already
exist: no carrier, line closed, no credit. **purchase_once** cannot serve repeat
purchases, so it needs a repeatable sibling on the same ledger.

Replace the migration debt on the way through: the key panel and the news chooser
become physical actions (RUL-013).

**4.4 Income that can pay for it.** At 25 cents a job, rent alone is 20 closed jobs
a month, and tips are capped so goodwill can't be farmed. Proposal: Arcade tenants
post paid jobs through the existing work orders (a stuck shutter, a blown fuse),
and the Funeral Parlour pays for chair work. Pawn gives fast money at a cost.
Prices stay modest enough that a careful player has choices and a careless one
goes without a treat, never without the story.

**4.5 Who is behind the counter.** Three tiers, using as few people as possible,
as the owner directed:

- **The set handles the sale** when nobody is needed. Most hardware, news and
  bodega sales work unattended on the terminal, as the radio note proposes.
- **Anonymous stick figures** browse and serve as background
  (**K-V2-BACKGROUND-STICKFIGURES**). They create no facts.
- **Named residents** only where a person matters: see section 9, ruling 3.

**4.6 Stock simulation.** One S1 bucket per shop, extending
**orison_v2_shop_simulation.gd** and its existing no-second-clock catch-up.

- Stock is **groups, not items**: fresh food, tinned goods, papers, valves. Each
  group has a level of **full, thin or out**.
- **Restock comes from deliveries on the calendar**, which fixes the Bodega running
  dry: milk daily, ice by wagon, papers at dawn, parts weekly.
- **Demand** comes from the existing schedule visits and the player. Only six shops
  are schedule places today; the other seven get visits as a statistic.
- **The year pushes on it:** the gas mantle shortage already in the mail, a July
  heat run on ice and soda, Christmas toys. Each is one dated row in a table.
- **Pawn and Photo** carry named item records rather than groups, because the
  specific object is the point.

**4.7 How it shows, within the draw-call budget.** The frame is draw-call bound, so
stock display must not add per-item nodes.

- A stock group swaps between three pre-batched shelf states. Out of stock means a
  bare shelf and a hand-lettered card, using the existing Bodega hide path.
- Price tags and notices are Label3D on the frequently handled items only, at the
  counter (RUL-008). Ordinary tickets stay illegible modelled paper.
- A closed shop reads as closed through the existing grille director, plus a card
  in the door.
- The window changes by month from a small set of pre-built dressings. Photo's
  window is the exception, with its own authored cards.
- Purchasable things use the existing physical stock pickup, one per item type.

**4.8 Teaching.** Opaque handheld slips on the field printer, once each (Bible
§VIII.5.l). Nothing explains how to operate a thing; the cursor does that.

## 5. Shop by shop

Each entry: purpose, the mechanic, its tie to the existing game, and what's shown.
Hours are as installed unless marked.

### Hardware & Paint. *Parts and reach.* Open all night (canon).
- **Purpose:** the Bible's diagnosis loop sends you here for parts. It stays the
  main parts counter, and now sells consumables you choose to carry ahead of need.
- **Mechanic:** pull a drawer, take the part, push the lever. Nails and screws by
  weight on the scale. **The ladder** is lent against a deposit and physically
  carried, which opens high jobs and places. It occupies your hands, so you plan the
  route.
- **Ties in:** work orders; the mantle shortage ("we have none" already runs in the
  paper); gaskets and protectant as sold today.
- **Shown:** the drawer wall as the hero, the ladder gone from its hooks when lent.

### Keys Cut. *Access, with permission.*
- **Purpose:** a copy opens a door for good, but only with a tenant's say-so.
- **Mechanic:** bring the tenant's signed slip and the original. Clamp both, draw the
  carriage past the wheel by hand. A rushed pass makes a key that sticks. Replaces
  the button panel.
- **Ties in:** **DoorKeyring** permission rule, trust (a resident must trust you to
  sign). The shop's copy book is readable and dated, so the question of who holds a
  key has somewhere to go. It shows no murder fact by itself.
- **Shown:** the key board fills and empties by hook; sparks and grinder noise.

### News & Cigars. *The news, and mail order.*
- **Purpose:** the paper starts costing its masthead price and becomes the way to
  order everything from the back page.
- **Mechanic:** lift a paper off the tier. **Tear a coupon off the back page** of a
  paper you own and post it in the box here. The order arrives days later through the
  existing mail. So the ads you read are things you can actually have: earplugs,
  felt bedpost pads, a tone bar, a home cycle meter, postcards for the Pun Derby.
- **Ties in:** the 65 advertisements, **mail_catalog**, the companion's paper
  witness. Cigars and chocolate work as small gifts.
- **Shown:** today's paper stacks shrink through the day; an unsold pile at closing.

### Bodega & Notions. *Food and errands.*
- **Purpose:** residents who can't get out give you a list. You buy the goods, they
  go in that household's larder, and the resident cooks from it.
- **Mechanic:** hand over the list, the counter fills a bag, you carry it to the door.
  A forgotten item is noticed at the door. Tips and trust follow within the caps.
- **Ties in:** **household_larders**, the 18 dishes, 52 priced items, the Bible's
  valves at six for a dollar. Connects residents' spending to the real stock bucket
  instead of a log line. Rebuild the counter collision.
- **Shown:** crates and an awning outside (Card 1). Produce thins out through the day.

### Otis & Son. *Medicine errands, and what you can hear.*
- **Purpose:** prescriptions for residents, simple first aid, and **earplugs**, the
  one real trade-off in the block: the Hum drops, but so do the small faults you find
  by ear. You choose when to wear them.
- **Mechanic:** take the resident's slip to the counter, wait a real few minutes
  while it's made up, carry it back. At the fountain, pull the tap and take a stool.
- **Ties in:** the acoustic graph and audio policy. Nothing here is a cure; tonics
  remain jokes on a label, and no item explains the Hum.
- **Shown:** the show globes (Card 4). Evening, the fountain stools fill.

### Luncheonette. *Find people, overhear them.*
- **Purpose:** the one place to meet residents who don't answer doors, and hear what
  the building thinks.
- **Mechanic:** take a stool, order from the board, lift the cup. While you eat, time
  passes and the people at the counter talk. Those lines come from the existing dated
  opinions, overheard and not addressed to you.
- **Ties in:** 292 authored opinions, **schedule_director** (already a schedule
  place), and the two menu jokes waiting in **object_copy.json** for a food counter.
- **Shown:** the low window onto the stools (Card 5), so you can see from the Arcade
  who is in there. Yesterday's rolls are cheaper, as the ad says.

### Model Laundry. *Your uniform, and the unclaimed wall.*
- **Purpose:** a clean uniform helps at doors, and the parcel wall is a physical
  search. This replaces the V1 note's "public Matching game".
- **Mechanic:** drop off a bundle, get a ticket, come back later. Residents' errands:
  find a parcel on the wall by matching ticket to tag, by eye and by hand. A dirty
  uniform is a small cost at first contact only; it never closes a door outright.
- **Ties in:** existing door trust. The ad's joke, "your shirts are still here", is
  the design: unclaimed parcels stay for a year, including, after July, one nobody
  will come for.
- **Shown:** the wall grows and shrinks by real parcels, batched in three states.

### Shoe Rebuilding. *How loud you are.*
- **Purpose:** your soles decide how the building hears you at night.
- **Mechanic:** set the boot on the bench, choose leather (lasts, loud on terrazzo) or
  rubber (quiet). Boots are gone while the work is done, so you get
  them back tomorrow, and you go about in borrowed slippers in the meantime.
- **Ties in:** footstep audio per surface. It matters for anyone asleep in the dark
  hours.
- **Shown:** the common-shaft finisher running, racks of ticketed shoes, the smell
  joke from the ad as a wisp over the machine.

### Radio Service. *What your set can do.*
- **Purpose:** the only place that improves the carried set: a sharper field lamp,
  better reception, more printer paper.
- **Mechanic:** at the bench, turn the alignment dial with the hand until the needle
  peaks on a live signal. Parts are bought once each, and a used valve from Pawn
  works but may hum.
- **Ties in:** the carried set, parts for Vantry sets as advertised. The bench
  may notice 1610 is there but, like the papers, never explains it. An
  upgrade never gates a companion conversation.
- **Shown:** an open chassis that changes as sets come and go; the valve shelves thin out.

### Photo Supplies. *Evidence, and Adela's window.*
- **Purpose:** the heart of the Arcade. Canon makes photographs dear and rare, so a
  print is a real event. This is where a negative becomes evidence.
- **Mechanic:** buy a single plate for the rare occasion you want a picture.
  Develop in the darkroom by hand: rock the tray under the safelight, lift the print
  when it's ready, too early is thin, too late is lost. The negatives register is
  read, not bought.
- **Ties in:** the treatment's carriers **m_register**, **m_nadia_card** and
  **m_aviation_card**; the window cards; plates 12 and 13. Before 19 July Adela keeps
  the shop, after it Nadia's cards "are not as good". Plate 13's half-image is never
  improved by your skill: technique affects your own pictures, not the case.
- **Shown:** a window that changes on authored dates with the pinned headline and
  grease-pencil card, the only per-date window in the Arcade.

### Pawnbroker. *Fast money, and who is in trouble.*
- **Purpose:** an honest way to get money you may regret, and the place the building's
  troubles show up on a shelf. The V1 note said it "buys what the smash room leaves".
- **Mechanic:** slide an object under the grille, receive a price and a ticket. Redeem
  it for a bit more within 30 days, or it goes on the shelf for sale. Residents' pledges
  appear on the shelf too, by date, so you may recognise someone's clock.
- **Ties in:** PersonInventory goods, a named-object bucket. Second-hand sets and used
  valves as advertised. Sold-up residents are authored dated rows, not procedural.
- **Shown:** the three balls outside; clocks stay static, each with a ticket.

### Funeral Parlour. *Paid quiet work, and the book.*
- **Purpose:** the steady wage nobody else offers, and the record of who came.
- **Mechanic:** when a service is booked, set the sixteen chairs out to the count by
  hand, and fold them after. No talking, no timer. The attendance book is readable.
- **Ties in:** the coat collected in the treatment and the 16 September
  memorial. The companion's silence rule holds here:
  it says nothing in this room.
- **Shown:** chairs out or stacked as actual state; the empty bier as negative space.

### Harukiya. *The evening, and wagers.*
- **Purpose:** where the money goes when you've earned it, and where residents are at
  night. It already has the richest actions.
- **Mechanic:** order by pushing the glass across, and your tab goes on the slate.
  Add pool and darts wagers (a small stake with a neighbour), already noted as unbuilt
  in **caretaking_and_economy.md**. Paid song sessions on the stage. Settle the tab on
  the set before you go, or it follows you.
- **Ties in:** songbook, stage, opinions. No alcohol policing or keypad, as the card
  says, and no drunk mechanics.
- **Shown:** the plain door and depth (Card 6). Slate marks by Label3D, only near.

## 6. How the shops feed the existing game

| System | What it gains |
|---|---|
| Maintenance loop | Consumables, the ladder and paid Arcade jobs, so a shift has a route and a budget |
| Residents | Errands that feed real larders; trust follows from care (caps kept) |
| Mystery | Readable books and the darkroom. Every clue stays free to reach |
| Companion | A dozen new things for it to witness and remark on, using its event path |
| Newspapers | Ads become orders; shortages in print match shelves |
| Dark hours | Soles and earplugs change how the night plays |

## 7. Appearance

**Adopt the six cards and the refit plan's kit** for Bodega, Hardware, News, Otis,
Luncheonette and Harukiya, in its slice order. Add seven more identities on the same
kit, as a proposal, pending a new reference pass:

| Shop | Silhouette at a distance | Window argument |
|---|---|---|
| Keys Cut | A large hanging key on a bracket | The key board seen through the glass |
| Model Laundry | Pale, steamed glass, plain enamel | Ticketed parcels stacked to the head of the window |
| Shoe Rebuilding | A hanging boot | One gleaming rebuilt shoe on a stand, next to a ruined one |
| Radio Service | A blade with a coil motif | One open chassis, lit |
| Photo Supplies | A small cream fascia, grease-pencil cards | The pinned headline and correction card |
| Pawnbroker | The three balls, iron grille | Too many objects, none matching |
| Funeral Parlour | Black, with one wreath stand; almost no sign | A single drape and palm |

Lettering stays Label3D; no reference photo is baked (RUL-007, RUL-008). All new
surfaces pass **V2_SURFACE_REQUIREMENTS** (RUL-012). Inside, the shared rule from
**SHOP_INTERIOR_INVENTORY.md** holds: one ledger, one implied back room, one window
argument. Renew the surface packet once per batch, not per shop.

## 8. Order of work

| Slice | Contents | Why here |
|---|---|---|
| 1 | Shared systems: catalogue, goods, repeat sales, terminal, buckets | Everything needs it |
| 2 | Hardware, Bodega, News | The money loop, errands and ads; existing owners are closest |
| 3 | Photo, Keys, Pawn | The mystery's shops; Photo's window also gives the playtest something real |
| 4 | Luncheonette, Otis, Shoe, Laundry | Daily-life choices and overhearing |
| 5 | Radio, Funeral, Harukiya | Set upgrades, wage work and wagers |
| 6 | Appearance batches | After the refit kit proves itself on Otis |

**Status, 2026-10-31.** Slice 1, the carried case and slice 2 are built. Four coupons can
be torn off the back page, posted at News and received in the 4B box. Sev Technical
Salvage's coupon is deliberately not orderable, because its contact microphone already
has its own arrival rule. Hardware, News and Bodega sell through one terminal per counter
with a selector, News charges for a paper and falls back to the desk account when it
can't, and door errands are in. Not built in slice 2: a modelled
price card and selector, and the Bodega's list-and-bag props.
Hardware's drawers and ladder are not yet operable.

**Slice 3 so far.** The Pawnbroker is built: pledge at the grille by carrying a stack off the
shelf, redeem within thirty days at an authored 3 percent a month, lapsed tickets go on the shelf
at twice the loan, and four residents' dated pledges appear and sell once. Not built: objects in
the wall cases, and Mae behind the counter, which still needs its timeline check.

Keys Cut is built: a permission puts a spare on the counter's list at 25 cents, and the hand draws
the carriage past the wheel to cut it. Not built: a key that sticks after a rushed pass, and the
readable copy book. Rent has its consequences: notices at one, two and three months, and from two
months tenants without an enabled case stop signing. Spares already cut stay.

Photo Supplies is built. The terminal sells its goods. Printed at the counter a plate comes back at
once, in whoever's hand keeps the shop. An hour in the darkroom takes a plate, a sheet and the chemicals:
the hand rocks a working tray on the rack, the picture comes up, and the hand lifts the sheet out,
thin, good or lost. Sittings stop on 19 July. The negatives register is drawn across the counter and
reads to today, granting **m_register**. The window's cards change on their authored dates, and two
of them are read from the street (**m_aviation_card**, **m_nadia_card**). Not built: exposing a plate
yourself, so every print shows the same street, and any use for a print beyond keeping it.

Each slice owes: real grabbing and release in tests, a schema-2 runtime receipt, reader
gate NEW 0, a draw-call measurement on the Arcade route, and a playable pass for Lily.

Any script or data change expires main's surface receipt, so slices merge in batches
with a merge hold for the renewal.

## 9. Owner rulings, 2026-10-30

These settle the open questions. Sections 4 and 5 read with them.

1. **Photo Supplies after July:** Nadia keeps it, as in the treatment. The older staff
   table's Sacha at Photo is retired.
2. **Money:** radio settlement everywhere, plus the slate at Harukiya. No coin dish.
3. **Staff:** all four proposals go ahead: Omar at Radio, Iris at Paint, Mae at the
   Pawnbroker, Lena's mending at the Laundry, and Cam on restock.
4. **Rent:** notices, then lost perks. Late notices come under the door and grow more
   pointed. After that, tenants stop signing spare-key permissions until you pay.
5. **Upkeep:** sole noise and the clean uniform both stay. The sole-wear answer
   conflicted (both "wear" and "no wear" were chosen), so the first build has **no sole
   wear**: the choice of sole matters and needs no upkeep. Wear can be added later
   without changing the data.
6. **Funeral Parlour:** paid per booked service, with no timer or talking.
7. **Order:** shared systems, then Hardware, Bodega and News, as in section 8.
8. **Research:** no gameplay research exists beyond what section 3 lists. There is no
   comprehensive historical interior packet for the thirteen shops. Follow current
   Bible and owner direction over the older research scope.

**What these rulings require:**

- **Spare-key perks never touch the mystery.** Rule 2 of section 1 wins. Treatment keys
  (**m_spare_key**, **m_key_loan_11**, **m_key_loan_19**) and any door the case needs
  stay outside the rent penalty.
- **Mae at the Pawnbroker needs a timeline check before it ships.** Her schedule must
  hold her dark-hours alibi, the rent receipt and her sale day. The job is a reason to
  be seen in the Arcade and a reason to know who is short of money. It adds no clue and
  no confession.
- **Lena's button book and mending ticket stay hers** when her mending moves to the
  Laundry: **m_button_book** and **m_bag_ticket** read the same. The Laundry gains a
  mending counter, and her 2B basket remains a carrier.
- **Cam on restock** must not disturb **m_route_book**. Deliveries are additional runs.

## 10. What is already modelled

From the fitting guides under **art/blender/**. Reuse these first. Their guides call them
passive, so none sells anything yet, and each needs a sale owner.

| Shop | Already built | What it changes here |
|---|---|---|
| Hardware | 35 drawers, beam balance, unloaded paint shaker, mixing paddle, 36 trays of washers, bolts, couplings and nails, 7 paint tins | The drawer, weighing and shaking actions need no new props, only motion |
| News | Four candy jars, pipe rack, punchboard, racing-form shelf, 16 cigars, cash drawer, open hatch frame | The catalogue gains candy, pipes, the punchboard and racing forms. The cash drawer stays passive under the radio ruling |
| Bodega | Tins, packets, produce crates, passive weighing dial, icebox, handcart | The handcart can be the delivery prop |
| Luncheonette | Empty griddle, five-pump fountain, 8 stools, urns | The griddle needs food on it when ordered |
| Otis | 4 stools, fountain, carboys, drawers, mortar | The tap needs motion |
| Photo | 15 cartons on the lower three decks; the upper two shelves are deliberately empty | Stock states have room to grow; cartons don't show contents |
| Radio | 14 stored opal valves with no emissive or electrical behaviour | Section 5's "valve shelves glow" is dropped: they stay unlit |
| Pawnbroker | 24 parcels, violin case, sewing machine, hanging coat, safe, balance, loupe, telescope, pocket watch, field glasses. **The two wall cases are deliberately empty** | The empty cases are where dated pledges appear |
| Funeral | 16 chairs, 2 benches, all static source records | Movable chairs are new work, the only real geometry cost in slice 5 |
| Harukiya | Its reference notes already call for a drink order with physical preparation | Matches the glass-and-slate proposal |

**Interior references.** The guides record what was built. They are not historical
evidence for what a 1929 shop stocked. If interiors or the seven uncarded frontages
need that evidence, it needs its own packet.

## Luncheonette first build, 2026-11-01

Evidence class stays **INERT**; this records what was built, not proof.

- **Built:** a sale point on the counter. An order comes up as a cup, a plate or both.
  A click grabs, mouse motion lifts it to the mouth, and it only goes down at the top
  of the lift. The next click lets go. What is left is saved and validated.
- **Overheard:** while something is left on the counter, residents the timetable seats
  there speak their dated opinions, one sentence at a time. It grants only
  **overheard:<id>**, so the opinion still waits at their door. Money buys no clue.
- **Bodies:** a seated body on a stool, placed only while the player is outside the room.
- **Timetable changes for Lily to read:** the schedule had one Luncheonette block, so
  three were added. Iris Bell's Thursday walk was already authored as "sits in the
  diner" and is now placed there. Noel Price goes there first on Saturday, 14:00-15:00.
  Evelyn Marsh ends her errand circuit there on Monday, Wednesday and Friday, 11:20-12:00.
- **Not built:** sitting down yourself, because a sit toggle breaks RUL-013 and needs a
  ruling on the gesture. No food shows on the plate or coffee in the cup, the griddle
  stays empty, the menu board does not list the shop's own items, the Melancholy
  Special joke is unplaced, and the draw-call cost on the Arcade route is unmeasured.

