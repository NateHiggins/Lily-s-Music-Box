# Resident keys and copied spares

Evidence class: **INERT**

The owner's October 1 request adds resident originals, permission for copies,
and locking/unlocking of manually operated hinged leaves. News Cigars starts
unlocked in V2. This is a gameplay and fitted-prop follow-up; the wider raw
architecture/infrastructure phase remains open.

## Sources and ownership

**game/data/resident_schedules.json** supplies the eighteen resident identities
and their existing apartments. **game/data/orison_v2_blockout.json** supplies
door-to-room relationships; the native **DoorProp.unit** remains the V1 fallback.
The caretaker holds the existing house/service access and the **4B** key.
Resident originals remain theirs. A resident's secondary key interaction records
permission for that apartment; permission alone supplies no spare.

**game/data/door_key_policy.json** explicitly permits the current residents to
authorize copies and sets only **SITE_SHOP_DOOR_NEWS_CIGARS** to closed/unlocked
for a fresh V2 world. The protected legacy layout and its generator retain their
historical initial-state contract. Saved player lock choices take precedence over
the V2 initial override. Explicit V1 rollback retains its authored initial state.

**DoorKeyring** validates and stores originals, permissions, copied spares and
semantic lock choices in the existing RealityState save. Compatible older saves
may omit this additive domain. Malformed records protect the save; read-only
state refuses permission, copy and lock mutations. Shared-apartment residents
retain separate originals while one authorized spare serves their apartment.

**DoorProp** owns physical leaves, moving collision, sounds and readiness. The
existing resident callers pass their resident identity. An original unlocks the
resident's own leaf for passage and restores its lock after closure. Motion
readiness, occupied-sweep checks and stale-close revision ownership remain with
the existing callers. A key cannot lock an open or moving leaf. All six existing
DoorProp kinds and the landmark entry inherit the lock behavior; controlled lift
mechanisms and hours grilles retain their own safety/service authorities.

**Keys Cut** uses the exact **storm_shop_keys_cut_counter_top** furniture record
and its existing shop cell, floor, counter and door. One source-sized interaction
area offers recorded permissions; the resident keeps the original and the
player receives one spare. The existing PassageHoursDirector refuses service
after hours, including when a menu opened before closing. No new price, stock
ledger, quest gate or shop-hours owner is introduced.

## Controls and fitted asset

Aim at a resident and press **K / D-pad Up / touch KEY** to ask for permission.
Use the same key action on a closed door to lock/unlock it. The ordinary **E**
interaction still opens/closes the leaf and opens the copying counter's menu.
The menu accepts the existing activity commit and cancellation controls; closing
releases movement and restores the pointer. The pocket notebook lists authorized
and held spares. The key prompt occupies a separate line on the carried paper.
The existing **L** lamp and controller **Y** jump bindings remain unchanged.

**art/blender/scripts/build_resident_key.py** creates editable
**art/blender/resident_key.blend** and **game/assets/props/resident_key.glb**.
The approximately 60 mm warded key has a pierced bow, stem and restrained wards,
350 micrometre filed edges, applied transforms, active metre UVs, normals and
tangents. It uses the existing **brass_dull** catalogue maps. No lettering is
baked. Two keys rest on the original counter; the same asset turns briefly in
the actual lock on its appropriate face. It introduces no collision owner.

Directly inspected **tmp/resident-keys/review-fit** frames show both apartment
lock faces and the counter pair under production lighting. This close review
uses a moved observer/camera and proves fit, not traversal. The continuous route
frames in **tmp/resident-keys/views4** show the readable permission menu and
paper prompt; subsequent candidate runs must bind final source and receipts.

## Checks and boundaries

The focused resident-key suite exercises all eighteen originals, wrong-owner
refusal, permission-only refusal, copying once, retained originals, actual door
motion/relocking, six leaf kinds, the landmark, V2 initial News state, V1 state,
chosen-lock reconstruction, malformed/read-only saves and actual isolated disk
reload. Its provisional run reports **322 checks / 0 failures**.

The production route reports **84 waypoints / 0 failures**: normal arrival and
stairs, Mina permission, continuous street/arcade approach, actual Keys Cut menu,
closing-hour refusal, one copied spare, News lock/unlock from both sides with
keyboard/controller/touch input, continuous return to the private threshold and
operation with the copied key. It writes a schema-2 **runtime_contract** after an
isolated actual save and fresh production-world reconstruction, then measures
retirement of runtime nodes, new door/counter shapes and their door voices.
Shared imported resource caches are outside that resource measurement scope.
This scoped contract does not promote the wider completeness ledger.

The eighteen identities receive originals in both builds. The currently composed
V2 physical resident route remains Mina's; this change does not claim eighteen
new physical V2 character routes. Existing V1 resident actors use the same key
permission and original-key methods. Existing schedule, case and conversation
owners remain in place.

Spatial classification appends sixteen individually reviewed source/fixture
references, preserving the previous 6,315 entries. The interaction census adds
exactly the new same-node Keys Cut counter; its smoke counts increase by one
with explicit owner assertions. Carrier audit baseline and audit logic remain
unchanged. Final clean-candidate gates, protected-path comparison and bound
regressions are required in **tmp/resident-keys/verified/verification.json**.

## Previous batch publication

The receiving implementation **7c2e35825df0b3827134739ac3c1c97448f4e3ec** is
verified and pushed on canonical main. **tmp/bodega-receiving/verified/verification.json**
records zero gate regressions, reader NEW **0**, unchanged protected **17/17**,
selector **v2** with V1 rollback, and seven successful bound suites. The complete
clean baseline for this key batch is **tmp/bodega-receiving/7c2e358-clean-board.json**.
All six architecture/infrastructure buckets still carry their production-map
queues; keys do not close those queues.
