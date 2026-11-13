# The loops — first script packet

Evidence class: **INERT**. November 12, 2026. **Draft writing, not new canon.**

Eleven existing historical visits now have scene drafts. Eleven ordinary-life
vignettes and five supporting encounters give the wider cast practical business,
relationships, listening and exits. This is the writing delivery requested while
Fable prepares the performance outfits. **Pull Up a Chair captures remain on hold.**

The [NPC loop plan](../../NPC_LOOP_PERFORMANCE_PLAN_2026-11-12.md) remains the
implementation plan. These scripts use its baseline-plus-dated-overrides approach;
they do not create eleven duplicate days for every resident. The
[Bible](../../ORISON_BIBLE.md), particularly RUL-015/016, takes precedence.

## Read the scripts

| Packet | Scenes | Dramatic work |
|---|---|---|
| [Tea / Friday / Stairs / Button](TEA_FRIDAY_STAIRS_BUTTON.md) | Mae and Nadia; Cam; Teresa; Lena | A service visit becomes an investigation; the night leaves ordinary people with practical work |
| [Notebook / Drain / Drama / Bench](NOTEBOOK_DRAIN_DRAMA_BENCH.md) | Jonah; silent drain investigation; Cal and Juno; Omar | Separate what was heard, invented, recorded and physically recovered |
| [Duplicate / Plate / Box](DUPLICATE_PLATE_BOX.md) | Sacha twice; Mae | Let incomplete material narrow the case without supplying a confession |
| [Ordinary year and support](ORDINARY_YEAR_AND_SUPPORT.md) | Eleven ensemble vignettes; Emil, Ewald, Vantry, patrolman and the party | Give the house a life beyond the clue chain; preserve grief, testimony and the unexplained |

Each anchor draft contains exact source dates, ordered physical actions, carrier
copy, optional reused dialogue with node IDs, new connective lines, acting beats,
silent routes, interruption and expiry. Source text is still draft where its own
metadata says so. New editorial IDs are labels for review, not installed data.
The ordinary scenes have shared recovery rules and explicit access dependencies.

## Anchor spine

The source of this table is [anchors.json](../../../game/data/temporal/anchors.json),
not a new scheduling authority. Prerequisites must be earned/filed through the
existing wall and deduction owners. A scene's opening is not evidence of an open
door, eligible conversation or available actor.

| Visit | Local civil window in 1929 | Existing prerequisite(s) | Physical evidence |
|---|---|---|---|
| tea | June 13, 16:20–17:30 | None; first call free | order_slip |
| friday | July 19, 18:20–20:00 | order_slip | route_leaf |
| stairs | July 20, 03:02–03:40 | order_slip | nurse_note |
| button | July 20, 05:00–06:20 | nurse_note | button_leaf |
| notebook | August 6, 20:00–21:30 | she_asked_first | jonah_page |
| drain | August 7, 09:00–11:00 | nurse_note | glove_scrap |
| drama | August 24, 15:00–16:50 | jonah_page | disc_label |
| bench | September 23, 12:00–14:00 | the_glove | dark_slide |
| duplicate | October 18, 19:30–21:00 | she_asked_first, button_leaf | duplicate_negative |
| plate | October 29, 19:00–20:40 | the_reason | plate_half |
| box | November 9, 15:00–16:00 | the_glove, the_evening_was_made, the_reason, plate_half | kept_papers |

## Cast-by-visit writing coverage

**B — baseline:** inherit the actor's actual schedule/agenda and eligible ordinary
text, with the linked OY vignette only a proposed addition. This includes being
asleep, elsewhere, busy or absent at that hour; it does not assert actor presence
inside the anchor room. [Schedules](../../../game/data/resident_schedules.json),
[motives](../../../game/data/resident_motives.json), and the actor's files in
[dialogue](../../../game/data/dialogue/) and [mystery](../../../game/data/mystery/)
remain authoritative. Current route gaps remain gaps, not passing cells.

**D — dated override drafted:** use the corresponding anchor packet only when
attendance/access and the particular dialogue gate permit it; otherwise retain
the silent physical route and baseline. **C — conditional supporting encounter:**
some source dates overlap, but only its exact hour/flag/placement rules permit
delivery; no mandatory detour is added. **A — absent from this visit's new
performance:** the source scene's date does not overlap, or Adela is no longer
alive. This does not erase an independently valid ordinary-world presence.

Column order follows the investigation branches, not an imposed playing order.
All cells are writing dispositions, **not runtime coverage passes**.

| Actor / ordinary draft | tea | fri | stairs | button | note | drain | drama | bench | dup | plate | box |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Evelyn / OY01 | B | B | B | B | B | B | B | B | B | B | B |
| Teresa / OY02 | B | B | D | B | B | B | B | B | B | B | B |
| Mina / OY09, existing case only | B | B | B | B | B | B | B | B | B | B | B |
| Lena / OY03 | B | B | B | D | B | B | B | B | B | B | B |
| Juno / OY04 | B | B | B | B | B | B | D | B | B | B | B |
| Malcolm / OY05 | B | B | B | B | B | B | B | B | B | B | B |
| Omar / OY03 | B | B | B | B | B | B | B | D | B | B | B |
| Rhea / OY06; route gap retained | B | B | B | B | B | B | B | B | B | B | B |
| Peter / OY01 | B | B | B | B | B | B | B | B | B | B | B |
| Cam / OY02 | B | D | B | B | B | B | B | B | B | B | B |
| Noel / OY07 | B | B | B | B | B | B | B | B | B | B | B |
| Transient guests / OY08; route gap retained | B | B | B | B | B | B | B | B | B | B | B |
| Nadia / OY08 | D | B | B | B | B | B | B | B | B | B | B |
| Cal / OY04 | B | B | B | B | B | B | D | B | B | B | B |
| Iris / OY06 | B | B | B | B | B | B | B | B | B | B | B |
| Sacha / OY05 | B | B | B | B | B | B | B | B | D | D | B |
| Jonah / OY07 | B | B | B | B | D | B | B | B | B | B | B |
| Mae / OY10 | D | B | B | B | B | B | B | B | B | B | D |
| Stacy / OY11, actual staff shift | B | B | B | B | B | B | B | B | B | B | B |
| Lily / OY11, owner-review placeholders | C | C | C | C | C | C | C | C | C | C | C |
| Living Adela / OY11, other eligible source threads | C | C | A | A | A | A | A | A | A | A | A |
| Emil / SU01, July 22 only | A | A | A | A | A | A | A | A | A | A | A |
| Mr Ewald / SU02, later ew_note recovery | A | A | A | A | C | C | C | C | C | C | C |
| H. Vantry / SU03, November 2 only | A | A | A | A | A | A | A | A | A | A | A |
| Patrolman / SU04, July 20 03:40–06:00 | A | A | A | C | A | A | A | A | A | A | A |
| the_party / SU05, November 1–8 only | A | A | A | A | A | A | A | A | A | A | A |

Lily's C entries require an actual attendance/encounter contract and review of
each source thread, not a promise that a thread is open throughout each visit.
Adela's June/July C cells do not extend **av_set** past its own dates or hours.
Off-visit support dates are written in SU01–05, so all-A rows are deliberate
coverage rather than forgotten characters. The companion remains with its current
authored presentation/hint owner; no new clue, biography or Emil-scene commentary.

## Specific reconciliation work found while writing

These are implementation/editorial issues, not new decisions silently applied:

| Existing mismatch | Required treatment before performing it |
|---|---|
| tea starts 16:20; mk_tea opens 16:30; Nadia needs real attendance | Preserve physical access; deliver the conversation only through its source window and actor owner |
| Cold one-pipe steam radiator described as needing “bleeding” | Repair owner reconciles terminology; don't stage a hydronic procedure |
| stairs opens 03:02; note is dated 03:05; later testimony says 03:10; Teresa is in yard while carrier is in 1D | Reconcile chronology and actual travel; never manufacture a note or teleport the nurse |
| button starts 05:00; source testimony describes a 06:00 arrival | Avoid future testimony; eligibility needs an explicit reviewed fix |
| m_trade_log, m_boiler_sheet, m_o1_print and m_receipt_seen reachability unresolved | Audit their actual carriers; no dialogue or loop prerequisite may stand in for them |
| Drain carrier can transact before 09:10; anchor has its own time step | Keep the carrier transaction and loop evidence distinct |
| Bench prose says windows shut; windows.raise is 0.8 | Reconcile dressing before visual proof |
| Cal promises audible comparison; Omar promises to carry the plate | Identify real audio and supported custody handoff before literal performance |
| Plate readiness is 19:15; Sacha's darkroom starts 19:45 | Silent physical path remains independent; actor uses real schedule |
| Box visit ends 16:00; mk_box confrontation opens 16:00–21:00 | No early confrontation or expiry-triggered reveal; reconcile normal access separately |
| Loop clues/deductions differ from m_ / mt: knowledge | Preserve each owner, including heard-at-entry on interrupted dialogue |

WR-03 legal wording/reversion/August receipt, Mina's **mv_struck**, larger-conspiracy
answers and Lily's self-insert lines retain their existing holds/review boundaries.
The murder is reconstructed, never witnessed; the July 19 21:01–July 20 03:02
blackout remains universal. There is no recognition of the player's hidden identity,
new Mae confession, new date travel, runtime language model or automatic case award.

## Production handoff

1. Review these texts and reconcile the listed chronology/carrier issues before
   voice batches. Ordinary pairings need actual overlap; avoid adding routes solely
   to serve a line. Preserve the approved existing cast voice identities.
2. Owner rulings already require **Cal first for body/clip compatibility**, wardrobe
   changes out of sight; then one qualified Mae tea encounter. This prerequisite
   does not reorder the eleven narrative leads. Fable owns her cast/outfit files.
3. Implement one normal entry, silent path, interrupted root, departure, save/load,
   expiry and rerun under the existing owners. Voice completion cannot grant a clue.
4. Only after text/body/attendance qualification select takes, measure durations,
   derive lips from that audio and review native hands, gaze and listener reactions.
   Keep the film's capture hold and separate Harukiya gameplay gates intact.

**State:** 27 scene drafts assembled: 11 anchors, 11 ordinary vignettes, 5 support
encounters. Source/continuity review is an editorial pass only. Design lint, exact
source-quote checks, anchor contracts and local links are checked before committing.
No new dialogue is approved by Lily, voiced, integrated, technically verified in
game, played or artistically accepted. No runtime files, saves, source voices,
wardrobe assets or captures were changed by this writing delivery.
