# The detective wall at home: proposal

Evidence class: **INERT**. Proposal, 2026-11-06, from the owner's direction that day: "the valise is for
transporting objects, photos, evidence, papers and relevant comic book strips clippings that will go on the detective
wall of string and conspiracy theories strung up at home as part of the investigation." Nothing here is built. The
owner's open questions are in her rulings as **wall_place**, **wall_strings**, **wall_clippings** and **wall_photos**.

## The loop

1. **Collect.** Out in the building and the city, the player keeps what matters in the carried case: papers and
   comics bought at the stand, letters from box 4B, written finds from the clue carriers (all built, see
   `ORISON_VALISE_PAPER_POCKET_2026-11-06.md`), and small objects and photographs (not yet: see below).
2. **Carry home.** The case is the only way evidence travels. Nothing teleports to the wall.
3. **Pin up.** At home, the player takes a paper or object out of the case and pins it to the wall by hand
   (RUL-013: grab, move over the board, click to pin). A pinned item leaves the case and stays on the wall, saved
   where it was put.
4. **String.** The player grabs the end of the red string at a pin, carries it across the board and clicks another
   pin to tie it. Strings are the player's theory, saved like the pins.
5. **Read.** Any pinned item can be taken down and read as it is in the case.

## What the wall is, and isn't

- It belongs to the player's investigation, not the case system. Pins and strings are a new owner,
  **detective_wall** (positions on the board, and string pairs), and every pinned thing keeps its own owner:
  NewspaperCatalog for papers, PaperPocket for comics and finds, the mail box for letters, PersonInventory for objects.
- **The game doesn't grade a theory** (recommended in **wall_strings**). A string never grants knowledge and never
  closes a case: the mystery's authorities stay where the Bible puts them, and the wall is where the player thinks.
  This keeps it free of the dead-data trap (a wall that decides would need a reader for every pair).
- It is diegetic: a real board on a real wall, lit by the room, with real pins, paper and string (catalogue
  finishes, RUL-008/RUL-012), lettering only as Label3D.

## What has to exist first

| Piece | State | Needed |
|---|---|---|
| Papers, comics, letters, finds in the case | Built (valise branch) | – |
| Clippings | Not built | Cutting a column or a comic panel out with scissors at home (**wall_clippings**) |
| Photographs | A print keeps only its name | Keep the picture when it is printed (**wall_photos**) |
| Small objects (the glove scrap, a key, a button) | Goods on the case's shelf | A tag to pin, or a shelf under the wall |
| The board | Not built | A place (**wall_place**), a Blender board with cork, pins and string |
| String | Not built | A runtime curve between two pins, sag by length |

## Suggested order

1. The board in its place, with pinning papers from the case and taking them down. Saved positions.
2. Strings between pins.
3. Clippings (scissors), then photographs with their pictures, then object tags.
