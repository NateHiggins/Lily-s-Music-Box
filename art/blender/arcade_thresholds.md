# Retained arcade shop threshold survey

Evidence class: **INERT**

This extends the composed-city inspection to all eleven retained shop entries.
It changes route coverage and documentation, with no replacement shop asset,
floor, grille, door, lamp, hours rule or simulation. The wider raw-architecture
and infrastructure phase remains open.

## Ownership and dimensional boundaries

**art/data/shop_interiors.py** and **art/data/gen_layout.py** remain the
authorities for the eleven imported shop cells. Both protected layout copies
retain their exact bytes. **orison_v2_passage_region.gd** mounts thirteen cells,
including passage and eleven shops, plus the separately retained gateway.
**DoorProp** owns each marker-derived moving leaf. **PassageHoursDirector** owns
ten night barriers and the hardware exception, security lighting and cart locks.
The actor identities persist while imported shop geometry retires/reloads.

The imported source uses **GameBoot.b2g** and translation world Z **-9.795 m**.
Sales floors finish at **0.01 m**, on **0.06 m** slabs; shop clear height is
**3.30 m**. Marker leaves are **0.95 m** wide and **2.10 m** high. Source yaw
and hinge placement remain unchanged. The laundry and diner start parked open
at **168 degrees**; their public faces can close that pose before ordinary
**100-degree** opening and inside closure. Normal operation and source parking
are separate poses, both retained by the survey.

The source counters, display backs, stools and shelving define customer space.
In particular, the diner's **17.60 m** world-X turning stance stays on the
customer side of the stool row starting at **18.16 m**. Moving to generic
**18.30 m** struck that actual stool collider; the failed discovery is preserved.
No fitted furniture was moved or collision bypassed to make a test pass.

The rear borrowed-light strip is **2.35..3.05 m** above the floor. Source
**Check 3** explicitly makes the **2.60 m** rear rooms view-only. The funeral
chapel earns a floor opening but retains its chancel rail. Painted service-door
panels are shallow presentation on a solid party wall. These are intentional
boundaries, not missing player-access leaves. No new rear route is invented.

## Normal input, closed hours and retirement

**OrisonV2ArcadeWestRouteTest** covers Model Laundry, Shoe Rebuilding, Keys Cut,
Hardware Paint and Funeral Parlour. **OrisonV2ArcadeEastRouteTest** covers the
Luncheonette, Otis & Son, News Cigars, Pawnbroker, Radio Service and Photo Supplies.
Both use one player from the Orison core, the actual street crossing and nave,
ordinary shop-door input, inside close/lock/unlock/reopen and continuous return.
The public approaches are shared with the existing passage purchase route.

The existing campaign advances monotonically from **20:00** to **03:00**;
reinitializing its clock mid-survey would invalidate durable shop cursors.
Actual physical grille rays verify all ten closed shops; Hardware Paint retains
night service. Physical leaf-shape queries additionally sample **0..100 degrees**
and the source **168-degree** pose against the active night barriers without
moving actors or disabling colliders. Return reaches the actual core, waits for
retirement and checks that operated leaf identities/poses and shop simulation
survive. Stopping at the prefetch edge is insufficient to prove dormancy.

Provisional complete routes report **68 west / 76 east waypoints**, zero failures,
in **117.17 / 122.68 s**. They remain within the approved **180 s** serial ceiling.
The added grille-sweep checks require final candidate binding. Before those
complete, **tmp/arcade-thresholds/west.log.receipt.json** and **east.log.receipt.json**
are provisional suite-run receipts; they grant no ledger runtime proof.

Player-height shop/rear-volume and night-frontage captures are under
**tmp/arcade-thresholds/west** and **east**. Inspection temporarily hides only the
isolated held-device overlay; the standing player, practical world lighting,
light mask and collision remain. It introduces no inspection fill lights.
The batch adds no production geometry or asset bytes, so it makes no new render
cost/FPS claim. Existing coarse stock and trade props are retained simplifications.

## Preservation, gates and next queue

The complete clean baseline is **tmp/resident-keys/693000c-clean-board.json**.
Final checks belong to **tmp/arcade-thresholds/verified/verification.json**:
zero regressions and reader NEW **0**, protected **17/17**, V2 with V1 rollback,
double imports and bound shop/connected-world regressions. Three individually
reviewed spatial references append to the previous **6,331** records; the audit
logic and existing classifications remain. Completeness counts stay
**[7,8,127,42,151,153]** with no promotions.

Threshold and closed-hours coverage now spans every shop. Full customer-floor
and specialist apparatus reach, shared roof/support details, wet/electrical
connections and service attachments remain separate inspection/fabrication work.
The existing bar, bodega receiving room, resident keys, gentler lamp, Dream/V1
boundaries and owner capture files remain preserved. No owner decision is needed
for this survey; continue the shared-infrastructure and other location queues.
