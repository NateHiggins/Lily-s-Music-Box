# What everybody carries

Evidence class: **INERT - DESIGN NOTE**

*Owner request, relayed 2026-10-25 by the entry-vestibule session: "we need
inventories for everyone, keys notably as well as groceries."*

## 1. One owner, one save domain

`PersonInventory` (`game/scripts/game/person_inventory.gd`) keeps what each
person carries. That is the player and every resident, keyed by holder id
(`player` or a resident id), in one domain: `RealityState.data.inventories`.
It is validated on load like every other domain. Nothing else stores carried
things.

| Thing | Id | Held by |
|---|---|---|
| A resident's original key | `key:<unit>` | that resident; housemates each carry one |
| A spare cut at Keys Cut | `key:<unit>:spare`, with `from` | the player |
| The house-service ring | `key:house` | the player |
| The player's own door key | `key:4B` | the player |
| Groceries on the way home | `grocery:<item>`, with `qty` | the shopper |

## 2. Keys

`DoorKeyring` still owns the **permissions** residents give for spares and
the **remembered locks**. It no longer stores who has which key. Instead it
answers every door from the holdings:
- **A resident opens** their door with a key they carry.
- **The player opens** a door with their own key, a spare, or the house ring
  for public doors.
- **Keys Cut** puts a spare in the player's pocket, marked with the resident
  who permitted it.
- **`revoke_copy`** takes the spare back and withdraws the permission.

`book()` still offers `originals` and `copies` for its readers, worked out
from the holdings.

**Migration.** `door_keys` moves to version 2 (permissions and locks). A
version 1 save seeds the holdings from it on first read: every resident's
original, plus every spare it recorded, placed in the player's pocket.

**Protection.** A save is refused if:
- a resident has lost their own original
- the player carries a spare nobody permitted, or permitted by someone else

## 3. Groceries

A shopping trip (`design/ORISON_KITCHENS_2026-10-24.md`) now moves goods
from the counter into the shopper's bag, and from the bag into the household
larder when they next arrive home, logged as *unpacked*. While goods are in
the bag they count as had, so nobody goes back for them. They are not in the
larder, so nobody cooks with them until they are put away. Mina's errands off
the map come home the same way.

## 4. Parts

Maintenance parts and tools stay with `MaintenanceInventory`: one grant and
one use per id, as before. The gas mantles (`gas_mantle_01..12`) are
unaffected. The inventory does not copy them. It reads the player's
unconsumed parts when it lists their pocket.

## 5. The pocket

The caretaker notebook's POCKET page lists the player's holdings
(`PersonInventory.pocket_lines`), followed by any copy still authorised at
Keys Cut:
- the key ring: house service, 4B, and each spare with whose it is
- anything they are carrying
- every unused part

## 6. Not done

- No one lends a key or hands one back yet. `hand_over` exists for it, but no
  conversation uses it.
- The player buys no groceries.
- Carried things have no weight and take no place on the body.
