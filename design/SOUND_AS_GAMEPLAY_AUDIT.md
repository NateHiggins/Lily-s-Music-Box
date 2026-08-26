# Sound is the house answering — gameplay-audio architecture audit

Status: implementation audit and plan, updated 2026-08-26. The policy, bus
tree, bounded pool and production census now exist. Numeric loudness and
masking claims still remain hypotheses until measured in a production walk.

## Implemented checkpoints

- `AudioPolicy` builds the canonical 18-bus hierarchy, a bounded 16-voice
  semantic pool, priority/cooldown/instance rules, a composable volume mix
  stack and ordered diagnostics.
- `audio_cues.json` owns 20 semantic cues. The release route now distinguishes
  the Vantry fault, switch on/off, ordinary door motion/latch/refusal, clock
  proof/refusal, register index/paper/key/refusal, and all four house-line
  states.
- ordinary switches and doors no longer carry hundreds of private one-shot
  players; the opening clock and night register have shed five more.
- every direct constructor has a bus assignment in its creating function.
  `audit_audio_emitters.py` makes that a repeatable static check.
- the full production scene-tree census currently finds 776 players and zero
  Master fallbacks. The two processed extension buses rejoin the canonical
  tree as `Ambience -> World` and `GhostRadio -> Diegetic`.
- focused policy proof passes 38/38; production policy proof passes 18/18;
  house telephone passes 41/41 focused and 16/16 live.
- persistent Master, Gameplay, Voice/Telephone, World/Weather, Music and UI
  controls are reachable from Building Services; mix states add their offsets
  to those baselines rather than erasing player settings.
- opt-in semantic cue captions render catalog copy plus one listener-relative
  sector, cap traffic at three lines, and disclose no distance, room or hidden
  owner. This is not yet full closed-caption coverage.
- live weather now gates the storm roof bed and exterior rain/hail events.
  Known clear, snow and fog conditions cannot borrow rain recordings; missing
  network weather deliberately retains the authored storm fallback.

This closes the routing emergency, not the listening/masking programme.

## Product ruling

Sound is Orison's primary *unsung* feedback channel. It should tell the player:

1. what acted;
2. where it acted;
3. whether the action took;
4. what state the mechanism entered;
5. whether that state is ordinary, faulty, dangerous or impossible;
6. what deserves attention next.

Silence is part of this language. A cue that carries no actionable or living
information spends attention without repaying it. The target is not a louder or
busier building; it is a building whose sounds can be learned.

## What production owns now

The system is not empty. Its strongest pieces should survive consolidation:

- `PropAudio` is one recorded-asset registry with caching, missing-key warnings
  and explicit licensing provenance.
- `AmbientSoundscape` owns four broad beds, a five-voice architectural event
  pool, sparse scheduling, a shared stagger guard and paranormal ducking.
- `AcousticGraphData` owns a 550-node physical-network graph with propagation
  delay and damping for authored motif/reality events.
- `FunctionalProp.make_emitter()` gives many mechanisms bounded 3D sources.
- the Vantry fault has a unique recorded `vantry_chirp`, a single promoted
  physical owner and an authored job relationship.
- Dream cellular audio has its own bounded voice pool and priority behavior.
- music, the Harukiya PA, phonautograph playback, microphone capture and a few
  ambient sources use purpose-specific buses.
- local mechanisms often distinguish state through pitch, cadence or a held
  loop rather than adding UI confirmation.

These are islands of good ownership, not yet one mix architecture.

## Static findings

The current scripts contain 53 direct `AudioStreamPlayer`/
`AudioStreamPlayer3D` constructions plus 80 literal calls through
`make_emitter()`. All 53 direct constructions now declare a bus in the same
function. The helper also routes its remaining legacy emitters and marks them
for runtime census. This replaces the original finding that most fell through
to `Master`.

The shared emitter helper hard-codes `unit_size = 4.0` and
`max_distance = 26.0` for objects as different as a toaster latch, key punch,
radiator knock and electrical cabinet. Individual props sometimes override it,
but there is no declared semantic class or audibility contract.

Literal `make_emitter()` reuse is concentrated heavily in a tiny vocabulary:

| Asset key | Literal uses | Collision risk |
| --- | ---: | --- |
| `tick` | 29 | clocks, switches, paper, darts, controls and inspections teach one sound as many verbs |
| `knock` | 17 | pipes, refusals, keys, registers and service mechanisms compete with the hero radiator clue |
| `hum_loop` | 9 | unrelated motors, draft, appliances and terminals lose source identity |
| `pop` | 9 | releases, paper and mechanical confirmations share one transient |
| `creak` | 5 | architecture, furniture and mechanisms blur |

This is efficient placeholder reuse, but it prevents a reliable learned audio
language. Pitch randomization does not create semantic identity.

### Ownership fractures

- There is no checked-in canonical bus layout. `Ambience`, `GhostRadio`,
  Harukiya PA, microphone and phonautograph buses are created and effect-loaded
  by whichever runtime owner arrives first.
- Ordinary prop, dialogue, voice, UI, service feedback, hazards and most
  machinery share `Master`; they cannot be balanced, ducked, metered or exposed
  as accessibility categories independently.
- `SleepPressureDirector` and `DreamEmbrace` both add temporary filters directly
  to `Master` and later remove effects by object identity. Each behaves locally,
  but no common owner composes simultaneous global mix states.
- `AcousticGraphData` is a narrative-event transport. Ordinary 3D emitters do
  not automatically use its door, wall, shaft, delay or damping truth. Most
  sound travels by Euclidean Godot attenuation even when the building says it
  travelled through plaster, pipes or a stairwell.
- `AmbientSoundscape` chooses plausible graph-node origins but still plays from
  a pooled point emitter; it does not prove the path heard by the listener.
- domestic radios and older baked radio furniture both use `murmur_loop`, while
  the music director separately owns an unlocatable moving radio. These are
  three radio concepts with no arbitration or spectral budget.
- the roof bed is permanently sourced from a storm-city asset even though live
  weather now owns real conditions. Weather state and weather sound can lie to
  one another.

### Missing contracts

Production has no single declaration for:

- cue purpose (`interaction`, `state`, `navigation`, `hazard`, `speech`,
  `world`, `music`, `impossible`);
- priority and concurrency;
- maximum simultaneous voices by category and room;
- foreground cue ducking and recovery;
- semantic variants and repetition avoidance;
- minimum/maximum audible range for a gameplay-critical cue;
- occlusion, portal transmission or floor leakage;
- subtitle/caption identity and direction;
- audio settings beyond master gain;
- automated proof that a cue starts, stops, remains unique and is audible from
  the player poses where the task expects it.

### Locomotion finding: truthful contacts, no audible shoe

`PlayerController._publish_foot_contacts()` already does the difficult part
correctly. It measures travel after collision resolution, rejects airborne,
teleport and noclip movement, varies stride for crouching, derives force from
actual planar speed, and publishes contact position/direction. Dream mechanics
consume that fact. No audio owner does.

Do not bind `stairs_footsteps.ogg` to each contact: it is a multi-step event,
so retriggering it would overlap phantom feet and sever sound from the measured
stride. The next slice needs a small licensed mono one-shot set for wood,
terrazzo/tile, concrete and metal stair/plant surfaces, plus shoe variants.
Surface identity should come from the collision owner or an authored floor
zone; a downward ray should be fallback only. One pooled listener-relative
owner can then turn the existing contact fact into sound without changing
movement or Dream stimulus truth.

## Proposed architecture

Do not replace every prop with a god object. Preserve state ownership at the
source and centralize only policy.

### 1. Authored bus tree

Check in one bus layout, created before world owners:

```text
Master
├── Gameplay
│   ├── Interaction      immediate hand/mechanism response
│   ├── State            running/stopped/faulted machine truth
│   ├── Navigation       Vantry, telephone, watch route, objective-bearing cues
│   └── Hazard           urgent physical or Dream warnings
├── Voice
│   ├── Dialogue
│   └── Telephone
├── World
│   ├── RoomTone
│   ├── Architecture
│   ├── Weather
│   ├── Machinery
│   └── Broadcast
├── Music
│   ├── Diegetic
│   └── Nondiegetic
└── UI
```

Keep special coloration buses as children or sends, not parallel undocumented
masters. Apply user controls at stable parent buses.

### 2. Cue catalog and semantic grammar

Replace raw string selection at call sites gradually with data-backed cue ids.
Each record declares purpose, source family, variants, gain range, pitch range,
distance profile, cooldown, max instances, priority, caption key and whether it
may be graph-transmitted. The prop still decides *that* its latch moved; the
catalog decides how a latch of that family speaks.

Opening-shift vocabulary should be deliberately small and contrastive:

- `accepted`: dry, immediate mechanical completion;
- `refused`: arrested motion with no completion transient;
- `working`: stable repeat/bed tied to physical activity;
- `fault`: irregular signature unique to the responsible family;
- `danger`: unmistakable attack/repetition reserved from ambience;
- `direction`: repeatable beacon whose level and spectrum survive the route;
- `impossible`: a familiar source violating location, rhythm or material—not a
  generic horror sting.

### 3. Audio policy director

A small policy owner receives cue requests and allocates pooled voices. It owns
priority, cooldown, concurrency, sidechain/duck envelopes and diagnostics; it
does not own jobs, cases or prop state. Critical navigation/hazard cues pre-empt
decorative architecture. Repeated low-priority events in one room coalesce.

### 4. Acoustic scene model

Use a hybrid rather than routing every click through 550 nodes:

- direct within the source room;
- portal/door attenuation between adjacent rooms;
- acoustic-graph propagation for pipes, structure, signal lines and authored
  remote motifs;
- simplified floor leakage for strong impacts and machinery;
- low-frequency survives barriers better than speech/high transients.

Cache listener-room and route solutions. Recompute on door/room transition,
not every frame. A debug overlay should show source, listener, chosen path,
gain loss, delay, low-pass and priority.

### 5. Mix-state stack

One owner composes normal, dialogue, telephone, sleep onset, Dream embrace,
pause and accessibility states. Directors request a named state with weight;
none edits `Master` effects directly. This prevents filters and ducking from
silently fighting or being removed out of order.

### 6. Captions as parity, not spoilers

Optional closed captions name source class, direction and useful rhythm:
`[Vantry chirp — above, behind the wall]`, `[two pipe knocks — floor above]`.
They must expose what an attentive listener can hear, never hidden ownership or
case truth. Critical cues also need visual/haptic redundancy, but sound remains
the fastest and richest surface.

## Executable programme

Refresh the static migration inventory without launching Godot:

```powershell
python tools/audit_audio_emitters.py
python tools/audit_audio_emitters.py --format json --output audio_audit.json
```

Generated reports are working artifacts. Runtime diagnostics come from
`AudioPolicy.event_history()` and distinguish presentation, cooldown, unknown
cue, instance-limit and priority-budget refusals in source order.

### AU-0 — Golden-shift listening baseline (launch blocker)

Record one uninterrupted fresh-save golden shift plus fixed listening stations.
Log active voices, buses, peaks, integrated loudness, source distance, room,
cue id and concurrency. Conduct three passes: normal mix, world muted, gameplay
muted. Produce a masking/collision table and identify the first missed cue.

Acceptance: every critical beat has a named cue owner and measured listening
position; no recommendation is based only on reading decibel literals.

### AU-1 — Canonical bus tree and mix-state owner (launch blocker)

Check in the bus layout; route new and critical-route emitters; add parent-level
volume controls; replace direct Master-effect mutation with a composable state
stack. Preserve audible output before tuning.

Acceptance: bus topology is identical regardless of scene entry order; sleep,
embrace, dialogue and telephone states compose and unwind in every order.

### AU-2 — Cue catalog and emitter contract (launch blocker)

Add the data schema, request API, distance profiles, concurrency and diagnostics.
Migrate only the golden-shift cues first. Keep `PropAudio` as the resource bank
behind the catalog until migration proves a different loader is needed.

Acceptance: no critical-route owner requests raw `tick`, `knock`, `pop` or
`hum_loop`; missing cue ids fail loudly in tests and silently in play.

### AU-3 — Vantry audibility vertical slice (K2-G dependency)

Treat the Vantry as the first end-to-end navigation cue: unique signature,
repeat schedule, source truth, door/portal behavior, route audibility and
repair silence. Measure identification and direction at F02 arrival, corridor,
2A threshold and inside 2A against the 45-second task ceiling.

Acceptance: a blinded player can locate it without UI; no radio, telephone,
radiator or ambience cue is confusable with it; repair removes only its owner.

### AU-4 — Interaction/state vocabulary (M3)

Build distinct material/family sets for switches, latches, paper, keys, water,
clockwork, electrical gear and steam. Every hero apparatus gets onset, motion,
completion and refusal only where the mechanism physically earns them.

Acceptance: blinded tests distinguish accept/refuse and running/faulted above
chance without louder-than-normal mastering.

### AU-5 — Architecture and room propagation (M6)

Implement cached room/portal transmission and connect selected network-born
sounds to `AcousticGraphData`. Tie weather beds to live-weather categories and
arbitrate radios/broadcasts per apartment and listener room.

Acceptance: opening/closing one door changes the measured path rather than
teleporting or merely scaling a global bed; clear weather never plays a storm.

### AU-6 — Mix, accessibility and performance gate (release)

Category sliders and semantic cue captions are implemented. Add dynamic-range
presets, full dialogue/world caption coverage, pause-menu reach, subtitle-size
control, mono compatibility, headphone/speaker checks, voice limits and
profiler telemetry. Test ordinary
laptop speakers and inexpensive headphones, not only the development system.

Acceptance: no clipped master, no persistent critical-band masking, stable
voice/CPU budget, captions match audible knowledge, and all critical cues have
non-audio fallback.

## Stop rules

- Do not bulk-retune 141-plus emitters before AU-0 measures the golden route.
- Do not make important cues “win” solely by increasing volume.
- Do not route every source through the 550-node graph.
- Do not let the policy director mutate jobs, cases, doors or prop state.
- Do not use horror stings where a physical source violation can carry meaning.
- Do not add more beds until the existing radio, weather, music and room-tone
  layers have an arbitration rule.

## Engine extraction value

The reusable engine seam is a source-owned cue request feeding a data-defined
semantic catalog, pooled policy director, acoustic scene model, mix-state stack
and evidence logger. Orison-specific cue names and its building graph remain
content. The contracts, tooling, profiler and accessibility parity can carry to
the next project or a standalone world-audio toolkit.
