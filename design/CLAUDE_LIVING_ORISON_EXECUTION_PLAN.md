# Claude execution plan: make the Orison live, then let the player's shadow speak

## Purpose

This is an implementation plan, not a brainstorming document. Its target is a
polished 45–60 minute vertical slice in which the Orison feels inhabited before
it feels haunted, Mina is a person rather than a quest dispenser, Reality
Maintenance has a complete repeatable loop, and the player slowly realizes that
their own shadow is trying to communicate trauma using the building as a
vocabulary.

Do not expand all eighteen cases in parallel. Finish one dramatic spine, prove a
second contrasting case, and only then scale content.

## Audit snapshot — 2026-08-01

### Implemented and worth preserving

#### The apartment building

- Eight traversable levels, a coherent atrium stair, working elevator, roof,
  basement, street, neighboring skyline, weather, puddles, exterior detail and
  physically modeled damaged pavement.
- Procedural source of truth in `art/data/gen_layout.py`, Blender generation in
  `art/blender/scripts/build_orison.py`, and generated Godot floor scenes.
- Eighteen profiled households. Occupied apartments have complete sleep, bath,
  kitchen, work/rest and storage affordances plus resident-specific clusters.
- 250 functional props, 202 switches, 23 radiators, 191 managed light sources,
  room-aware moonlight, window glow, door spill, occluders and a bounded light
  budget.
- A working acoustic graph with 267 runtime nodes, localized propagation,
  ambient building sounds, intermittent radiator activity, television station,
  moving ghost radio, 36 diegetic tracks and resident music anecdotes/rewards.
- Resident portal-graph navigation covers 320 nodes, seven stair links and the
  elevator. Routines make residents leave home, operate doors, walk the halls,
  use stairs/lift, visit authored haunts, watch television and return.
- Exterior, environmental wear, renovation zones, domestic anomaly props,
  eighteen witness clocks, character art and story-detail catalogs are present.

#### Gameplay and persistence

- Persistent case state distinguishes temporary stabilization, recurrence,
  emotional recognition, integration and resolution. Repair alone cannot close
  a case.
- Eighteen resident case definitions, trauma-linked manifestations, silly
  minigame concepts, portal rules and resolution flags exist as data.
- Mina's Caption Crisis is the only complete playable case: work order,
  inspection, factual-caption calibration, stabilization, return visit,
  recurrence, branching dialogue, silence choice, integration and resolution.
- The maintenance headquarters reads resolved state, displays eighteen trophy
  slots and exposes six gear thresholds.
- Save/load covers cases, stability/coherence, portal rules, discovered
  documents, music unlocks and anecdotes.
- Reality case, reality rule, Mina gameplay, Mina character, cast and map
  distortion tests currently pass.

#### Horror direction

- `SanityDirector` is a strong hidden-pressure authoring system, not a visible
  sanity meter. It observes movement, running, camera checks, dwell, gaze and
  whether the player noticed the last intrusion.
- It has refractory periods, mercy after major events, anti-repetition,
  attention-aware timing and campaign memory.
- `PoltergeistLibrary` provides a four-rung, trauma-specific grammar for all
  eighteen residents: deniable tell, repeated pattern, reenactment and direct
  address.
- `Intrusions` prefers off-camera changes, checks visibility and occlusion,
  snapshots affected objects, restores them, and can use props, lights, sound,
  captions, television, map distortion and restrained fourth-wall effects.
- Domestic witness clocks and secondary anomaly props give every home a
  resident-specific uncanny behavior rather than one universal haunted prop.

### Partial, misleadingly complete, or placeholder-only

- All eighteen cases exist in data, but only `mina_caption_crisis` is enabled.
  The remaining seventeen have no playable minigame/dialogue/integration flow.
- `reality_rules.json` contains authored rule progressions for only Mina, Peter
  and Cam.
- The intro is an F2/debug-controlled camera route in
  `virus_sound_director.gd`. `intro_complete` exists in save data but is never
  consumed or set. There is no production new-game onboarding or first-shift
  state machine.
- The intro ends on an incoming-call monitor, but does not establish the job ad,
  the Realty/Reality correction, player motive, maintenance headquarters,
  controls, or why the player accepts the first case.
- Runtime reports 18 residents, 0 rigged, 18 sprite fallbacks. ResidentRoutines
  upgrades only Evelyn's available mesh opportunistically. `USE_RIGGED_RESIDENTS`
  is false.
- Sprite residents have billboard presentation and floating nameplates. They are
  non-colliding and can be walked through. Their schedules are loops, not a
  building clock with believable sleep/work/meals/social encounters.
- Mina requests `strained` and `recognition` animation roles, but they no-op
  unless matching clips ship.
- Case 01 has 34 authored voice takes and an import pipeline, but there are zero
  shipped `.ogg` voice files. Every conversation is silent text.
- Generic resident interaction activates a case or tells a music anecdote. Only
  Mina has substantive case dialogue.
- Most repair gear is display/progression symbolism rather than player tools with
  reusable mechanics.
- The resident case definitions are emotionally promising summaries, not yet
  scenes with subtext, reversals, specific memories, relationship dynamics and
  consequences.
- The sanity/poltergeist systems can address the player, but they speak as
  residents/the building. There is no persistent player's-shadow entity, state,
  visual behavior or learnable communication grammar.
- Existing fourth-wall messages are powerful accents but risk reading as a
  collection of horror UI tricks without a single speaker and dramatic agenda.

### Verified technical blockers

- `LightingAudit.tscn` currently exits with 89 failures. It expects local shadow
  coverage in rooms across inactive floors, which conflicts with the active-floor
  light budget. Decide whether the test contract or rig contract is correct, then
  make the test meaningful and green; do not simply increase every light budget.
- `WalkTest.tscn` starts successfully and passes its early architecture,
  lighting, prop, resident and touch checks, but did not reach a final summary
  within the bounded audit run. Give it deterministic sections and a hard test
  completion signal.
- Generated glTFs emit invalid-UID fallback warnings for several textures.
- Music/WalkTest startup emits an invalid UTF-8 byte warning (`0xA9`). Find and
  repair the source file encoding.
- `game/scripts/building/orison_provenance_pass.gd.uid` is orphaned after the
  floating-decal pass was removed.
- Root/game documentation contains stale engine versions and old prop/node
  counts. Treat runtime/generator output as authoritative until docs are updated.

## Product definition for the vertical slice

The slice succeeds if the player experiences this arc without opening debug UI:

1. Arrive for a mundane overnight maintenance shift.
2. Learn the building by doing two ordinary tasks and encountering residents in
   believable routines.
3. Notice one deniable error involving their shadow.
4. Receive and work Mina's practical complaint.
5. Stabilize it, believe the job is done, and watch it recur.
6. Discover that practical repair only changes symptoms; honest conversation
   changes the rule.
7. Learn that the player's shadow has been borrowing resident manifestations to
   develop a vocabulary.
8. Receive one clear but incomplete message from it: not a villain's threat, but
   a desperate attempt to communicate a wound the player refuses to own.
9. Resolve Mina's case, receive a tangible headquarters/music reward, and see a
   second work order arrive whose manifestation proves the system can vary.

The shadow must remain ambiguous in this slice. The player should know it is
trying to communicate, but not whether it is a dissociated self, a future/past
self, a parasitic echo, or something the building created from them.

## Core dramatic rule: the shadow learns from the cases

The shadow cannot begin with fluent text. Each resolved resident case teaches it
one concept and one medium.

For the slice:

| Beat | Borrowed lesson | Shadow behavior |
|---|---|---|
| Before Mina | none | lags by a few frames; occasionally faces the wrong light |
| Mina tell | annotation | shadow edge resembles a bracket/caption tail for one second |
| Mina recurrence | silence is meaningful | shadow persists during a brief light dropout instead of disappearing |
| Mina integration | assumptions are not facts | shadow points to an object, then retracts when player looks; it is testing reference |
| Slice climax | communication | uses three learned gestures to form `NOT YOUR FAULT` or a similarly incomplete, contestable statement without HUD text |

Never render a floating ghost beside the player. The player's normal shadow is
the character. Violations should be achieved with a lightweight duplicate
silhouette/decal/projection that is only visible in authored conditions, not by
replacing Godot's entire lighting solution.

## Execution order

### Phase 0 — establish a trustworthy baseline

1. Repair invalid UTF-8 and glTF UID warnings.
2. Remove orphaned `.uid` files for deleted scripts.
3. Split WalkTest into bounded suites: architecture/navigation, apartment
   completeness, resident travel, elevator, interaction and mobile input. Every
   suite must emit a summary and non-zero exit on failure.
4. Rewrite LightingAudit around the actual contract:
   - active floor is navigable and modeled by the allowed light/shadow budget;
   - visible exterior and atrium sources remain coherent;
   - inactive floors do not spend dynamic light budget;
   - authored rooms have a fixture in the fixture map even when it is gated off.
5. Capture baseline performance at street, lobby, atrium, one apartment and roof.

Acceptance:

- All non-visual tests green.
- No parse, missing-resource, invalid-UID or encoding warnings on main-scene boot.
- A repeatable screenshot/performance command documents the five baseline views.

### Phase 1 — production boot and first shift

Create a `FirstShiftDirector`; do not keep adding responsibilities to the viral
sound director.

State machine:

`NEW_GAME -> ARRIVAL -> CLOCK_IN -> MUNDANE_TASKS -> FIRST_ERROR -> CALL_READY -> FREE_PLAY`

Required sequence:

1. Start outside with player control, not a long noclip movie.
2. Place the corrected employment listing in the player's hand/inventory:
   `Realty Maintenance` visibly corrected to `Reality Maintenance` by inserting
   the I. Keep the joke quick.
3. Let the player unlock the front door, find the maintenance room and clock in.
4. Give two ordinary tasks that teach tools and geography: replace/inspect the
   entrance lamp and bleed/check one radiator. They must use the same interaction
   verbs later used by supernatural work.
5. During task two, stage the first shadow error. Do not call attention to it.
6. Only after the player has acted in the world should the viral seed move toward
   4B and the incoming call appear.
7. Set and persist `intro_complete`; subsequent loads begin at the last safe
   maintenance state.

Acceptance:

- A fresh save reaches Mina's work order without F1/F2 or developer knowledge.
- The player has learned interact, light/tool use, headquarters and one vertical
  route through action rather than tutorial text.
- Skipping/reloading cannot soft-lock the first call.

### Phase 2 — make ordinary life convincing before adding more horror

1. Add a simple building clock and schedule blocks: home, sleep, meal, work/away,
   errand, shared-space haunt. Seed schedule offsets deterministically.
2. Keep portal-graph routes, doors, stairs and elevator. Replace timed random
   wandering with schedule intent plus small local variation.
3. Add resident-to-resident acknowledgement at close range: glance, pause,
   greeting, held door, irritation when blocked. No complex crowd AI.
4. Remove floating resident nameplates in normal play. Identification comes from
   mailbox/door labels, conversation and context; nameplates remain debug-only.
5. Prevent walking through visible residents. Add low-cost reciprocal avoidance
   or a soft player capsule only when the actor is nearby and route-safe.
6. Add ordinary one-line barks and non-case interactions for all residents:
   current task, time of night, neighbor opinion, building complaint. Author at
   least five per resident with state/time gating and repetition memory.
7. Make routine actions audible and visible: kettle, tap, television, door,
   elevator call, footsteps, laundry, cupboards. Reuse existing audio catalog.
8. Ensure apartments change modestly across schedule states: bed use, a lamp,
   mug/plate state, television latch, work surface. Prefer toggling existing
   props over spawning clutter.

Acceptance:

- Ten minutes with zero hauntings still feels like an occupied building.
- From corridor sound and behavior, the player can infer at least three residents
  are awake and doing different things.
- No resident walks through a wall, closed door, player or another visible actor.

### Phase 3 — make Mina a compelling co-protagonist

1. Ship Mina's final rigged model and enable it in production.
2. Provide bespoke idle, walk, listen, guarded, strained, deflecting,
   recognition, quiet and relieved clips. Use animation state driven by dialogue
   role and case stage.
3. Record/import all 34 voice takes. Direct performance toward precision used as
   armor: quick correction, dry wit, involuntary pause, then controlled honesty.
4. Add gaze targets and conversational staging so she looks at evidence, player,
   exits and her own captions instead of facing the camera continuously.
5. Add six non-case interactions and three reactions to the player's behavior
   (leaving mid-conversation, staring at a caption, choosing silence).
6. Replace case-object title floating with diegetic highlighting/inspection UI
   that appears only at interaction range.
7. Give her a relationship with at least two neighbors visible outside the case.

Acceptance:

- A blind observer can describe Mina's coping strategy from performance before
  the dialogue names it.
- Dialogue remains understandable with subtitles off and emotionally legible
  with audio off.
- Silence choices produce acting and room-tone consequences, not merely a branch.

### Phase 4 — implement the player's shadow as a character

Create `ShadowContactDirector` with persistent state separate from sanity
pressure:

- `fluency`: concepts/media learned from resolved cases.
- `urgency`: increases when communication attempts are ignored or misread.
- `trust`: increases when the player waits, looks back, follows or repeats a
  gesture; decreases when they flee or flood the room with light.
- `attempt_history`: prevents repeats and supports callbacks across saves.
- `trauma_fragments`: opaque tokens revealed in a fixed dramatic order.

Implement a six-verb visual grammar:

1. **Lag** — silhouette trails a small fraction after player movement.
2. **Refuse** — remains still while player moves.
3. **Point** — extends toward a prop, door or light source.
4. **Occlude** — blocks a small pool of light it should not be able to block.
5. **Repeat** — echoes the last resident-specific gesture.
6. **Split** — briefly shows two mutually exclusive poses/histories.

Rules:

- Use authored pools of light, mirrors, wet pavement, elevator interiors and the
  stairwell as legibility zones. Do not attempt the effect everywhere.
- Most attempts happen at the edge of view or are discovered after turning back.
- The shadow never harms the player in the slice.
- Every clear communication attempt must be preceded by at least two deniable
  versions of the same verb.
- SanityDirector decides when attention is available; ShadowContactDirector
  decides what the ongoing speaker is trying to say. Do not let both directors
  independently fire major events.
- Resident poltergeists remain resident-specific. The shadow may borrow their
  grammar only after the player has witnessed or resolved it.

Add three slice set pieces:

1. Entrance lamp: during a flicker, shadow remains on the wall after the player
   moves.
2. Elevator: shadow exits one floor before the player, visible only through the
   stained vision panel.
3. Mina integration: room lights cut, but the shadow remains and performs the
   first deliberate three-gesture sentence.

Acceptance:

- Playtesters independently describe the shadow as “trying to tell me something,”
  not “a ghost chasing me.”
- At least half notice the first event but remain unsure it happened.
- The climax is readable without a caption or fourth-wall text box.

### Phase 5 — close the complete Mina loop

1. Connect FirstShiftDirector to the existing Mina flow.
2. Make inspection tools physical verbs with feedback, failure and recovery.
3. Ensure stabilization creates a believable quiet interval and visible mundane
   aftermath before recurrence.
4. Replace the artificial time-clock “Visit Two” shortcut in production with a
   real shift boundary or meaningful elapsed-time/leave-and-return trigger.
5. On resolution, visibly install Mina's trophy, unlock her tracks, change her
   apartment/witness clock behavior and retire her poltergeist from random
   address selection.
6. Leave one quiet unresolved shadow consequence after the celebratory reward.

Acceptance:

- Repair without conversation always recurs.
- Conversation without competent repair cannot resolve.
- Resolution changes resident, apartment, headquarters, soundtrack and shadow
  vocabulary in ways the player can perceive.

### Phase 6 — prove extensibility with one contrasting second case

Implement Peter Wren's bureaucracy corridor next. It already has a rule set and
contrasts Mina: spatial/legal anxiety rather than annotation and silence.

Required loop:

- Forms create physical route ambiguity.
- Practical minigame is funny and tactile, not menu paperwork.
- Temporary compliance makes the corridor worse.
- Honest resolution requires proceeding with acknowledged uncertainty.
- The shadow learns `POINT` or `SPLIT` from Peter, expanding its grammar.

Do not implement cases 3–18 until Peter meets the same acceptance bar as Mina.

### Phase 7 — scale the cast and campaign

After two polished cases:

1. Create a reusable case scene contract: start, manifestation, repair verb,
   recurrence trigger, dialogue roles, integration, resolution aftermath,
   shadow lesson and tests.
2. Group remaining cases into production batches by reusable mechanics, not by
   floor.
3. Produce final character models/voice in the same order as case batches.
4. Expand portal rules and a convergence sequence only after enough rules exist
   for meaningful combinations.
5. Give the player's shadow a reveal arc that remains emotionally specific and
   does not invalidate residents by making every wound secretly about the player.

## Claude working protocol

1. Read the relevant system and its tests before editing.
2. Work one phase and one acceptance gate at a time. Do not “touch every system”
   in one pass.
3. `art/data/gen_layout.py` owns coordinates. Never hand-edit generated JSON or
   glTF. Regenerate and rebuild through the documented pipeline.
4. Preserve GL Compatibility constraints: bounded dynamic lights, no reliance on
   SSR/volumetrics, batch repeated geometry and avoid one process callback per
   decorative object.
5. Never use floating world-space labels as a substitute for object placement or
   interaction design. Debug labels must be debug-only.
6. Every horror event needs: speaker, emotional meaning, deniable precursor,
   escalation rule, restoration behavior, cooldown and test hook.
7. Every case needs: practical repair, recurrence, real conversation,
   integration, persistent aftermath and shadow-vocabulary consequence.
8. Run focused tests after each change and the full bounded suite before handoff.
9. Update this document with evidence: files changed, test output, screenshots and
   remaining gate. Do not mark a phase complete because data stubs exist.

## Definition of done for the vertical slice

- Fresh save to completed Mina case is playable without debug tools.
- 45–60 minutes of intentional pacing with no mandatory wandering.
- Building remains convincing during a ten-minute no-horror interval.
- Mina is voiced, animated and behaviorally specific.
- Practical repair, recurrence, conversation and integration are all necessary.
- Player's shadow performs at least three deniable tells and one legible,
  incomplete communication.
- Headquarters, apartment, resident, audio, music and campaign state all reflect
  resolution.
- A second case is announced and can begin.
- Tests and boot are warning-free; performance remains within recorded baseline.

