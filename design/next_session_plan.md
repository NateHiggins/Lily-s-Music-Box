# Priorities — post-cast-arrival, the lobby pass, and the spine

Written 2026-08-02, after the merge that closed the lighting blocker, the
character dump landing (17 hero faces + harpy + oni, lamia still missing),
the opening lockdown, collision-validated pathfinding, and all 34 voice
takes arriving. Every suite is green. The governing document remains
`design/CLAUDE_LIVING_ORISON_EXECUTION_PLAN.md`; this brief sequences the
work in front of it.

## P0 — the vertical-slice spine (execution plan phases 1, 3, 5)

1. **Finish the first shift** (Phase 1): FirstShiftDirector exists and
   stages arrival; still owed are the two mundane teaching tasks (entrance
   lamp, radiator bleed) using the same verbs as supernatural work, the
   staged first shadow error, and `intro_complete` set/consumed so a fresh
   save reaches Mina's work order with no debug keys.
2. **Mina's performance layer** (Phase 3): voice is DONE (34/34, matched,
   playing). Remaining: her bespoke acting clips (listen, guarded,
   strained, deflecting, recognition, quiet, relieved — `strained` and
   `recognition` are already requested by the tree and no-op), gaze
   targets, and the six non-case interactions + three behavior reactions.
3. **Close the Mina loop honestly** (Phase 5): replace the time-clock
   "Visit Two" shortcut with a real shift boundary; trophy/track/witness
   aftermath on resolution.

## P1 — the lobby pass (user-directed, this week)

1. **Remove the old wood mailbank** — the generated `lobby_mailbank` asm
   in `gen_layout.py` (south lobby wall). The brass MailBankProp on the
   east wall is the real one now. Pipeline is finally uncontended:
   delete the asm + `F01_MAILWALL` marker, regen, rebuild glTFs.
2. **Remove + retool the title board** — the title-image plaque built by
   `maintenance_headquarters._build_plaque()` (south wall of F01_OFFICE).
   Pull it from the world; retool the concept before it returns.
3. **Foyer bench: functional and re-sited** — move to the other side of
   the entry door (gen_layout furniture), give it a sit affordance
   (resident `settle` role socket + player sit). Teresa's authored haunt
   `(3.4, -8.4)` IS this bench — move her haunt with it or she will sit
   on air.
4. **Wall-art placement audit** — walkthrough + user confirm a large
   misplacement family: art floating off walls, clipping openings, and
   crossing the mid-wall picture rail. Audit every FoundArtPass /
   character_wall_art / hallway_art placement against actual wall faces
   and the rail line; add a WalkTest-style assertion so regressions are
   loud (art quad must lie on a wall plane, not span the rail, not
   overlap an opening).
5. **Unique art per stair half-landing** — seven landings (B1..ROOF),
   each gets its own piece (extend the hallway-art catalog + atlas;
   landing walls are known geometry at the half-flight x=±2.31 line).

## P2 — walkthrough systemics (now unblocked — gen_layout is free)

1. **Blinds decoupled from windows** (~15 rooms, every floor) — one
   placement offset in the window-dressing pass. The walk's top blocker.
2. **WSTOR placeholder slab + cube** (F02–F06) — untextured geometry
   filling the west storage rooms.
3. Batchable trivia: floating faucets, towel bars across door trim,
   pendant-in-duct clipping, ceiling-height sticky notes, B1 laundry
   machines mid-floor, coal-room placeholder block.

## P3 — smaller carried items

- White decal quads (halls/corridors/roof sign/B1) — believed to be the
  wallpaper/story-decal passes still settling; re-render before fixing.
- Socket-prop labels render world-space and mirrored — should be
  look-triggered prompts (execution plan Phase 2 wants nameplates
  debug-only; same policy for these).
- Re-shoot walkthrough floors after fixes (`WALK_FLOOR=F0x`); the camera
  rig now dodges nested rooms.
- Lamia: still absent from the dump — drop the zip and the pipeline
  (`resident_hero_models.json` → `convert_dump_characters.py`) takes it.
- Canon-height mechanism: runtime scaling (current, user-directed) vs
  baking heights in the converter (parallel session's stated preference
  via the identity-scale test guard). Decide once, before more models.

## Standing state

- Case Network: all eight desk cases + conditional beats. Reality cases:
  Mina complete and voiced; Peter Wren is the sanctioned second case
  (Phase 6) — do not author cases 3–18 before he meets the bar.
- Mail: brass bank functional, upgrades flow through it (contact_mic
  gated on Mina repair one), letters land under doors.
- Start state: entries locked except 4B, cases unlock their units,
  residents home; debug lineup + LineupShot for cast inspection.
- Nav: collision-audited graph (352 bad edges cut), stairs proven.
- WalkTest, LightingAudit, ResidentCast, Mina, MailBank, RealityCase:
  all green as of this writing.

## Invariants (unchanged, sworn again)

gen_layout authors all coordinates; b2g() is the only conversion; never
hand-edit generated JSON/glTF; all suites green before every commit
(isolated-worktree verification when the tree is contended); fetch before
push; audio stays procedural except catalogued, attributed assets with
gdignored sources.
