# Direct manipulation — owner ruling and migration contract

Evidence class: **INERT**. Binding design direction; no runtime acceptance.

Authority: owner, 2026-10-12. RUL-013, Bible §VIII.5.l.

## Player contract

The world is a fidget toy. A subtle cursor change identifies the actual operable
part under the aim point. Primary click takes that part, mouse motion operates
its physical constraint, and the next primary click releases it. This is a
latched grab, not a hold-to-drag requirement. Acquiring or releasing a part must
not itself snap the mechanism to an endpoint or trigger a hidden state toggle.

Doors and refrigerator leaves rotate about their hinges, drawers translate
along runners, and knobs rotate about their own shafts. Hot and cold faucet
knobs operate independently in their physically correct direction. Water flow
follows valve opening and available supply; it is not a boolean click effect.
Travel limits, obstructions, friction and detents are legible through motion,
sound and result. Partial opening is a real state wherever the mechanism allows
it. A spring or latch may return or retain a part according to its construction.

Selection follows the visible part under the cursor, including moving collision.
A grab holds that part's identity rather than retargeting as the cursor moves.
Mouse movement during a grab operates the constraint without uncontrolled camera
rotation. Release, lost reach, interrupted play or a destroyed owner safely ends
the grab. Avoid forced camera jumps when ordinary looking resumes.

## Teaching and narrative

Replace every minigame with manipulation of the actual world mechanism. Preserve
the underlying fault, inventory, work-order and case owners; outcomes come from
those owners observing real physical conditions. Remove puzzle overlays only
after their legitimate consequences have a physical replacement.

The cursor communicates availability and possession, not step-by-step recipes.
Any tutorial is an opaque handheld message or crude ASCII illustration. Use the
existing service radiophone's field-slip printer, consistent with the Bible's
paper grammar. Device power continues to govern its messages; operating a world
object must not require an explanatory message. Ordinary conversations and
authored inscriptions retain their existing voices.

## Implementation order and acceptance

The initial source inspection identifies these migration points:

| Existing owner | Required change |
|---|---|
| `game/scripts/player/player_controller.gd` | Replace the E-driven `use_primary_interaction` dispatch and explanatory prompt slip with shared part targeting, a latched grab and constrained motion. Keep protected conversation and seated-input ownership explicit. |
| `game/scripts/props/door_prop.gd` | Replace player-triggered endpoint tweens; retain key authority and the separate resident/NPC operation path. Claim the leaf while grabbed so a resident cannot overwrite the player's motion. |
| `game/scripts/props/fridge_prop.gd` | Target the main door, ice door and tray separately; drive their existing pivots/runners continuously while retaining inventory, light and possession ownership. |
| `game/scripts/props/tap_prop.gd` | Replace the hot/mixed/off click cycle and boolean-only valve output with independent continuous valve openings, authored shaft direction and flow-weighted mixing. |
| `game/scripts/props/dead_letters_prop.gd`, `darts_prop.gd`, `otis_prop.gd`, `point_ball_prop.gd` | These currently launch separate panels. Trace each panel's outcomes and preserve the activity as physical world operation before retiring its overlay. |

This is an initial source inventory, not a claim that every interactive prop or
minigame caller has been found. The shared contract should expose part identity,
constraint frame, travel limits, current value and owner-controlled begin/update/
release operations. A generic controller maps mouse displacement into that
constraint; each owner remains responsible for permitting and applying motion.
Do not create a parallel state store that disagrees with save or simulation state.

Tiny controls may supply a positive, finite **motion_scale** in their shared
grip descriptor. The controller multiplies its ordinary constrained mouse
displacement by this gain; omission retains the existing gain of one. The
porter-board keys use 0.025 so their four-millimetre stroke has useful partial
travel. Travel limits and contact conditions remain in physical units. Actual
input tests must apply the same gain when constructing mouse motion.

1. Inventory the shared input/target resolver and all interactive owners. Add a
   common constrained-grab contract rather than divergent drag logic per prop.
2. Migrate ordinary and entrance doors, refrigerator leaves and independent
   faucet handles first. Preserve NPC door use, locks, collisions, sound and
   actual save/reconstruction, including partial positions where appropriate.
3. Extend to drawers, cabinets, blinds, switches, valves and remaining service
   mechanisms. Audit minigame entry points and replace each with a physical task.
4. Replace production instructional prompts with the target indicator and the
   handheld teaching grammar. Accessible equivalent inputs use the same owner
   and constraint. Existing scripted tests must exercise the new player path;
   an old E-toggle route is not evidence of compliance.

Render and play representative installed objects from both sides and at oblique
angles. Prove selection, acquire-without-motion, motion direction, partial travel,
stops, release-without-snap, reach loss and interruption. Verify locked and blocked
movement, hot/cold independence and supply response, NPC ownership conflicts,
and save/reconstruction. Run one combined review after the batch is ready.

Current status: **ruled; runtime migration pending**. Earlier geometry/material
and navigation receipts retain their original scope. They do not prove this
new interaction contract. Do not promote any completeness requirement from this
document or describe unconverted click toggles as compliant.

## Owner extension, 2026-10-13

Space after grabbing an inspectable part enters its fixed mechanism view with a
free mouse pointer. Primary click still grabs/releases, and mouse movement still
operates the selected part. Space or Escape restores the prior camera; interrupted
inspection releases ownership. Inspection cannot auto-open a cover or repair a
fault. The toilet is the first inspection provider; other mechanisms require an
authored, unobstructed inspection view before they offer it.

The handheld is collapsed to its actual printed first line in the bottom-right
corner. E toggles the full instrument/message in the right third. This replaces
E's world-interaction keyboard binding. The carried flashlight uses a stable
supply without simulated contact chatter or impact-induced flicker.
