# The household kitchens and the house cookbook

Evidence class: **INERT - DESIGN NOTE**

*Owner direction 2026-10-24: "i want a cultural dish with our alternate
reality twist made by each npc that is made from ingredients available to buy
in the bodega and the arcade mall. add shopping cooking eating and doing the
dishes tasks to the npcs behavior. add ingredients to the pantry and ice box.
simulate their use are stock. research and invent them and create an in game
cook book with them including character notes."*

## 1. The world's kitchen

Bible §VIII.4 fixes the room: "The kitchen is 1890. The parlour is 1970."
Every flat cooks on a coal range that has to be lit, keeps milk on ice with a
drip tray, and owns tin, enamel, cast iron and copper; there is no aluminium and
no stainless. Signal is the only thing this world advanced, so the twist on
every dish is a signal one: receipts dictated to cylinders, broadcast by the
Kitchen Hour, timed by a recorded sound, tuned by ear. Nothing about the food
itself is futuristic.

Queens in 1928 ate the food of whoever lived on the block. The canon names
no heritage for any resident, so the households' origins below are
**proposed**, chosen to fit each surname, profession and wound in
`design/ORISON_ARCHETYPE_SCHEDULES.md` and the neighbourhoods a Queens walk-up
drew from: New England Yankees, Azorean and Minho Portuguese out of Fall
River, Salonika Sephardim, Astoria's Bohemians, Scots, Welsh, Washington
Street Syrians, Japanese from the Harukiya's circle, Poles, Irish, Chiot
Greeks, Rhineland Germans.

## 2. The eighteen dishes

All are in `game/data/kitchen/cookbook.json`, each with ingredients and the
shop that sells them, a method, the washing-up it leaves, the twist, the
resident's note and the compiler's red pencil.

| Resident | Dish | From | Twist |
|---|---|---|---|
| Evelyn Marsh, 1A | Saturday Beans and Red-Pencil Brown Bread | New England | timed by the kettle's pitch, correcting the Kitchen Hour |
| Teresa Vale, 1D | Night-Shift Caldo Verde | Minho via Fall River | kale cut to a recorded alarm board |
| Mina Vale, 2A | Arroz Doce with the Date in Cinnamon | Portugal | transcribed from her mother's cylinder, four silent seconds kept |
| Lena Ortiz, 2B | Fijones for Whoever Comes | Salonika Sephardic | the loft's dictaphone cylinder survived the fire |
| Juno Kells, 2C | Bramboráky at Three in the Morning | Bohemia via Astoria | the crackle is in three uncredited broadcasts |
| Malcolm Reed, 3A | Cock-a-Leekie with the Prunes Left In | Scotland | roof leeks from Auggie's seed |
| Omar Bell, 3B | Mujaddara, Repaired | Mount Lebanon via Washington Street | lentils tinned on a press Omar repaired |
| Rhea Sato, 3D | Nikujaga, Take One | Japan via the Harukiya | learned from a disc of the cook's own cooking |
| Peter Wren, 4A | Toad-in-the-Hole, as Printed | England | the card's misprint, certified and obeyed |
| Cam Ortiz, 4C | Huevos Haminados for the Bridge | Sephardic, Lena's | a pocket timer keeps the overnight pot |
| Noel Price, 4C | Cawl on the Daily Set | Wales | cooked from a typed copy so the original is never touched |
| The guests, 4D | The Departure Sandwich | no fixed address | packed every morning for a train never taken |
| Nadia Quell, 5A | Bigos, Built Over a Week | Kraków | drafted unsigned on Quell and Sons letterhead |
| Cal Dwyer, 5B | Spotted Dog, Never the Last Slice | Tipperary | the bake graded by the crust's pitch through his hearing aid |
| Iris Bell, 5C | Gemista, Arranged | Smyrna and Chios | a still life for an audience that is not there |
| Sacha Reed, 6A | Rumbledethumps, Unphotographed | the Borders | the one time the camera went down |
| Jonah Price, 6B | Three O'Clock Rarebit | Wales | forty openings, never the line "serve it hot" |
| Mae Kessler, 6C | Sauerbraten, Certified | the Rhineland | the marinade timed by the iceman's recorded knock |

The cookbook is **The Orison Table**, compiled for the Tenants'
Association by E. Marsh of 1A: her foreword, one receipt a page, and her
corrections in red where one was owed. Brands follow the ones already on the
iceboxes' labels (Meridian, Astoria, Kessler's, Crown & Vale, Holloway's,
Bell Bros., Quell, Peerless, Wren's) and the counters (Harukiya shoyu).

## 3. Where the food comes from

`game/data/kitchen/groceries.json` lists 73 goods. Each one has a shop, a
price in cents, a unit and pack, pantry or icebox storage and keeping days.

- **The bodega** (always open): dairy, eggs, meat, vegetables, bread, dry
  goods, tins, Kessler's pickles, Harukiya shoyu, Peerless lager.
- **The Luncheonette**: yesterday's rolls, gingersnaps, beef dripping, and the
  urn's spent coffee grounds, free after close.
- **News & Cigars**: Quell tonic and chocolate.
- **Otis & Son, druggists**: spices, bay, soda, mustard powder. A druggist,
  not a grocer, sold these in 1928.
- **Hardware & Paint** (night service): soap flakes, scouring powder,
  kitchen matches.

The Arcade's shops keep its hours: closed 02:00 to 06:30, except Hardware &
Paint.

## 4. The simulation

`KitchenLarder` (`game/scripts/game/kitchen_larder.gd`) keeps every
household's stock on the campaign save (`household_larders`, validated on load):

- **Stock.** A quantity per good with the minute it was bought. Each household
  starts with its long-keeping pantry goods, soap and matches, and a bare
  icebox.
- **Shopping.** The resident goes to the open shop that sells the most of what
  their dish lacks, and buys whole packs until the dish is covered.
- **Cooking.** If everything is in, the resident cooks their dish: it uses the
  ingredients and a match, leaves the dish's portions, and adds its washing-up.
  If not, a plain supper of eggs and bread, if there are any.
- **Eating.** One portion, one plate to wash.
- **Washing up.** Clears the stack, using soap flakes and scouring powder.
- **Spoilage.** Anything past its keeping days is thrown out. Leftovers keep
  two days.

The **resident agenda** decides when (`design/ORISON_RESIDENT_AGENDA_2026-10-24.md`):

- **Shopping** is an option while anything is short; it is weighted by hunger.
- **Cooking** is an option when everything is in and nothing is left.
- **Eating** is an option while portions remain.
- **Washing up** is an option once the stack passes the household's tolerance:
  1 to 8 pieces, from `apartment_life_profiles.json` cleanliness.

The timetable's own cooking, eating and chores blocks also cook, eat and wash
up. Mina's body cannot reach the Arcade, so her shopping there is an errand
off the map ("out").

## 5. Pantry and icebox

Every household's **icebox** shows its larder. Each cold good maps onto a
food shape the icebox already has (`icebox_looks`): Meridian bottles, Astoria
cream, Wren's butter, egg cartons, Kessler's jars, paper-wrapped meat, a
covered dish of leftovers. At most four sit on a shelf, and they are restocked
whenever the household's stock changes. An empty larder is an empty icebox.

The **pantry** is the back edge of the kitchen work table, in the eleven
residents' flats that have one. `PantryDisplay` shows up to eight dry goods in
stock as paper sacks, zinc tins, stoneware jars, packets, a loaf and paper
bags of produce (`pantry_looks`). Each carries a Label3D tag with its name and
stays clear of the bowl. All surfaces use catalogue PBR on metre-charted UVs.

## 6. Measured

`ResidentAgendaTest` lives four spring days, step by step, with every larder
live:

- 242 kitchen events: 71 shopping trips, 36 cooks, 104 meals eaten from the
  pot, 20 washing-ups, 11 spoilages.
- All eighteen residents cooked their own dish.
- All five shops were used.
- No stock went below nothing.

`OrisonV2KitchenTest`, run in the game window, shows the following in the
production V2 root:
- the cookbook on 4B's table, reached by the player's ray, with its foreword
  and eighteen pages
- Lena's shopping and cooking, restocking 2B's icebox with native food stock
  and 2B's pantry with its dry goods

## 7. Not done

- The six flats whose only work surface is a board over the sink, and the
  closed wall cupboards, show no dry goods.
- The player's own kitchen in 4B keeps no larder.
- The shop counters' own stock does not fall when residents buy. The bodega's
  bucket counts timetable visits only.
- The proposed heritages and brands await the owner's ruling.
