# The valise's paper pocket

Evidence class: **INERT**. Feature note for the carried case's paper compartment, built
2026-11-06 at the owner's request ("a compartment to valise for storing and viewing newspapers,
comic books and various paper sized pieces of evidence"). It records what the code does and what
is still open. It proves nothing and promotes no requirement.

## What it is

The carried case holds the papers the player has collected or bought (the owner, 2026-11-06). Its fixed body
carries three containers in front of the existing linen panel, built at runtime from the case's own catalogue
finishes, with papers standing in them, tops showing, each with a typed tab (Label3D; no lettering in textures):

- **The evidence folder**, left: a manila folder (paper finish) for loose evidence: every letter taken from box 4B,
  and every written find a clue carrier gives (its service note, kept instead of printed once).
- **The newspaper pocket**, right: the one newspaper being carried (the owner, relayed by Codex, 2026-11-06: the
  valise holds exactly one newspaper at a time). The stand refuses a second before any charge, stock or collection.
- **The comics pocket**, in front of the newspaper pocket and lower, so both rows of covers show: LILITH issues
  bought at the stand.

Nothing about the asset, its materials or the goods grid changes, and papers take no squares: the shop proposal's
rule that a full case cannot block a job or the mystery holds.

## How it is handled (RUL-013)

With the case open, the cursor finds a paper's showing edge. A click takes it, upward pointer motion draws it out
(it tips toward the reader as it comes), and drawn most of the way out it is held up to read. A newspaper opens as
itself in the existing `NewspaperPanel` (corner turning and coupons work as at the desk; ESC hands it back). A letter,
a find or a comic's cover opens on a plain sheet (`PocketPaperPanel`). The next click lets it go and it slides back.
A part-way draw reads nothing. The case keeps the pointer and the player's lock throughout.

## What is in the case

| Paper | Owner | How it gets there | How it leaves |
|---|---|---|---|
| The newspaper in transport | **paper_pocket**.news (one key) | Bought at the stand, inside the sale's settlement | Slid by hand onto the stack beside the 4B bookshelf (`NewsStackProp`) |
| Kept newspapers at home | NewspaperCatalog (every kept issue) | Deposited from the case | Read from the 4B shelf archive, which never empties the case |
| LILITH comics | **paper_pocket**.comics; issues in `game/data/comics.json` | Bought at the stand through its own menu entry, five cents (item **lilith_comic**), inside the sale's settlement | Never |
| Letters | The mail box's `mail_taken`; text from `mail_catalog.json` | Taken from box 4B | Never |
| Written finds | **paper_pocket**.evidence (id, title, body) | A clue carrier's find (`clue_draw_prop`) | Never |

LILITH is on the rack from each issue's Saturday (Nos. 1 to 6, 9 February to 16 March 1929), by the owner's
rulings that the stand sells it and that only the script, never the private art, is in this repository; the cover
shown is lettering only. The save validator checks **paper_pocket** (version 1; news keys, known comic ids and
well-formed finds).

## The stack at home

`NewsStackProp` stands on the floor in front of the 4B bookshelf. It is every kept paper except the one in the case,
drawn as piles of folded newsprint, 120 to a pile, each pile one box whose height follows its count: no object per
issue and no cap on the archive. When the case holds a paper it waits on the stack's front edge; a click takes it,
motion slides it square onto the pile, and there it leaves the case (RUL-013). An older save that carried several
papers keeps the newest in transport; the others are already kept and stand on the stack.

## Sales

The stand sells papers and comics through `ShopSales.transact_delivering`: stock, the exact debit and custody change
in one settlement, or not at all (short cash, no stock, a duplicate comic, a full transport slot).

## Held open

1. **Comic pages.** The cover is read; the pages are not drawn in the game, because the comic's art
   stays outside this public repository. How an in-game issue's pages are drawn is an open question.
2. **Photographs** keep no image (the photo counter stores a name only), so a print can't stand in
   the folder yet.
3. **Mail text encoding.** Several letters in `mail_catalog.json` carry mis-encoded dashes
   (for example the welcome note); the pocket shows them as the box does.
4. **Gamepad.** Like the rest of the case, the pocket is mouse-only.

## Verification

`PaperPocketRouteTest` drives the production V2 root with real input: a bought paper and two
taken letters stand in the pocket, front first; a full draw reads the letter that was taken; the
next click lets it go and the case stays open; a part-way draw reads nothing; the newspaper opens
as the one bought and ESC returns it; the 4B shelf files the pocket's papers and keeps them; the
letters remain; a malformed record is refused.
