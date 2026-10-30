# V2 shop catalogue: proposed inventory

Evidence class: **INERT**. Companion to **design/V2_SHOP_OVERHAUL_PROPOSAL_2026-10-30.md**.
Nothing here is live.

**Prices.** Prices marked **live** come from game data or the Bible and win any
disagreement. Prices marked **ad** come from the advertisement copy on the newspaper
branch. Everything else is an authored guess at a 1929 Queens price, not historical
research, and needs a check against dated advertisements before it ships.

**Kinds.** **goods** go in pockets, **consumed** are used on the spot, **service** takes
time, **part** feeds a job, **upgrade** is bought once, **loan** comes back.

**Groups.** The stock group a line belongs to; these are what the simulation counts.

**Alternate history.** The Rule of Signal keeps valves, wet cells and recording cheap.
Items that exist only in this world are marked **world**.

## Hardware & Paint

| Item | Cents | Kind | Group | Note |
|---|---|---|---|---|
| Carbon transmitter capsule | job | part | parts | **live**, job-gated |
| Rubber protectant, service bottle | 25 | part | parts | **live** |
| Hose coupling gasket | 10 | part | parts | **live** |
| Receiving valve, sleeve of six | 100 | part | parts | **ad**, **world** |
| Silk flex, per yard | 12 | part | electrical | **world** status item |
| Rubber flex, per yard | 5 | part | electrical | stiffens with age |
| Fuse, screw-in | 5 | part | electrical | |
| Friction tape, roll | 15 | goods | electrical | |
| Gas mantle | none | part | shortage | **ad**: "we have none"; management mails them |
| Nails, by the pound | 7 | goods | bins | weighed |
| Wood screws, by the pound | 18 | goods | bins | weighed |
| Machine oil, can | 15 | goods | sundries | |
| Pipe dope, tin | 20 | part | sundries | |
| Faucet washers, card | 5 | part | sundries | |
| Hex bolts, by the pound | 18 | goods | bins | Already in the trays |
| Flanged brass coupling | 20 | part | bins | Already in the trays |
| Soap flakes | 12 | goods | sundries | **live** |
| Scouring powder | 10 | goods | sundries | **live** |
| Kitchen matches | 5 | goods | sundries | **live** |
| Map pins, gross | 15 | goods | sundries | **ad**, for WORS maps |
| Inside-window scraper | 5 | goods | sundries | **ad** |
| House paint, quart | 75 | goods | paint | shaken by hand |
| Paint brush | 25 | goods | paint | |
| Ladder | 100 deposit | loan | ladder | one only, returned deposit |

## Keys Cut

| Item | Cents | Kind | Group | Note |
|---|---|---|---|---|
| Spare key, with signed permission | 25 | service | blanks | a new charge; free today |
| Spare key, flat or trunk | 15 | service | blanks | |
| Lock rekeyed | 100 | service | none | tenant's choice, for jobs |
| Padlock | 40 | goods | hardware | |
| Key ring | 5 | goods | hardware | |
| Brass Listening Act door notice | 50 | goods | hardware | **ad**, **world** |

## News & Cigars

| Item | Cents | Kind | Group | Note |
|---|---|---|---|---|
| The Borough Record | 2 | goods | papers | **ad**, masthead price |
| The Loud Speaker | 1 | goods | papers | **ad**, masthead price |
| Quell tonic | 5 | goods | counter | **live** |
| Bar of chocolate | 5 | goods | counter | **live** |
| Cigar, nickel | 5 | goods | tobacco | gift |
| Cigar, ten-cent | 10 | goods | tobacco | better gift |
| Cigarettes, pack | 13 | goods | tobacco | a 1933 report has 12 to 13 cents |
| Pipe tobacco, tin | 15 | goods | tobacco | |
| Postal cards, hundred | 100 | goods | stationery | **ad**, for the Pun Derby |
| Postage stamp | 2 | consumed | stationery | for coupon orders |
| Pencil | 2 | goods | stationery | |
| Stick candy, from the jars | 1 | goods | counter | Four jars are modelled |
| Briar pipe | 50 | goods | tobacco | The pipe rack is modelled |
| Racing form | 10 | goods | papers | The lower shelf is modelled |
| Punchboard, one punch | 5 | wager | counter | Period chance game, already modelled; small prizes only |

### Mail order, from the back page

Coupons from a paper you own, posted here, delivered through **mail_catalog**.

| Item | Firm | Cents | Note |
|---|---|---|---|
| Felt bedpost pads | Slumberfelt | 50 | Quiets one bed |
| Tone bar | Professor Ernst | 200 | Comic; does nothing you can prove |
| Home cycle meter | Rastin-Pattern | 450 | Shows the line frequency |
| Earplugs, reorder | Otis & Son | 10 | Same as the counter |
| Room consent book | Fogarty & Keel | 35 | **world**, a joke you can own |
| Party-line manners | Arcade Toy & Stationery | 10 | **ad** |
| Answering doll | Arcade Toy & Stationery | 350 | **ad**; says six words |
| Schematics course | Albany Home Study | 100 | One lesson by post, per month |
| Sardines | Parcel Post Sardine Co. | 15 | The cat follows you for a day |

## Bodega & Notions

The 52 items in **game/data/kitchen/groceries.json** stay as they are, at their
live prices. Examples: milk 15, eggs 45, white loaf 9, rat-trap cheddar 32, Harukiya
shoyu 20, Peerless lager 12, Fall River sausage 30, ground coffee 45. Their stock groups
are dairy, meat, produce, bread, dry goods, tinned and drink.

Add the notions counter:

| Item | Cents | Kind | Group | Note |
|---|---|---|---|---|
| Receiving valve, sleeve of six | 100 | part | notions | **live**, Bible: beside the cigarettes |
| Needle and thread | 5 | goods | notions | |
| Shoelaces | 5 | goods | notions | |
| Safety pins, card | 5 | goods | notions | |
| Candles, two | 5 | goods | notions | |
| Cigarettes, pack | 13 | goods | notions | |

## Otis & Son

The 12 spices and bicarbonate stay at their **live** prices.

| Item | Cents | Kind | Group | Note |
|---|---|---|---|---|
| Prescription, made up | 50 | service | dispensary | resident errand, paid by slip |
| Earplugs, wax, pair | 10 | goods | counter | **ad**; Hum down, faults harder to hear |
| Carbolic | 15 | goods | first aid | **ad** |
| Clean rag bandage | 10 | goods | first aid | **ad** |
| Aspirin, tin | 15 | goods | first aid | |
| Cough syrup | 25 | goods | counter | |
| Sleeping powder | 20 | goods | counter | Used only in bed |
| Soda, at the fountain | 5 | consumed | fountain | a stool and a minute |
| Egg cream | 8 | consumed | fountain | |
| Licence queue lozenges | 5 | goods | counter | **ad**-based joke |

## Luncheonette

| Item | Cents | Kind | Group | Note |
|---|---|---|---|---|
| Coffee | 5 | consumed | urns | |
| Slice of pie | 10 | consumed | case | |
| Coffee and pie | 15 | consumed | case | **ad** |
| Egg sandwich | 15 | consumed | griddle | |
| Blue plate | 35 | consumed | griddle | changes by weekday |
| The Melancholy Special | 40 | consumed | griddle | **JF016-A01** |
| Yesterday's rolls | 5 | goods | case | **live** |
| Gingersnaps | 10 | goods | case | **live** |
| Beef dripping | 8 | goods | back | **live** |
| Spent coffee grounds | 0 | goods | back | **live** |
| Soda, from the carbonator | 5 | consumed | fountain | **ad** |

## Model Laundry

| Item | Cents | Kind | Group | Note |
|---|---|---|---|---|
| Uniform, washed and pressed | 40 | service | none | Ready the next day |
| Shirt, finished | 15 | service | none | |
| Collar | 3 | service | none | |
| Bundle, wet wash | 25 | service | none | For resident errands |
| Mending, per piece | 10 | service | none | Lena's counter, per the owner's ruling |
| Unclaimed parcel | none | none | wall | Read and matched; not sold |

## Shoe Rebuilding

| Item | Cents | Kind | Group | Note |
|---|---|---|---|---|
| Half soles, leather | 100 | service | none | Durable, loud on terrazzo |
| Half soles, rubber | 85 | service | none | Quiet |
| Heels, rubber | 40 | service | none | |
| Shine | 5 | consumed | bench | Stand and wait |
| Polish, tin | 10 | goods | counter | |
| Laces | 5 | goods | counter | |
| Borrowed slippers | 0 | loan | counter | Until your boots return |

## Radio Service

| Item | Cents | Kind | Group | Note |
|---|---|---|---|---|
| Set alignment | 50 | service | none | Hand-tuned at the bench |
| Field printer paper, roll | 15 | goods | parts | |
| Printer ribbon | 25 | goods | parts | |
| Better aerial coil | 150 | upgrade | parts | Better reception |
| Lamp reflector | 75 | upgrade | parts | Better inspection lamp |
| Long-life valve | 35 | upgrade | parts | **ad**, Newark |
| Vantry parts, by order | job | part | parts | **ad** |
| Wet cell, service | 25 | service | battery | Topped and charged |
| Listening licence renewal form | 0 | goods | counter | **world**, no fee to read it |

## Photo Supplies

Canon: recording is cheap and photography is dear. Prices are high on purpose.

| Item | Cents | Kind | Group | Note |
|---|---|---|---|---|
| Single dry plate | 75 | goods | plates | Rare and deliberate |
| Plate, developed and printed here | 50 | service | darkroom | Or do it yourself |
| Darkroom hour | 25 | service | darkroom | The hand-rocked tray |
| Portrait sitting | 300 | service | studio | "An occasion" per the ad |
| Developer and fixer | 20 | goods | chemicals | |
| Printing paper, sheet | 10 | goods | chemicals | |
| Grease pencil | 5 | goods | counter | Adela's own |
| Negatives register | none | none | register | Read, never sold: **m_register** |

## Pawnbroker

Named objects, not groups. Mae runs the counter (owner ruling). The two wall cases are
empty until pledges fill them. Rate: an authored 3 percent a month. Current New York law
caps pawn interest at 4 percent a month; no period rate was found.

| Item | Cents | Note |
|---|---|---|
| Used valve | 10 | **ad**: "a used valve has seen things"; may hum |
| Second-hand Vantry service set | 750 | **ad**; a spare, not a replacement |
| Violin, in its case | 800 | Already modelled; a resident's dated pledge |
| Sewing machine | 900 | Already modelled |
| Telescope, collapsed | 500 | Already in the window |
| Pocket watch and chain | 350 | Already in the window |
| Field glasses | 600 | Already in the window |
| Coat, hanging | 150 | Already modelled |
| Folding camera | 1200 | Rare, as canon wants |
| Mantel clock | 400 | Static, per the existing rule |
| Wedding ring | 300 | A dated resident pledge; no joke |
| Radio chassis, dead | 150 | Parts |
| Your pledged objects | offer | About a third of value, 30 days to redeem |

## Funeral Parlour

Not a shop you buy from. It pays you.

| Item | Cents | Note |
|---|---|---|
| Setting and folding sixteen chairs | +50 | Paid per service; booked by date |
| Black armband | 10 | Worn only on a memorial day |
| Wreath, ordered for a resident | 150 | A gift in the existing care caps |
| Attendance book | none | Read, never sold |
| Adela's coat | none | Treatment item, no transaction |

## Harukiya

| Item | Cents | Kind | Group | Note |
|---|---|---|---|---|
| House lager | 15 | consumed | bar | On the slate |
| Whiskey, no questions | 35 | consumed | bar | |
| Sake, warm | 25 | consumed | bar | |
| Soda and bitters | 10 | consumed | bar | No loss of standing for choosing this |
| Rice crackers | 5 | consumed | bar | |
| Shoyu, bottle | 20 | goods | bar | **live**, the shop's own |
| Song session | 25 | service | stage | A paid slot on the stage |
| Darts or pool stake | 5 to 25 | wager | none | With a neighbour, capped per night |
