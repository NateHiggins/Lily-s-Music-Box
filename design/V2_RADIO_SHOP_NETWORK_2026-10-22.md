# Radio settlement and a small working cast

Evidence class: **INERT**. Research, owner-directed fiction and implementation
notes; this document grants no space, interaction or runtime acceptance.

REPORT - V2-RADIO-SHOPS - 2026-10-22

## Direction and historical boundary

The owner requires all shops and points of sale to communicate financially
with the handheld over radio, minimizing dedicated shopkeeper characters and
employing existing residents when a person is useful. This applies to the
hardware-store hose supplies and the street picture booth as well as retained
shops. It does not authorize deleting existing witnesses or case authorities.

CANONICAL historical references: the Federal Reserve used book transfers and
telegraph messages, leasing a dedicated system in 1918; automation came later.
That supports account settlement as a period idea, not an assertion that
unattended radio retail existed in historical 1928.
[Federal Reserve History, Fedwire](https://www.federalreservehistory.org/essays/fedwire).
WWV broadcast agricultural market reports in 1920–21 and standard frequencies
in 1923. This informs a separate commercial signalling channel and calibration
practice; it does not supply an early digital payment protocol.
[NIST, WWV history](https://www.nist.gov/pml/time-and-frequency-division/time-distribution/radio-station-wwv/history-radio-station-wwv).
The Smithsonian preserves Horn and Hardart automat/lunch-room records beginning
in 1912: self-service retail has a contemporary institutional lineage.
[Smithsonian collection](https://americanhistory.si.edu/ar/collections/archival-item/sova-nmah-ac-0922-ref523).

ADAPTATION, invented for this world: **Queens Mutual Radioclearing**, a merchant
cooperative founded in 1909, uses leased switching rooms and neighborhood radio
relays. Shop receivers exchange short addressed tone bursts with the service
set. A daily punched validation strip and sealed subscriber contact identify
the terminal and account. This is intentionally advanced signal apparatus under
Bible VIII.2, not historical cryptography or a modern internet service. Vantry
made compatible sets before its 1924 disappearance; the cooperative maintains
the network independently. Relays, paper accounts and repairable terminals
remain visible infrastructure, with no invented screen on the handheld.

## Purchase behavior

The player selects actual stock or a mechanical selector. The terminal presents
item, quantity and price on a physical plate and the existing field slip. A
short bounded pull of its settlement lever authorizes the quoted transaction;
releasing an uncompleted pull cancels it. Browsing, lifting or inspecting an
unpaid object does not silently bill the player. A terminal releases its parcel
or service latch only after settlement. The same primary-grab, mouse-motion,
next-click-release contract applies. A small mechanical flag and relay click
are enough feedback; no checkout menus or repeated confirmation prompts.

The handheld's existing radio switch is authoritative. Radio off, unavailable
terminal, invalid quote, insufficient funds or a blocked save refuse the sale
without charging or delivering. No asynchronous network wait blocks movement.
A transaction identity prevents retries and save/reload from charging twice.
An interrupted acknowledgement retrieves the same result, rather than creating
a second purchase. Busy/disconnected fiction should be rare and legible, not a
random shopping minigame. Use cached/event-driven radio state, not per-frame
visibility scans. Hours and physical shutters remain the existing shop owners'.

**CaretakerEconomy** remains the single money ledger; **MaintenanceInventory**
remains the owner of acquired/consumed maintenance stock; **WorkOrders** retains
requisition legality. Approved building parts use the existing work-order
authorization and a building-account receipt; they must not become unaffordable
personal purchases. Optional service supplies currently have authored fictional
prices: protectant bottle 25 cents, spare gasket 10 cents. No new wallet,
interest, loans or resident relationship score is introduced.

## Staffing edit

Unattended settlement is the default across bodega, hardware, news, laundry,
shoe repair collection, keys, photographic and radio supplies, pawnbroker,
luncheonette, Otis counter and picture booth. A machine can settle and release
stock; it cannot cook, cut keys, repair shoes or appraise an object by itself.
Prepared goods, labelled collection drawers and booked service work distinguish
immediate purchases from fulfillment. Retain existing bar hospitality and any
authored human witness, rather than creating a replacement clerk per shop.

Use the same scheduled resident actor, never a duplicate employee body:

| Existing resident | Useful paid work | Boundary |
|---|---|---|
| Omar Bell, repair technician | radio-service bench and occasional hardware apparatus service | preserve his repair case and home workbench; one scheduled location at a time |
| Iris Bell, painter | limited hardware paint mixing/colour consultation | a short specialist shift, not a rewritten full-time identity |
| Mae Kessler, antiques appraiser | pawnbroker appraisal appointments | provenance judgement stays human; receipt machine only settles |
| Sacha Reed, photographer-documentarian | photographic processing/collection sessions | preserve their documentary work and case, no generic sales chatter |
| Lena Ortiz, seamstress | booked laundry mending/alterations collection | needlework, not invented shoe-rebuilding expertise |
| Cam Ortiz, bicycle courier | a shared restock/collection round | follow their existing courier work and motion arc |

These are selected implementation assignments, not a claim that schedules or
world animations have already changed. Reconcile them with the schedule and
archetype documents together, retaining protected conversations and existing
interlocks. A human appears for specialist work or an existing story reason;
ordinary payment never requires waiting for that person.

## Current implementation and verification

Branch **codex/v2-acoustic-topology**, starting HEAD **276e2ff4**; origin/main and
merge-base **21f0b1fc27ac8e25c8466fe1ed2ce64019ee7ede**. Shared tree remains dirty;
other hose work, import churn and unrelated untracked files are preserved.

New candidate radio adapter delegates debit/receipt to CaretakerEconomy and
delivery to MaintenanceInventory in the same saved state. A V2 shop extension
adds two explicit optional supplies without bypassing the capsule requisition
or creating a work order. The bottle is a reusable tool; the spare gasket is a
single-use part. Existing campaign inventory is deliberately not converted to
a general stacking framework in this checkpoint.

Diagnostic **stock_v1** passed 17 stock/inventory checks before the radio
direction. Retained **stock_v2** passes 27 checks including radio off, unavailable
terminal, failed fulfillment rollback, exact 35-cent debit, replay refusal,
insufficient funds, blocked save and JSON round trip. **stock_v4** adds a real
disk reload proving that debit, receipt and both inventory items survive
together (28 checks). The final diagnostic adds immutable receipt retrieval
after a lost acknowledgement. **stock_v5** retained a failed strict receipt
comparison after JSON converted cents to a float. The public receipt query now
normalizes integer cents; **stock_v6** passes all 30 checks, including immutable
receipt retrieval. The 22-check existing economy regression also passes.
Logs and wrapper receipts
are under **art/reviews/v2_fire_maintenance_20261022**. These are diagnostics, not
test-written runtime contracts or actual-input/world qualification.

The native bottle/tin candidate has five exported groups and 2,552 triangles.
The first render exposed restarted surface charts. The second build develops
the bottle's cylindrical/conical bands and keeps the label chart continuous;
its original failure and revised rendered review are retained. Loaded Godot
materials, physical purchases, bottle application and world placement remain
unqualified. The new service and radio adapter are not installed in the world.

Working-tree board **tmp/v2_radio_core_board** completed with 100 PASS, 9 FAIL
and 1 INCOMPLETE. This is not a clean merge-base comparison or merge approval.
Failures include the three new uninstalled canvas image imports, outstanding
surface qualification, spatial/profile bindings, unread candidate mesh/tent
metadata, the unregistered street viewer's inherited interaction census and
existing completeness checks. The core's optional-stock fields have zero new
reader findings; systemic reports zero new actionable violations. Original
board outputs are retained with the packet. Do not describe the whole tree as
green or claim the other candidate debt is repaired by this transaction work.

Open findings: all retained point-of-sale adapters still need the shared radio
path and physical lever migration; merchant terminal geometry, employment
schedules, actual-input purchases and interruption/save tests remain. The hose
bottle's direct application candidate is incomplete. Existing broad V2 work,
performance A/B comparisons and human acceptance remain open. No completion
ledger status changes are claimed. No owner decision is needed to proceed.

Last line: BLOCKED — qualification and world integration remain, not a request
for owner approval.
