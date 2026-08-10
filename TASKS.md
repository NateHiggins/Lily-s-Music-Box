# OPEN TASKS

The shared queue. Everyone working on Orison writes here — the main dev chat,
Codex, the arcade/compiler session, and whoever picks this up next.

**This is a list of open work, not a log.** Delete a task when it is done; git
history is the record. If a task is wrong, say so on the line rather than
quietly removing it.

## How to use it

- **Add to the bottom of a section.** Ids are permanent — never renumber.
- **Claim by putting your name in the line.** No name means unclaimed.
- **Section prefixes exist so two agents adding at once do not collide.**
  `D` decisions · `A` arcade · `S` studio · `M` materials · `H` housekeeping.
- One line each. If it needs a paragraph it needs a brief in `design/`.

---

## D — Needs a decision from the owner

Nothing below is blocked on effort; it is blocked on someone choosing.

- **D1** Studio: does the desk power up? A room the player can use is a system;
  a room they can only look into is a landmark. The layout supports either.
  *Blocks S1.*
- **D2** Studio: do the storage cages stay? Argued for in the brief, but it
  costs floor area.
- **D3** Studio: is the echo chamber's extra tail ever *heard*, or only measured
  on the reel?
- **D4** Studio: which resident is found down there, if any, and at what hour.
- **D5** Coarse-luminance threshold is **absolute** luma (0.02) — that is 2.6%
  relative on plaster at mean 0.70 and 13% on a dark floor. Perceptually
  backwards. Absolute or relative? Shared definition, so it binds both
  pipelines.
- **D6** Does **VIII.5.g retire "minigames"** as a frame? The ruling says there
  is no video game industry in this world, but the pool table, the darts, the
  can-stacking and "one minigame per landmark" are all still described as games.
  Pool and darts are 1927 pub games and survive untouched; the question is only
  whether anything *screen-shaped* may be a game, or whether every screen must
  be a received broadcast. Answer binds the bodega machine and everything after.

## A — Arcade / the signal parlour

Ruled in `ORISON_BIBLE.md` VIII.5.g. Docs: `game/docs/arcade_cabinets.md`.

- **A1** `.swcpkg` files almost certainly do **not** ship in an exported build.
  `export_presets.cfg` has `export_filter="all_resources"` with an empty
  `include_filter`, and `.swcpkg` has no Godot importer. Expected fix is
  `include_filter="*.swcpkg"` — **untested**. Export, install, confirm a cabinet
  still boots. Failure mode is a machine playing in graybox with no error.
- **A2** Nobody has played one. `arcade_panel.gd` is unproven in the hand: mouse
  capture and restore, ESC, `E`, and whether a 480×360 feed at 2× is aimable.
  Expect tuning, not repair.
- **A3** Machines never free their world. `set_live(false)` stops the board
  rendering but the built world stays in memory. Needs an unload policy on the
  same distance gate that governs `set_live`.
- **A4** Twelve live machines have never been profiled — twelve 3D worlds plus
  twelve phosphor viewports, gated at 9 m. Measure before adding more.
- **A5** Audio is undifferentiated: attract mode is silent and every machine
  shares one weapon report. The World Bible already carries a `sound_palette`
  per world and nothing consumes it. Probably the highest-value polish left.
- **A6** The held object is procedural GDScript built from `held_object`, not a
  compiled mesh shipped in the package like every other visual.
- **A7** `arcade_panel.gd` reads raw keys, bypassing Orison's input map — on
  purpose, so a cabinet cannot inherit the outer player's bindings, but it means
  no rebinding, no gamepad, no touch.
- **A8** Port drift: `game/scripts/arcade/swc_*.gd` is a deliberate *copy* of the
  compiler repo's runtime. Nothing checks the two have not diverged.
- **A9** Screen legibility at distance in the dark bar. Brightness floor on the
  feed, or accept it as atmosphere? Worth deciding rather than defaulting.
- **A10** Every spawned enemy is named `Enemy`, so Godot's rename-on-collision
  makes their degrade thresholds differ slightly. Cosmetic.

## S — Basement studio

Proposed in `design/ORISON_STUDIO_BRIEF.md`. Not canon until the owner rules.

- **S1** Author the studio and echo chamber in `gen_layout.py`. Studio in
  `B1_STORAGE_CAGES`, chamber in `B1_UTILITY`, clear height 2.62 m. Never
  hand-edit `building_layout.json`. *Blocked by D1.*
- **S2** Six new Blender assemblies: `mixing_desk`, `monitor_pair`, `patch_bay`,
  `control_glass`, `acoustic_drape`, `chamber_fitting`. Reuse the nine that
  exist first; check for an upright piano before authoring a seventh.
  *Blocked by S1.*
- **S3** Wire the chamber into the acoustic graph. Send and return cross
  `B1_ATRIUM` past the `room0_threshold`, so the return shares house wiring
  rather than a cable of its own. *Blocked by S1, D3.*
- **S4** Studio props and the dead-channel chore: pull the rack, read the
  schematic in the lid, find the dead valve, buy one at the bodega, return.
  *Blocked by S2.*
- **S5** Connect the studio to the Songbook as its capture half — the bar is
  where songs mutate, the studio is where a take is fixed. Ghost duets belong in
  the room that records. No pitch scoring. *Blocked by S4 and the Songbook's own
  order.*

## R — The street's shops

Built in `art/data/shop_interiors.py`. Guide: `design/SHOP_INTERIOR_BUILD_GUIDE.md`.
**The rooms are display cases, not spaces.** They were authored to be looked
into through a storefront; the owner wants them walked around in, by the player
and by NPCs. R2 needs a brief before anyone builds.

- **R1** Measure before resizing. Nothing records the *clear* floor left after
  fittings — only the gross bay. Interior width is the authored bay less the
  200 mm party-wall inset, so today: news **2.10**, radio 3.00, locksmith 3.40,
  druggist 4.10, pawn/funeral 4.40, diner/photo 5.00, hardware 5.20,
  laundry/cobbler 5.40. Depths run 4.0 (news) to 7.0. Player capsule is
  `BODY_RADIUS` 0.33, so a 0.66 m body needs ~0.9 m of aisle not to scrape.
- **R2** Enlarge and re-plan. **Depth is the cheap axis** — `SHOP_PLAN` cuts
  further into the block and nothing is behind the south row. **Width is not:**
  since `_south_street_wall()` makes every shop its own building, `x0/x1` drives
  the footprint, the void, the awning, the blade and the signage together.
  Two cannot grow backward at all — the diner sits in the Harukiya's mass
  (`nbr_s2`) and the druggist in `nbr_w` beside the Orison. *Needs the brief.*
- **R3** NPCs have no way in. Movement is anchor-to-anchor in
  `resident_routines.gd` — there is **no NavigationRegion3D or NavigationAgent3D
  anywhere in the project** — so "NPCs move around inside" means authoring venue
  anchors per shop, not dropping a navmesh. Overlaps #22 (favourite spots) and
  should be done with it rather than twice.
- **R5** Two things the re-plan must not break: the **181 per-shop buffers**
  (fittings falling back into floor-wide buffers is what made the bodega go
  black), and `ShopEntryTest`'s ruling that the NEWS CIGARS proprietor side stays
  inaccessible — that one is deliberate, so changing it must be a decision.
  Watch the street elevation too: **32.53 ms** after the door pass streamed 120
  doors (it was 47.11 when this was filed), so there is real headroom for
  fittings now — but it is still double the budget, so spend it deliberately.
- **R6** **Residents walk through furniture, everywhere, today.** `resident_nav.gd`
  builds its AStar graph from `fl["walls"]` alone and never reads a prop, so the
  router cannot see a counter, a shelf or a display case. Harmless while NPCs
  only cross open corridors; fatal the moment they are asked to move inside a
  fitted shop. R2's re-plan is wasted unless the router learns about fittings —
  and the fix is worth having building-wide, not just on the street.


## M — Materials and textures

- **M1** Supertiles and stable per-wall UV offsets. Explicitly **not** part of
  the plaster repair, which was fixed without them — an optional later
  anti-repetition enhancement, with a real VRAM cost to decide first.
- **M2** `family_mean_spread` is defined on the compiler side but has never run:
  one texture per material means no family to compare. If the planner ever emits
  texture variants, that gate is unexercised.
- **M3** Compiler textures are 128² at roughly 64 px/m, which is the deeper
  reason features come out large relative to the tile.

- **M4** **Texture appearance audit.** Not "do the textures exist" but *does each material read correctly at the size of the object wearing it*. Materials are triplanar in WORLD space, so a bad `meters_per_tile` shows as brick-sized grain on a doorknob rather than stretched UVs. Sweep the warehouse first (68 displays, 44 kinds, flat-lit, side by side — it is the instrument for this), then spot-check in situ under torch. Method and the four failure modes in `design/AUDIT_BRIEF.md`. *Audit only — propose fixes, change nothing.*
- **M5** **Codex — unify the material library authority.** Generate runtime
  material sets from the ingest/catalog contract, fence current visual locks,
  and fail on missing files, silent scale drift or shared-cache mutation.

## H — Housekeeping

- **H2** **`C:\FPSengine01` is not a git repository.** The entire compiler side —
  the world compiler, the providers, the arcade catalog build, the texture
  validation — is unversioned files on disk. `git init` and a first commit.
- **H3** `worldc clean --stale` has no test covering it.
- **H9** Nothing defends the **mail bank ↔ lobby clock clearance**. Measured
  today at 175 mm: the clock spans blender y -9.205..-8.735 and the bank's
  surround -8.560..-7.200, and they overlap in height (1.715..1.930), so that
  gap is the only separation. `MAIL_BANK_Y` is a Godot constant and the clock's
  `mount_along` is layout data, so either side can move without the other
  noticing. The mail-bank plan listed this assertion and it did not land.
- **H12** **Unused objects and systems roundup.** Both directions: code that never runs, and — the half that bites — live data resolving to nothing. Precedents to pattern-match: arcade cabinets once spawned unbound and did nothing silently; the flue markers carry `unit: "F02C"`, an id in no namespace. Propose removals, delete nothing; several sessions share this tree. Brief: `design/AUDIT_BRIEF.md`.
- **H13** **Logical placement audit.** Is each object placed correctly, and does it belong there. Convention traps are listed in the brief (door markers are the hinge jamb; pendant markers are ceiling anchors with a drop). Note placement cannot lean on the router to prove a route is clear — see R6, residents walk through furniture. Brief: `design/AUDIT_BRIEF.md`.
