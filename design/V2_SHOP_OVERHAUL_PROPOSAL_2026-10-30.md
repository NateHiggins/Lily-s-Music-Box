# V2 shop mechanics and appearance overhaul: proposal

Evidence class: **INERT**. A proposal for the owner's decision, dated 2026-10-30.
Nothing here is built, rendered or accepted. All stock and prices are in
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

I found one recent research packet on shops, **C:/ov/reports/storefront_research_20261028**
(six reference cards and a source register), plus item 7 of
**C:/ov/reports/research_agenda_20261028/RESEARCH_AGENDA.md**. These folders don't
say who wrote them. Lily's ChatGPT project tracker isn't readable from here, so any
gameplay research that exists only there was not used.

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
- **Named residents** only where a person matters: see section 9, decision 3.

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
  rubber (quiet, wears faster). Boots are gone while the work is done, so you get
  them back tomorrow, and you go about in borrowed slippers in the meantime.
- **Ties in:** footstep audio per surface. It matters for anyone asleep in the dark
  hours. Worn soles get louder and slip on wet stair treads.
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
- **Shown:** an open chassis that changes as sets come and go; valve shelves glow.

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

Each slice owes: real grabbing and release in tests, a schema-2 runtime receipt, reader
gate NEW 0, a draw-call measurement on the Arcade route, and a playable pass for Lily.

Any script or data change expires main's surface receipt, so slices merge in batches
with a merge hold for the renewal.

## 9. Decisions for Lily

1. **Who runs Photo Supplies after July?** The treatment has Adela, then Nadia keeping
   the window. The radio note's staff table puts Sacha there. I recommend the treatment.
2. **Should coin ever change hands?** Your radio-settlement ruling says no, and I've
   followed it, but papers and pool stakes feel like coin. I recommend staying with
   radio, plus a Harukiya slate.
3. **Which residents work?** The radio note proposes Omar at Radio, Iris at Paint, Mae
   at Pawn, Sacha at Photo, Lena at mending and Cam on restock. Mae at Pawn would change
   what she can do and when in the murder plot, so it needs your read. Lena's mending has no shop yet: the Laundry could carry it.
4. **Does rent get teeth?** Today it has no penalty. A notice under the door and a
   grumbling landlord would make money matter. Eviction would not fit. I recommend the
   notice.
5. **Are clean uniforms and sole noise too fussy?** They add small upkeep. Cut them
   first if the game starts to feel like chores.
6. **Is the ChatGPT research elsewhere?** If there's gameplay research in your tracker,
   paste it and I'll fold it in.
