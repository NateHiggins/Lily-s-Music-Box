# V2 bodega overhaul: audit against current requirements

Evidence class: **INERT**. An audit and work report, dated 2026-11-24. It records what
the street bodega (**SHOP_BODEGA**, "Bodega & Notions") does on main at **f736d3494**,
measures it against the standing requirements, and lists what was fixed on branch
**claude/bodega-overhaul-20261124** and what waits on Lily. Lane receipts for the
fixes are cited in section 6. Nothing here is artistic or runtime acceptance.

Owner direction, 2026-11-24: "we need to do an overhaul of the bodega to meet our
current requirements, do it."

## 1. What the bodega is

| Part | Owner on main |
|---|---|
| Shell, shelves, counter, cooler, labels, seven lights | **TEMPLATE_BODEGA_CELL_V1** in **game/data/orison_v2/exterior/exterior_geometry.json**, mounted by **orison_v2_exterior_cell.gd** |
| Fitted joinery (58 parts) | **orison_v2_bodega_fittings.gd**, **bodega_fittings.glb** |
| Storefront glazing and paired leaves | **orison_v2_bodega_frontage.gd**, **orison_v2_bodega_shop_door.gd** |
| Back receiving room, electrical service | **orison_v2_bodega_receiving.gd**, **orison_v2_bodega_power.gd** |
| Street sign | **bodega_signage_prop.gd**, refitted by **orison_v2_native_signage.gd** and **signage.json** |
| Sale point (selector, lever, slip) | **shop_sale_point.gd**, **radio_sale_terminal.gd**, placed by **orison_v2_shop_counters.gd** |
| Catalogue and stock groups | **game/data/shops/bodega.json** (notions, icebox, pantry; calendar deliveries), groceries from **game/data/kitchen/groceries.json** |
| Stock simulation | **orison_v2_shop_simulation.gd** (one-second poll of campaign time, no second clock) |
| Errands | **resident_conversations.gd**, **ResidentErrands**, **household_larders** |
| Resident queue and admission | **bodega_admission.gd**, **orison_v2_bodega_route.gd** (three waiting places, one service stance, a transit registry) |

## 2. Audit

### 2.1 Direct manipulation (RUL-013, RUL-018)

| Item | Finding | Status |
|---|---|---|
| Purchase | Selector slide and settlement lever are grabbed, moved and released; the refusal and receipt slips print on the handheld. | Complies |
| Counter-wide click volume | V2 keeps the semantic **MaintenanceShopCounter** but zeroes its collision layers (**v2_maintenance_shop_service.gd** line 83). The interaction audit's first reading missed the V2 subclass. | Complies |
| Storefront leaves | Directional passage through **request_passage**; primary click works the leaf; an open leaf without a return mechanism stays open. The "[E] Open door" text is shared DoorProp debt. | Complies (shared debt) |
| Sign | "[E] Inspect HALF BAKED shop sign" returns a click-for-card. It is in the carrier baseline and in **DIRECT_MANIPULATION_MIGRATION.json** as pending. | Legacy carrier, held for ruling **bodega_sign_period_20261124** |
| Selector length | About 60 stops on 0.10 m of travel at 16 px a stop. The route test had never moved the bodega selector by hand; it called **select()**. | Test gap, fixed (section 3) |
| List and bag | "Hand over the list, take the bag" (proposal section 5) is not built. The errand is a conversation topic and groceries become an inventory count. No forgotten-item check at the door. | Not built, ruling **bodega_list_and_bag_20261124** |
| Tutorial | None. The sale slip uses the field printer. Nothing teaches the selector-and-lever gesture. | Gap, low; authored slip text would be new writing |

### 2.2 Surfaces (RUL-012, RUL-008)

Static checks at **f736d3494**, all passing: **fix_runtime_texture_imports.py --v2 --check**
(1,260 textures, none to repair), **audit_glb_surface_uvs.py** on the five bodega GLBs
(0 failures), **v2_surface_evidence.py** (PASS, packet matches inputs) and
**audit_v2_surfaces.py** (PASS_TECHNICAL_ONLY). Of the inventory's 232 bodega draws, all
have UVs, no projection, albedo, roughness and normal maps, and all 101 textures have
loaded mips. A contact sheet of the 26 albedo maps showed no lettering. All lettering
is Label3D.

Two judgement items, both on the sign and both waiting on its ruling:

- The yellow backlit-vinyl valance takes the **milk_glass** recipe. The requirement bars
  standing a different substance on a generic tile.
- The two acrylic cabinet faces are primitive boxes with the default box layout rather
  than metre charts.

### 2.3 No prop physics (ruling of 2026-11-20, PR 443)

No RigidBody, impulse or unfrozen body in any bodega owner. Fittings, receiving room,
power and frontage are static. Crates, handcart, scale and cooler door are dressing.
Complies.

### 2.4 Shops (proposal, section 9 rulings)

The bodega's one job is "food and errands for residents". Built: catalogue, three stock
groups with calendar deliveries (milk daily, pantry every three days, notions weekly),
radio settlement, door errands with tips inside the caps. Not built: the list-and-bag
props, the forgotten-item check, produce thinning through the day, and Cam on restock
(ruling 3 says Cam restocks; deliveries are not yet carried by anyone).

The proposal's section 2 line "the Bodega counter has no collision in V2" was wrong:
**counter_case** and **counter_top** have had collision since the exterior cell landed
(**1da7dd68a**). Nothing needs rebuilding.

### 2.5 Period and text (1928-29, RUL-015)

- **The sign is modern.** **bodega_signage_prop.gd** builds "HALF BAKED / DELI · GROCERY ·
  OPEN 24 HOURS" on a backlit yellow vinyl valance, with a double-faced acrylic lightbox
  and a fluorescent tube that drops out every few minutes. Backlit vinyl, acrylic sheet
  and commercial fluorescent tubes all postdate 1929. The storefront refit plan's
  slice 6 (timber fascia, fixed canvas awning) and Lily's November 1 choices (linen
  cloth, dark green, no modern **awning_vinyl**) already describe the period front. The
  name and the hours on it are canon, so the replacement waits on ruling
  **bodega_sign_period_20261124**.
- **"WEST 138TH STREET / ORISON"** on the street return is editorial flag D7, already
  tracked by work order **w0e43f4d4f9bf** and the street-sign ruling. Not re-filed.
- **"NOTIONS · HOUSEHOLD · KEYS"** on the counter: keys are the Keys Cut shop's one job
  (proposal section 1). Ruling **bodega_counter_keys_20261124**.
- All text met is authored; no model writes or chooses any of it.

### 2.6 Performance (30 fps order)

| Item | Finding | Status |
|---|---|---|
| Sign | **_process** wrote the emission level to both cabinet materials every frame, lit or not. | Fixed: writes only when the tube changes state |
| Sale terminal | **_physics_process** ran every physics tick on every sale point in the game, returning early at rest. It missed the idle-physics pass. | Fixed: idle at rest, woken on release while off its stop |
| Stock simulation | One-second poll, whole-minute catch-up. | Fine |
| Lights | Seven template lights (two shadowed) plus two sign omnis and the receiving practical. Lily allows culling (2026-11-23). Not changed here: the sign's two omnis go with the sign ruling, and the interior set needs a rendered pass. | Deferred to the sign build |

### 2.7 Residents and queue

Bodega admission is in Codex's hands (case
**D:/ov_reports/orison_bodega_admission_intake_20261124**). Codex traced the full-queue
denial on main as legitimate: Cal holds the service stance while Noel, Peter and Rhea
hold the three waiting places, and the queue turns over in campaign time. Mae's stop
at the mid-block lamp is being fixed in public foot traffic, not in admission. This
branch does not touch **bodega_admission.gd**, **orison_v2_bodega_route.gd**, resident
routes, schedules or any main cast member's behaviour.

## 3. Built on this branch

### 3.1 Without a ruling

1. **radio_sale_terminal.gd**: no physics callback at rest; the hand's release turns the
   spring on while the lever is off its stop, and the spring turns itself off at rest.
   This covers every shop's terminal, not only the bodega's. Sale, refusal and
   settlement code is untouched.
2. **shop_counters_route_test.gd**: the real hand now walks the bodega selector to a
   grocery stop, and a ray from the terminal's foot holds it on the real counter
   collision. (The first version measured against the authored box and failed: the
   fitted counter stands in its place.)
3. The sign's per-frame emission writes were first reduced to state changes; the period
   sign below then removed the per-frame callback altogether.

### 3.2 From Lily's rulings of 2026-11-24

**bodega_sign_period_20261124.** **bodega_signage_prop.gd** now builds a painted
dark-green timber board and blade with gilt Label3D lettering, HALF BAKED · GROCERY,
lit by two shaded gooseneck lamps (steady SpotLight3D, no shadows) in place of the two
omni lights. The east lamp stands on the existing branch termination at the board's
top edge. No tube, no dropout, no **_process**. The card reads OPEN ALL NIGHT, the
period phrase the prop reference research recorded
(**tools/prop_reference/queries.json**). The native fit's indexed replacements 0-4 and
**signage.glb** are unchanged. The source plan gains an explicit mesh count of 13 (seven
fitted primitives and the lamps' six meshes), **signage_geometry.py** honours it, and
the finish moves to painted green with no emission. The runtime data, the test fixture
and its construction twin follow, and only the four files this branch changed are
re-bound in their source digests. The legacy palette maps the board to **door_paint**,
the arms to **iron_blackened** and the shades to **enamel_appliance**. New boxes carry
metre UV charts.

**bodega_counter_keys_20261124.** The counter lettering reads NOTIONS · HOUSEHOLD. The
geometry record is hash-bound (**SOURCE_GEOMETRY_SHA256_LF**), so the fittings owner sets
the words at mount and keeps the source wording in its retained meta.

**bodega_list_and_bag_20261124.**

- At the door, taking the list puts a written list slip (form card) in the carried case
  and prints it on the field-slip printer with a crude sack-and-counter sketch.
- Held off the case shelf within reach of the bodega counter, the slip offers LAY THE
  LIST ON THE COUNTER. This uses the same **ItemUse** hook as the pawn grille.
- Laid, the counter fills a paper sack line by line through the bodega's own
  **ShopSales** settlement, so stock, radio and ledger refusals hold. A refused line
  stays out of the sack. If nothing can be packed, the list stays in the case.
- **bodega_sack.gd**: the sack stands on the counter. The real hand grabs it, mouse
  motion lifts it, and lifted clear it goes into the case (form parcel). Released short,
  it sets back down. It has no physics body and no per-frame work.
- At the door the resident looks in the sack. A short sack is answered on its own node,
  **errand:short**: "That isn't all of it. Never mind, I'll manage. Thank you." The voice
  inventory reads it like the thanks and wait lines. The tip's completeness is the share
  of the list that came, inside the existing caps.
- Lists now keep to what the bodega sells, since 21 of the 73 larder ingredients are
  sold elsewhere and would always be short.
- Errands taken before this change have no stage and keep the old pocket path.

### 3.3 For Codex's intake

- No route, doorway, queue, admission, clearance or collision coordinate changes. The
  sack adds one manipulation area on the counter top, beside the terminal (sale-point
  frame **(0.34, 0, 0.02)**), and nothing a body can collide with.
- Authority changes: **ResidentErrands** gains stages and a sack record; **ItemUse** gains
  the bodega point; the runtime root mounts the sack. Purchase stays with **ShopSales**
  and the radio clearing; save validation accepts the two new optional fields.
- Cadence: sale terminals stop ticking at rest; the sign has no per-frame callback.
- Lighting: the sign's two omni lights become two unshadowed spot lights.

## 4. Rulings

All three were answered by Lily on 2026-11-24 with the recommended option.

| Id | Answer |
|---|---|
| **bodega_sign_period_20261124** | Painted dark-green wooden signboard, gold lettering reading HALF BAKED · GROCERY, two shaded lamps that don't flicker, open all night |
| **bodega_list_and_bag_20261124** | Written list slip, laid on the counter, the counter fills a paper sack, carried to the door, missing items noticed there |
| **bodega_counter_keys_20261124** | Drop KEYS: NOTIONS · HOUSEHOLD |

Work order **w2005ff86065f** tracks the build.

## 5. Not done

- The resident's new door line for a short sack and the list slip's printed sketch are
  first-draft authored text for Lily's playtest read.
- The case view is not driven by its own UI in the test; the test calls **ItemUse** as
  the case does, and drives the sack with the real hand.
- The interior light cull, Cam carrying deliveries, produce thinning through the day
  and a selector-and-lever teaching slip remain open.
- No render review of the interior's texture scale or grain beyond the captures cited.
- The full surface packet is not renewed here; Codex renews it at integration.

## 6. Verification

Runs from a short-path checkout at **C:/ov/bodega**, through **tools/lane.ps1**, with the
patched editor. Receipts: see the PR description, which cites each
**.receipt.json** by path.
