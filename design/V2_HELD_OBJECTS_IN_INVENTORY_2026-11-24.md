# Held objects live in the inventory, shown on the hand

Evidence class: **INERT**. Owner direction, migration history and current scope.

Owner direction, 2026-11-24: "in general pick up able objects like kitchen utensils
shouldnt be carried, put it into their inventory and use the clothing system to put the
object in their hand model not as an actual game object."

## 1. What happens now

A grip of kind **free** that is not marked **pickup: false** is a carried pickup
(**constrained_grab.gd**, **holding_pickup**). While it is held, the world body follows
the hand every physics step (**follow_holder**, called from **PlayerController._physics_process**).
Collision exceptions bind it to the player, and motion tests cast it against the room.

Free pickups on main at **d919106ac**:

| Owner | What is picked up |
|---|---|
| **orison_v2_kitchen_prep_station.gd** | 30 breadboards, rolling pins, bowls and sink boards in 18 kitchens |
| **v2_library_movable.gd** (and readable books) | Library books |
| **basin_plug.gd** | The basin plug |
| **fire_line_gasket.gd**, **fire_loose_union.gd** | The spare gasket and the loose union nut |
| **fire_unracked_hose.gd** | Unracked hose parts |
| **night_register_hand_controls.gd** | The register pen |
| **orison_v2_water_closet.gd** | One loose closet part |

Not pickups, and unchanged: parts already constrained in place (bath, switchboard plugs,
**pickup: false**). Levers, drawers, doors, keys in locks and threaded couplings are
operated where they stand.

## 2. What the direction asks for

- **Taking an object** moves it into the holder's inventory and retires the world copy.
  The world copy is hidden with collision off, kept as its owner's record, not freed.
- **The held look** comes from the clothing system. **resident_wardrobe.gd** wears parts
  skinned to the same skeleton in five slots (bottom, top, over, feet, head). A held
  object becomes a sixth slot, **hand**: a part weighted wholly to the hand bone, loaded
  only while worn. The player's body is the doodle avatar (**doodle_player_avatar.gd**),
  and residents use their cast bodies. Both carry the same slot.
- **Putting it down** keeps it in the inventory (Lily, **held_put_down_20261124**: "It
  stays in the inventory until you use it somewhere"). The hand slot is emptied and the
  item stays packed in the carried case.
- **Using it somewhere** is what returns it to the world. For a kitchen tool that is its
  own station: with the tool in hand, a primary click on the station puts it back at its
  authored rest. Other uses (a rolling pin at another kitchen, a plug in another basin)
  are later slices.
- **Saves:** the carried case owns where the item sits in the case (item
  **kitchen_tool:<station>/<assembly>**). The station's saved mechanism marks the tool
  **stowed**, so a reload never shows both copies, and the household state refuses a save
  where the two disagree. What is in hand is saved with the case.

## 3. Choices for Lily

Answered 2026-11-25: **held_put_down_20261124** (it stays in the inventory until used
somewhere) and **held_scope_20261124** (all of them, kitchen tools first, then books, the
plug, the pen, the fire maintenance stock and the closet part). The first-person answer
came through as "i answered", so it was filed again as **held_view_first_person_20261125**,
answered 2026-11-25: the rubber-hose arm is the first-person hand ("let erryone know the
rubber arm is the solution"). In first person a held object shows in the arm's glove
(PR 553), on the arm's render bit (1<<13), taken from **first_person_hose_arm.gd**
**LAYER** rather than written as a literal; bits 1<<16 and up belong to the lamp's depth
isolation. The avatar's hand slot (1<<15) stays the mirror view and does not come into
first person. The arm's owner adds a **GloveSocket** on its Hand bone; this order then
wears the held part there as a follow-up once both changes are on main.

The glove follow-up (2026-11-25, after the arm and slice 1 reached main): the avatar
keeps a second **HeldHandSlot** on the arm's Hand bone, offset to **palm_offset()**, on
the socket's layer, and calls **set_holding** whenever the case's hand changes, so the
arm carries the glove in at its carry pose. The item is drawn at world size with no
shadow. While the glove works a world grab, the item stays in hand but is hidden, and
it shows again on release. The arm's own file and motion are not touched.

Answered 2026-11-25: **held_tethered_parts_20261125**. The basin plug, register pen,
union nut, unracked hose, cistern lid and spare gasket stay worked where they stand,
with no inventory. They are tethered parts, not carried pickups. The order then covers
the kitchen tools and books. Also answered 2026-11-25: **held_books_reading_20261125**.
A book goes into the case and the hand. To read it, the player clicks it in the glove,
and it comes up into the same close reading view. A click on a shelf puts it back in
that shelf's next free place.

The books slice works as follows. A click on a closed copy, on its shelf or lying loose,
commits it to the case and the hand at once, with no carry. A primary click with a book
in the glove and nothing usable under the reticle takes the place of the put-down. The
copy comes out at the glove's hold. The ordinary reading view takes it there, from the
camera's own pose, and the cover is opened by hand as before. Closing the view (Space)
closes the book and packs it again. Its save record stays the packed, closed one
throughout, so a save while reading keeps it in the case. With a book of that shelf in
the hand, a click on the shelf or its stock puts the book back. It goes to the first
slot, in shelf order, that is free and that the closed copy clears. Only its own
collection takes it back. The case view's "take in hand" now sets the hand, where
before it unpacked the book into a carry. When the case has no room, a closed copy
stays where it is until the player frees space. Shelves built without the household state,
such as the library benches, keep the old carry. To empty the hand of a book without
shelving it, the player takes another item in hand. A click on nothing reads the book
rather than putting it down.

Originally filed, recommended option first:

- **held_view_first_person_20261124:** what the player sees in first person while holding
  something. The avatar is drawn only in mirrors today.
- **held_put_down_20261124:** where a put-down object goes.
- **held_scope_20261124:** which objects move to the new rule first.

## 4. Implemented scope

- PR #571 installs the player glove and mirror hand for packed kitchen tools. The
  installed 2A route verifies pickup, return and saved custody through the existing
  household and carried-case authorities.
- PR #576 installs book pickup into the case and glove, same-copy reading and shelf
  return. A full case leaves the closed copy in place.
- PR #577 shares the held-item binding between the two player rigs and qualifies it
  with the installed Toon Lily avatar.
- The basin plug, register pen, union nut, unracked hose, cistern lid and spare gasket
  keep their existing hand-follow motion under **held_tethered_parts_20261125**. The
  shared grab path remains in service for those tethered interactions.
- Resident inventory presentation is a separate cast integration task. Installed
  player proofs cover the kitchen tool and book paths.

## 5. Not decided here

- The hand bone each body uses. The cast and doodle skeletons may differ, and the parts
  must be authored on the right skeleton (Blender, RUL-006).
- Held-object art. Each object needs a wardrobe part: a small skinned copy of its mesh,
  which must meet the UV, PBR and mipmap requirements (RUL-012).
