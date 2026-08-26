# Claude production plan: build the shift, then polish the world around it

*Owner-directed product plan, rewritten 2026-08-13. This is the product-direction
authority named by `ORISON_BIBLE.md` §V. The Bible remains the authority for
fiction. This plan supersedes the 2026-08-01 execution plan.*

## 1. Product decision

The Orison is no longer developed as a collection of impressive independent
systems. It is developed around one repeated dramatic shift:

1. **A building problem becomes known.** The player either discovers it or is
   alerted by a resident.
2. **Diagnosis creates an errand.** The practical answer requires a trip to one
   of the street shops and a return to the building.
3. **The player repairs the physical problem.** The interaction is tactile,
   readable and satisfying even without the haunting.
4. **The repair earns a conversation.** Evidence and trust may let the resident
   name, confront or begin to heal the trauma underneath the recurrence.
5. **At a dramatic threshold, narcolepsy takes the player.** They endure a short,
   terrifying scramble through the dark and wake in bed in 4B.
6. **Something remains changed.** The case progresses or recurs, the building
   retains evidence, and another problem eventually begins the loop again.

The owner has ruled this sequence. The ruling canonises narcolepsy, involuntary
dream entry, a dark survival passage and waking in bed as the campaign loop. It
does **not** silently approve every implementation detail or open question in
`ORISON_MAZE_BRIEF.md`; those details are still reviewed on their merits.

The whole project must now answer one question:

> **Does this work make the next complete shift more legible, more affecting,
> more frightening or more pleasurable to inhabit?**

If the answer is no, defer it. A receiver, poster, prop family or simulation may
be excellent and still be out of scope.

---

## 2. What exists now

The project already owns most of the expensive world:

- A complete eight-level Orison, street, eleven shop interiors, working doors,
  stairs, elevator, schedules, navigation, lighting, weather and acoustic graph.
- Eighteen residents with identities, apartments, routines and animation data;
  six are case residents: Mina, Peter, Juno, Cal, Omar and Mae.
- `RealityCaseManager`, persistent case state and a complete Mina case flow.
- A minimal but real `WorkOrders` service and objective presentation.
- The Tenant's trauma-specific haunting grammar, pressure director, propagation
  systems and a measured audit identifying what players currently fail to see.
- Physical prop mechanisms, material infrastructure, audio sources, shops and a
  bodega capable of supporting maintenance errands.
- A ruled dream premise and production design, but no production dream loop.
- Strong visual density with a measured CPU/submission performance problem,
  especially in the atrium and on Android-class hardware.

The missing product is **connective tissue**. Mina's case, the shops, the repair
props, the residents, the haunting and the dream do not yet form one production
path that a new player can enter, understand and finish without debug knowledge.

Therefore the next target is not another room or subsystem. It is one complete,
shippable shift.

---

## 3. The golden shift

Build and polish one 25–40 minute vertical slice using Mina, because hers is the
only case currently complete and voiced. Do not invent six implementations in
parallel.

The slice must contain every campaign verb:

| Beat | Player action | Required payoff |
|---|---|---|
| Discover / alert | Notice a fault or receive Mina's complaint | A mundane need with one deniable impossibility |
| Inspect | Examine the affected object and its surroundings | The player can state what is physically wrong |
| Plan | Receive or infer a needed part/tool | A concrete reason to leave, not a waypoint invented by UI |
| Shop | Travel, speak, obtain, borrow, trade or improvise | Character or case information arrives with the part |
| Return | Re-enter an Orison subtly changed by absence | Dread accumulates without blocking navigation |
| Repair | Perform a short physical mechanism | Resistance, commit, sound, visible result and a test |
| Converse | Speak to Mina using evidence and earned trust | Compassion is not an obvious correct-answer button |
| Recur / integrate | See whether repair and conversation changed the rule | Repair alone cannot close the wound |
| Succumb | Read or abruptly experience narcolepsy onset | The condition is real; the Tenant exploits the interval |
| Scramble | Run, turn and decide when to use light | Terror, one case truth, no combat and no loot |
| Wake | Return to bed in 4B | Persistent residue proves the passage mattered |

The first pass may use deliberately plain presentation. It may not omit a beat.
Polishing half a loop is not progress toward this milestone.

### Two valid beginnings

The job catalog must support both starts with the same downstream contract:

- **Discovered issue:** an inspectable condition opens a work order after the
  player notices it.
- **Reported issue:** a resident, telephone, note or desk call opens it first.

Both become the same authored job state after acknowledgement. Do not build two
quest systems.

### The shops are narrative rooms, not vending machines

Every mandatory shop trip must do at least two jobs:

1. provide the practical component or knowledge; and
2. reveal character, history, contradiction or contamination from the Orison.

The procurement verb may be buy, identify, borrow, repair, trade, recover or
improvise. Repeating “buy item, return” is not six cases; it is one fetch quest
performed six times.

### The dream is punctuation, not a separate campaign

Dream entry is scheduled by dramatic eligibility, not a raw random timer. Sleep
pressure may accumulate systemically, but a production case declares safe and
unsafe transition windows. Calls and interactions already in progress remain
protected. The dream cannot erase completed work.

The waking condition and the supernatural reading remain both true. The game
must not suggest that narcolepsy itself is evil or causes the Tenant. It creates
the vulnerable interval the Tenant uses.

---

## 4. “AAA shine” in this project

AAA is not polygon count. Here it means that the player rarely encounters the
edge of the illusion and every important action has authored response across
image, sound, body and world state.

### Interaction

- One interaction language and consistent prompts.
- Every repair has approach, resistance, give, commit, confirmation and recovery.
- Hands, tools and moving parts meet; no object animates from across the room.
- Failure is recoverable and understandable. No hidden state blocks progression.

### Character

- Conversation staging uses gaze, posture, interruption, distance and room tone.
- Dialogue reacts to inspected evidence, repair quality, previous avoidance and
  whether the player stayed for the quiet beat.
- Case-less residents remain present through schedules, sound, doors, complaints
  and small acknowledgements without acquiring counterfeit chapters.

### Environment

- The critical route—4B, Mina's flat, lobby, stairs/elevator, chosen shop and
  repair location—receives hero polish before remote rooms receive more clutter.
- Lighting always preserves navigation while allowing authored darkness.
- Props required by the loop are readable in situ, correctly scaled, reachable
  and free of collision. Warehouse beauty is secondary to use in the room.
- Wear follows hands, water, heat, feet and repair history rather than uniform
  procedural noise.

### Horror

- Every major event has a speaker, emotional meaning, deniable precursor,
  escalation rule, cooldown, restoration behavior and test hook.
- The Tenant uses the active resident's wound; it never becomes a generic random
  effect generator.
- Resolved cases gradually give the player's own shadow a vocabulary. This is a
  campaign throughline and waking residue, not a second monster or an unrelated
  effects director.
- The dream reveals one concentrated truth and ends before repetition becomes
  familiarity.
- Waking residue prevents “none of it counted.”

### Audio

- The mix has a readable hierarchy: speech, immediate threat, interaction,
  navigation, building bed, music.
- Important sounds remain localisable in darkness and legible on ordinary stereo.
- Ambient sources are staggered, soft and sparse; repetition memory prevents a
  building full of synchronized loops.
- Silence after a dramatic peak is mixed deliberately, not produced by muting
  everything.

### Technical finish

- Stable frame pacing matters more than maximum visual settings. The current
  CPU-bound submission problem is a release blocker, not a later optimisation.
- No parse, missing-resource, invalid-UID or generated-data drift warnings.
- Save/load works at every loop boundary and never resurrects completed work.
- Keyboard/mouse and controller are complete; the gradual-onset accessibility
  option ships with the first dream implementation.

---

## 5. Code ownership and organisation

Do not make one god-director. Orchestration and domain state stay separate.

### Runtime ownership

| Concern | Owner | Rule |
|---|---|---|
| Overall shift stage | `CoreLoopDirector` in `game/scripts/campaign/` | Coordinates signals; contains no repair, shop, dialogue or haunting rules |
| Work-order lifecycle | `WorkOrders` | One authority for issued, acknowledged, diagnosed, awaiting-part, repairable, repaired and closed |
| Case truth and resolution | `RealityCaseManager` | Repair changes symptom state; conversation changes emotional rule |
| Job definitions | `game/data/maintenance_jobs.json` | Data names anchors, item requirements, case binding and eligible dream windows |
| Carried maintenance items | small `MaintenanceInventory` service | Parts and tools only; do not build a general RPG inventory |
| Shop stock / transactions | `game/data/shop_inventory.json` plus one shop service | Item provenance and acquisition verb; geometry remains layout-owned |
| Narcolepsy and transition | `SleepPressureDirector` in `game/scripts/dream/` | Accumulates pressure, respects protected windows, requests entry |
| Dream run | `DreamDirector` and its scene | Owns entry, light binary, pursuit, capture/hazard wake and residue handoff |
| Waking haunting | existing sanity / Tenant / intrusion owners | They provide pressure and case grammar; they do not advance quests |
| Presentation | objective, dialogue, interaction and subtitle UI | Presents authoritative state; never owns progression |

Names may change after inspecting the current tree, but ownership may not blur.
Before adding a manager, prove an existing owner cannot hold the responsibility.

### State contract

Use stable string ids and persist only authoritative facts:

- `active_job_id` and job stage;
- acquired/consumed maintenance item ids;
- inspection and evidence flags;
- practical repair quality/result;
- case trust, recognition, recurrence and resolution flags;
- sleep pressure seed/state and whether a dream is pending;
- dream seed, active pursuer id and last residue id;
- current safe return anchor.

Do not save transient UI, animation progress, current sound, light tween or
duplicated objective text. Reconstruct those from authoritative state on load.

### Signal contract

Systems communicate through explicit events such as `job_stage_changed`,
`part_acquired`, `repair_committed`, `conversation_changed_rule`,
`dream_requested`, `dream_entered`, `dream_ended` and `waking_residue_applied`.
Do not find sibling systems by brittle absolute scene paths when an injected
reference or signal suffices.

### Generated world law

`gen_layout.py` continues to own coordinates, markers and authored classifications.
Runtime code may select among authored anchors; it may not invent permanent world
placement. Generated JSON and GLBs are outputs, never hand-edited sources.

---

## 6. Milestones and acceptance gates

Milestones are evidence gates, not dates. Do not begin the next one because the
previous one “mostly works.”

**Current status overlay (2026-08-26):**
`design/MILESTONE_RECONCILIATION_2026-08-26.md` maps the integrated tree,
`TASKS.md` and the walkthrough punchlist onto these gates. M1 is structurally
complete; M2's fresh-save eleven-beat playthrough is the active product gate.
The overlay reports status only and does not alter the milestone definitions
below.

### M0 — Freeze and establish the current truth

1. Preserve unrelated dirty work; never stage with `git add -A`.
2. Run import, focused gameplay suites, FULL WalkTest, LightingAudit and the
   current performance stations.
3. Record the exact playable path through Mina, current save boundaries, shop
   reachability, warning count and performance baseline.
4. Identify which recent branches are product-critical, atmospheric support or
   deferred expansion.
5. Resolve or explicitly record contradictions between this plan, the Bible,
   maze brief and current data.

**Gate:** a fresh checkout reproduces the baseline, all failures are named, and
Claude can describe the current golden path without reading source during play.

### M0.5 — Finalise the map substrate

*Inserted by owner ruling 2026-08-13. Build drawing and measured baseline:
`design/FINAL_MAP_REDESIGN_BRIEF.md`.*

Consolidate the playable world into three separately owned zones before job data
binds itself to shop anchors that are about to move:

1. **ORISON** — the final apartment building, its required service spaces and
   controlled exterior proxy.
2. **STREET** — the compact 1928 crossing, traffic and honest stage boundaries.
3. **PASSAGE** — the Vantry Arcade in fiction; all eleven researched shops in
   one enclosed, independently gated commercial hall.

This is bounded subtraction, relocation and optimisation, not world expansion.
Remove the redundant street parade, identify and remove the black obstruction
masses, build the ruled portal/throat/hall envelope, preserve all load-bearing
shop identities and interactions, and introduce real zone ownership. Pin every
comparison to the production 16-light/16-shadow budget until that contract is
deliberately changed.

**Gate:** all three zones and the complete errand route are reachable and
visually final; the Passage does not submit from the street; all eleven shops
exist exactly once; no obsolete shell, invisible blocker or exposed stage edge
remains; generated data and focused/full suites are clean; every critical
performance station meets the recorded target or carries a measured blocker
that the owner has explicitly accepted.

### M1 — Build the loop spine

1. Define the data schema for one maintenance job and one shop item.
2. Extend `WorkOrders` through the full practical lifecycle without embedding
   case dialogue.
3. Add the narrow maintenance inventory and one acquisition transaction.
4. Add `CoreLoopDirector` as orchestration only.
5. Persist and restore every stage boundary.
6. Add a test harness that can enter each boundary directly without debug UI in
   the production scene.

**Gate:** one graybox job can start by discovery or report, require an item,
accept a repair, request conversation, request a dream, and resume after waking.

### M2 — Complete the graybox golden shift

1. Route Mina's existing case through the new spine.
2. Select one period-correct shop, part and procurement action already supported
   by the fiction; do not invent another shop.
3. Connect inspection evidence to the procurement reason.
4. Connect repair result to Mina's conversation entry and recurrence.
5. Prototype gradual and sudden sleep onset, dark scramble and bed return.
6. Apply one persistent waking residue.

**Gate:** a fresh player completes all eleven beats in §3 without console,
debug panel, noclip or developer knowledge. Save/load succeeds after every beat.

### M3 — Make repair and procurement pleasurable

1. Finish the hero repair mechanism to crumb-tray tactile quality.
2. Stage hands/tool/part, sound, animation and visual confirmation.
3. Give the chosen shop a proprietor interaction, acquisition verb and case clue.
4. Make street travel short, safe to navigate and atmospherically changed on
   the return leg.
5. Remove unnecessary UI waypoints; let signage, light and dialogue carry route.

**Gate:** blinded playtesters understand what they need, where to go, what they
obtained and whether the repair worked.

### M4 — Make Mina and the building respond

1. Polish Mina's performance, staging and reactive conversation.
2. Make repair-only, conversation-only and integrated outcomes visibly distinct.
3. Add ordinary reactions from nearby case-less residents without diverting the
   chapter.
4. Change Mina's flat, sound signature, schedule behavior and maintenance-room
   record after integration.
5. Let the Tenant escalate because it was ignored, not because a timer expired.
6. Leave one deniable shadow behavior that borrows the lesson Mina's case taught;
   do not attempt fluent communication in the first shift.

**Gate:** a player can describe Mina's coping strategy before the game names it,
and can explain why the practical repair did not by itself solve the case.

### M5 — Make the dark scramble terrifying

1. Prototype and approve the light-on/visible versus light-off/safer binary.
2. Reuse Orison room vocabulary with local coherence and global wrongness.
3. Bind the pursuer to the just-integrated case's release print under the
   one-Tenant ruling; never preview the next unresolved case.
4. Give every hazard an audible tell and understandable wake outcome.
5. Protect calls, conversations and committed repair work from onset loss.
6. Ship gradual-only onset accessibility and mix safeguards.
7. Tune the first run to end before mastery; later campaign stages lengthen it.

**Gate:** first-time players are frightened, know why the passage ended within half a
second, wake in 4B without lost progress, and recognise one case truth in the run.

### M6 — AAA vertical-slice polish

1. Hero-pass only the critical route and interaction surfaces.
2. Fix collisions, clipping, visibility, lighting and prop reach along that path.
3. Complete animation transitions, gaze, hand contact, subtitles, controller
   navigation, mix and haptics where available.
4. Profile and meet an agreed frame budget at every critical camera station;
   test Android-class hardware before claiming performance done.
5. Run visual regression shots with real streaming and gameplay lights, plus
   luma, shadow, route and acoustic checks.
6. Conduct three fresh-player playtests and fix observed confusion before adding
   content.

**Gate:** the complete Mina shift presents no placeholder, debug dependency,
obvious collision, warning, broken save boundary or unexplained objective.

### M7 — Prove the template with Peter

Peter is the ordained second case. Build him by reusing the spine and changing
content, repair mechanism, procurement verb, conversation pressure and dream
grammar—not by forking managers.

**Gate:** Peter reaches Mina's quality bar, the two cases feel structurally
related but emotionally and mechanically distinct, and no Mina-specific branch
has leaked into shared code.

### M8 — Produce the six-case campaign

Build Juno, Cal, Omar and Mae one at a time. Each must specify:

- discovery/report path;
- physical fault and diagnosis;
- shop and procurement verb;
- tactile repair mechanism;
- evidence-driven conversation;
- recurrence rule;
- Tenant grammar and dream truth;
- persistent aftermath and trophy;
- the concept or gesture the player's shadow can borrow after resolution;
- case-less resident involvement;
- test and performance budget.

Do not open the sanctioned expansion until all six are complete and the owner
has played the whole campaign.

---

## 7. Practical task discipline

### Before implementation

1. Pull/re-read current source and generated output; other sessions move quickly.
2. Claim the exact `TASKS.md` line with a name.
3. State the milestone and acceptance gate the change serves.
4. Read the relevant authority documents and existing owner before adding code.
5. Capture a before render for visual work and a failing focused test for logic.

### During implementation

- Work one vertical slice through all layers before broadening a family.
- Keep commits single-purpose and reviewable.
- Do not combine generated data, unrelated cleanup and feature code casually.
- Run only one Godot process against `.godot` at a time.
- After the last source edit, regenerate, copy outputs, import, then test. A green
  run built from the previous artefact is not evidence.
- Verify visuals in a real window, in situ, with production streaming and lights.
- Keep debug controls as observability tools, never required progression.

### At handoff

Record in the commit or task handoff:

- milestone and task id;
- player-visible outcome;
- authoritative files changed;
- generated outputs refreshed;
- focused and full test commands/results;
- before/after render paths where relevant;
- performance delta at affected stations;
- remaining defect or next acceptance gate.

Do not turn `HANDOFF.md` into a status log. It documents build mechanics. Do not
turn audits into queues. Do not leave completed tasks in `TASKS.md`; git history
is the log.

---

## 8. Documentation map for this production

| Information | Authority / location |
|---|---|
| Fiction and owner rulings | `design/ORISON_BIBLE.md` |
| Product direction, milestone order, definition of done | this document |
| Immediate next sequence | `design/next_session_plan.md` |
| Open executable work | `TASKS.md` |
| Ruled dream production design | `design/ORISON_MAZE_BRIEF.md` |
| What props do | `design/PROP_ACTIVITIES.md` |
| Actual subsystem behavior | `game/docs/` next to the subsystem |
| Build and verification mechanics | `HANDOFF.md` |
| Evidence from an investigation | dated `design/AUDIT_*.md` report |

When the loop spine lands, add `game/docs/core_loop.md` documenting the actual
state machine, signal contract, save fields and extension recipe. Do not write
that reference document from this execution plan before the code exists.

---

## 9. Vertical-slice definition of done

The Mina slice is done only when:

- a fresh save reaches and completes it without debug tools;
- discovery/report, diagnosis, shop, return, repair, conversation, recurrence,
  sleep attack, dark scramble and bed return are all present;
- the player always knows their immediate practical intention without a quest
  arrow doing all the work;
- repair feels good and repair alone does not resolve trauma;
- Mina performs as a person rather than a dispenser;
- the Tenant's behavior is emotionally specific to her case;
- the dream is frightening, fair, short and unable to erase work;
- waking leaves persistent physical or social residue;
- the critical route looks and sounds final;
- save/load, controller, subtitles and gradual-onset accessibility work;
- focused suites and the bounded full suite pass;
- the build is warning-free and within the agreed performance budget.

Only then is “next case” the correct next task.
