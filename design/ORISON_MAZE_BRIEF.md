# THE DREAM MAZE — RULED PRODUCTION DESIGN

*Replaces the 2026-08-10 exploratory brief. Ruled 2026-08-15 after the owner
clarified that “the dream world is our reveal” is a title-screen spoiler rule,
not a prohibition on designing or building dream play. The title must remain in
the waking world. The dream itself must now be designed, tested and eventually
shipped.*

**Status: APPROVED — BINDING PRODUCTION DESIGN.** On 2026-08-15 the owner
approved all five rulings formerly requested at the foot of this document:
release-print case binding; capture/fall/contact rather than player-death
language; the deterministic ten-module ring; the 28/38/50/62/76/90 campaign
curve; and the player's own shadow held for endgame design. Bible §I.1 already
rules the core shift; Bible §III.1 rules one Tenant, no true form. This document
now binds the implementation details that connect those laws.

---

## THE ONE-LINE CASE

**After a case is integrated, sleep takes the player into a deterministic wrong
Orison: their service-radio lamp reveals the way and tells the Tenant where they are;
the Tenant wears the departing case's shadow; capture or a building hazard ends
the passage; the player wakes in 4B with one quiet fact left behind.**

The dream is not a second campaign and not a preview on the title screen. It is
the violent punctuation mark at the end of a completed shift.

---

## WHAT IS ALREADY RULED

- The waking condition and the impossible reading remain **both true**.
- Narcolepsy creates a vulnerable interval. It does not create the Tenant and is
  not itself evil, monstrous or a punishment.
- Entry is involuntary and dramatically scheduled. It is not a level selected
  from a menu.
- A call or conversation already in progress is protected. Protection delays an
  eligible onset; it does not erase the request.
- Committed work, case truth, inventory consumption and repair results survive.
- The player wakes at the authored bedside in 4B.
- There is one Tenant. It has no body or true form and cannot be killed. It may
  only wear the current subject's shadow and wound grammar.
- The dream may borrow the Orison. The waking Orison never previews, explains or
  confirms the dream.
- The title screen remains entirely waking-world and spoiler-safe. That is the
  complete scope of the reveal restriction.

Everything below is the approved implementation. Changes require a new owner
ruling and measured replacement evidence; a convenient prototype result does
not silently rewrite the contract.

---

## THE SHIPPED LOOP AND THE OLD PURSUER CONTRADICTION

The first brief selected a pursuer from unresolved cases. The production K6
seam now requests Mina's dream only **after** her complete rule is earned, her
case integrates and the work order closes. At that moment Mina is no longer an
active unresolved case. Selecting a different unresolved case would spoil the
next chapter; pretending Mina is still unresolved would violate the case state.

### Recommended resolution: the release print

Each campaign dream is bound to the case that has just integrated.

1. The Tenant has been satisfied and is letting go of that subject.
2. The dream is the last image left in the vulnerable transition—the **release
   print**—not a renewed waking manifestation.
3. The Tenant may wear the just-resolved subject's silhouette and grammar for
   this one passage. After wake, that case is quiet.
4. Unresolved cases remain fair game for waking intrusions. A later proposal may
   use them for unscheduled ambient dreams, but the six campaign dreams do not.
5. No dream advertises a case the player has not met.

This preserves “a resolved case is quiet” in the waking world, gives the dream
the concentrated truth required by the execution plan, and matches the actual
K6 event order. The future dream request must carry stable `case_id` and
`dream_profile_id` fields; `DreamDirector` must never infer Mina from a hardcoded
job id.

The player's own shadow remains an endgame possibility, not part of the six-case
implementation and not decided here.

---

## THE EXPERIENCE CONTRACT

Every campaign dream must deliver five things and then leave:

1. **Recognition — AMENDED 2026-08-17.** This used to read "at arm's length,
   this is indisputably the Orison", and the rule-of-cool ruling retires that
   clause. It is worth being honest about what the trade costs, because the
   clause was not decoration: the dream was frightening *because* it was your
   building, and a generic gilded dreamscape is not frightening at all.
   Recognition now lives in the BONES rather than the surface. The module
   footprints, the 2.08 m corridor width, the 0.91 m door openings, the 3.015 m
   clear ceiling, the stair that climbs honestly and arrives at a lower floor —
   all measured from the real Orison and all unchanged. You do not recognise
   the wallpaper any more. You recognise the *dimensions*, which is the more
   unsettling half: it is the right size to be home, and nothing else about it
   is.
2. **Global wrongness.** The route makes architectural sense one room at a time
   and cannot possibly make sense as a building.
3. **One continuous decision.** Light on gives information and gives the player
   away; light off buys uncertainty and demands listening.
4. **One case truth.** The environment behaves according to the subject's wound,
   without restaging their dialogue or turning trauma into a boss gimmick.
5. **A hard wake.** There is no loot, score, game-over screen or victory pose.
   The player opens their eyes in 4B and finds one deniable residue.

The target emotion is not “solve the maze.” It is **I know this building, I am
getting better at surviving it, and there still is nowhere to arrive.**

---

## ONSET — A CONDITION, NOT A HORROR SWITCH

`SleepPressureDirector` owns readiness and transition. It receives an authored
eligible window from the core loop, accumulates no case or quest rules, respects
the player's existing protected-interaction flag and asks `DreamDirector` to
enter. It does not own the maze.

### First production behavior

- Mina's first onset is always gradual so the player can learn the language:
  peripheral contrast falls, the field narrows slightly, the mix loses high
  frequencies, the service lamp lags, and the Room 0 hum becomes perceptible.
- Later case profiles may permit sudden onset. The campaign seed chooses between
  permitted onset forms; it does not roll continuously during ordinary play.
- The accessibility setting **Always warn before sleep** forces gradual onset
  for every case without changing progression.
- Calls, dialogue, transaction panels and physical repair commits remain
  protected through the authoritative engaged flag. Onset begins only after the
  protected action finishes and its state commits.
- The transition never drops the player into moving traffic, an elevator seam or
  an unresolved physics fall. If eligibility arrives there, the request remains
  armed until the body is on a stable floor. This is safety, not a cure mechanic.
- Cold water, button mashing, sprinting and “willpower” do not cancel an attack.
  The game does not teach a false cure.

### Medical representation guardrail

Symptoms vary; not every person with narcolepsy has every symptom. The first
slice uses excessive sleepiness, sleep attacks and sleep/wake hallucination. It
must not automatically equate emotional intensity with cataplexy unless the
protagonist is explicitly characterised that way after lived-experience and
clinical review. Sleep paralysis may be a brief wake presentation, but it must
be skippable and must never be required to understand what happened.

Reference baseline, not a substitute for consultation:

- NHS, “Narcolepsy”: <https://www.nhs.uk/conditions/narcolepsy/>
- NHS, “Narcolepsy — Symptoms”: <https://www.nhs.uk/conditions/narcolepsy/symptoms/>

---

## THE MAZE: AUTHORED ROOMS, SYSTEMIC ASSEMBLY

The first brief proposed unconstrained fractal generation. That is visually
tempting and production-hostile: arbitrary geometry makes collision, acoustics,
lighting, culling and fair hazards difficult to prove. The replacement is a
small authored module kit assembled into a deterministic graph.

**Local truth is authored. Global impossibility is assembled.**

Every module is a measured extraction or reconstruction of a real Orison space.
Its skirting, wallpaper, door dimensions, pipe runs, hardware and wear remain
photo-faithful. Wrongness comes from connections, repetition, scale rhythm and
impossible return—not melted walls or generic dream particles.

### The ten-module vocabulary

| ID | Waking source dimensions | Dream work |
|---|---|---|
| `D00_4B_THRESHOLD` | 4B vestibule, 2.20 × 1.25 m | One entrance, every time; the room behind is absent |
| `D01_F04_LONG_HALL` | 2.08 m corridor width; 19.30 m from three true bays | Establishes the service-lamp rule and the receding practical |
| `D02_DOGLEG_STAIR` | 6.32 × 6.32 m well; 1.70 m flights; 3.20 m rise | Goes up honestly, arrives at a lower floor number |
| `D03_LIFT_VOID` | 4.10 × 3.50 m hall; 2.15 × 2.20 m shaft; 0.91 m door | One working door, one open shaft, chain and draught hazard |
| `D04_BATHROOM_PROCESSION` | four 2.20 × 2.40 m bathrooms in a 9.60 m run | Four locally exact bathrooms sharing one impossible wet wall |
| `D05_SERVICE_RISER` | 2.08 × 6.50 m corridor bay | Narrow listening room; heating, water and signal separate audibly |
| `D06_LAUNDRY_BOILER` | laundry 8.14 × 6.98 m; boiler 8.14 × 10.53 m | Machinery rhythm, steam hazard and long occluded turns |
| `D07_LIGHT_COURT_WALK` | 6.32 × 6.32 m well; 1.70 m clear walk | Interior exterior: windows face rooms that cannot occupy the volume |
| `D08_CASE_ECHO` | 2A main-room source, 8.14 × 5.80 m | One small case-authored substitution, never a full duplicate apartment |
| `D09_RETURN_HALL` | 2.08 × 6.50 m corridor bay | Looks like arrival; physically returns to `D01` from the wrong side |

All flat modules retain the waking 3.015 m clear ceiling. Ordinary connectors
retain the authored 0.91 m door opening; the player capsule is 0.66 m wide. No
dream connector is narrowed below waking code merely to manufacture tension.

The base graph is a ring with one seeded branch, not a cloud of random rooms:

```text
 D00 → D01 → ┬→ D02 ─┐
             └→ D03 ─┴→ D04 → D05 → ┬→ D06 ─┐
                                      └→ D07 ─┴→ D08 → D09
                                               ↑          │
                                               └── D01 ←──┘
```

- `D02` and `D03` exchange left/right presentation by seed and reconverge.
- `D06` and `D07` exchange order by seed and reconverge.
- `D09` joins the back of `D01` with valid physical geometry. The player does
  not teleport; the impossible loop is visible only after they recognise it.
- Mina's first run exposes `D00`, `D01`, `D03`, `D04` and `D05`. Later campaign
  budgets expose more of the same saved building; only the final slot reaches
  `D09` and recognises the complete fold.
- A warm 4B practical appears one connector ahead. It never slides away in view;
  the lit fixture changes only while a wall or closing door occludes it.

### What the seed may and may not change

One 64-bit dream seed is created with the campaign and never rerolled. It may
choose branch handedness, repeated-door count within authored limits, hazard
sockets, material repetition and which valid connector carries the next light.
It may not change door dimensions, invent coordinates, overlap modules, block
the only traversable connector or make an audible tell point the wrong way.

Source data belongs in `game/data/dream_module_catalog.json`. A generator reads
that catalog and emits the assembled graph and compact dream assets. Generated
outputs are never hand-edited. The generator exits nonzero for overlap,
unmatched connector, insufficient capsule clearance, bad step height, invalid
door swing, unreachable module, inaudible hazard route or unstable seed hash.
The waking `gen_layout.py` remains the sole owner of waking-world coordinates;
the dream generator may reference its source records but may not write them.

---

## THE LIGHT IS THE GAME

The player brings the same physical Vantry service radiophone and attached warm
tungsten lamp into the dream. No new magic lantern appears and no tutorial panel
explains it. Q4 replaced the legacy phone dependency with the device-neutral
service-set light contract while retaining honest carried lag. N3 now proves
that contract through one toggle path shared by keyboard, controller and touch
before any production pursuit is built.

| State | What the player gains | What the Tenant gains |
|---|---|---|
| **Light on** | floor edges, hazards, connectors, case marks | a fresh target, a faster route and a shadow to cast |
| **Light off** | time and broken line-of-sight | the last known point plus the player's footsteps |

Darkness is safer, never safe. Turning the lamp off breaks visual acquisition
and decays pursuit confidence; the Tenant continues toward the last light splash
and listens for movement. There is no hiding state, closet prompt or stealth
meter. Standing still in darkness delays capture but cannot make the run endless.

Balance by outcomes, not lore numbers:

- On a straight control corridor, leaving the light on must reduce median
  survival by at least one third.
- Turning it off after acquisition must buy a clearly audible six seconds or
  more on Mina's run.
- The beam may attract from its splash on a wall through an open doorway; it may
  not attract through opaque architecture.
- Repeated toggling has no stamina cost and no arbitrary cooldown. The risk of
  giving away a new position is the cost.
- The service lamp never flickers at photosensitive frequencies. Case pressure changes
  intensity slowly or cuts it cleanly.

The world remains readable enough to move with the light off: black level keeps
the nearest floor silhouette, and the receding practical supplies a vague
orientation. “Off” means navigation by sound and memory, not a black video file.

---

## THE TENANT: A NAVIGATION BODY WITH NO BODY

The dream does not buy a monster model.

- One invisible navigation body owns position, last-known target, hearing and
  capture distance.
- A **shadows-only proxy** borrows the current subject's broad silhouette. It
  casts onto walls and floor when the service lamp finds the right angle, but the
  proxy itself never renders. No face, eyes, hands, texture or reveal exists.
- Case effects occur in the architecture: captions, stamps, feedback, broken
  appliances, radio fragments or contradictory labels. They are not particle
  costumes wrapped around a humanoid.
- The Tenant never uses the resident's speaking voice. It borrows rhythm,
  vocabulary and signal carriers from `PoltergeistLibrary`.
- Capture is the service-lamp beam being occluded at intimate distance, the case sound
  reaching its missing fifth position and the image cutting to black. There is
  no attack animation and no creature close-up.

This realizes “wears the subject's shadow” literally while preventing a
temporary graybox mesh from becoming a canonical true form.

### Pursuit contract

The Tenant is slower and less certain without a light target, faster once a lit
surface acquires the player, and always capable of finishing the run. It follows
the validated navigation graph; it does not teleport behind the camera or cross
closed collision. If the authored time cap expires, the terminal fold places
the player back on the known ring with the Tenant legitimately occupying the
shorter converging route. The topology closes the distance; rubber-banding does
not.

Being caught is called **capture** in code and tests, not player death. A fall,
electrical contact or crushing hazard produces a different `dream_ended`
outcome, but all are dream outcomes and all wake the same living character.

---

## EIGHT FIXED HAZARDS

Eight hazards are provisioned across the full saved maze. Mina teaches only
three. Every hazard has a sound that precedes danger, a visible confirmation
under the service lamp and one reconstructable cause. “The player understands in
the half-second before impact” remains the fairness bar.

| Hazard | Kind | Sound in darkness | Lit confirmation | Result |
|---|---|---|---|---|
| Open lift void | positional | deep draught, loose chain below | absent car and sill edge | fall → wake |
| Vantry signal trunk | conditional | carbon hiss and rising electrical beat | arc reaches toward the lit beam splash | contact → wake |
| Hollow runner | conditional | one dry creak two steps ahead | bowed boards and split tack line | running breaks it; walking crosses |
| Boiler relief sweep | rhythmic | three pipe knocks, then pressure hiss | white steam crosses one lane | contact → wake |
| Counterweight passage | rhythmic | cable climbs, brake strikes twice | shadow traverses the shaft opening | impact/stagger, then pursuit |
| Fire-door return | triggered | hinge scrape before latch | door begins closing behind | route closes; pursuit continues |
| Laundry mangle belt | triggered | belt slap at a fixed interval | rollers pull a hanging sheet across path | contact → wake |
| Breathing partition | positional/rhythmic | plaster grit moves left to right | corridor narrows on the same cycle | crush → wake |

The acoustic graph logic is reusable; the current `acoustic_graph.json` is not.
It is tied to waking-world ids and coordinates. The dream generator must emit a
small graph using the same network, delay and damping schema, then feed it to a
shared route planner. Claiming the waking graph already solves dream acoustics
would be false.

Mina's run uses the open lift void, signal trunk and hollow runner. One teaches
position, one teaches light consequence, and one teaches that sprint is not
always the answer.

---

## THE SIX CASE GRAMMARS

All six use the same movement, service-set and pursuit code. A profile changes room
behavior, signals and authored substitutions—not controls or manager logic.

| Case | What the wrong building does | What light changes | Truth the player can recognise |
|---|---|---|---|
| Mina — Caption Crisis | nouns appear on surfaces, then expand into claims about the player | illumination gives each visible thing another annotation; darkness leaves the blank alone | silence does not require annotation |
| Peter — Form Corridor | reversing at a junction duplicates the pending corridor and stamps another door | light reveals instructions but also makes every hesitation legible | uncertainty does not prevent action |
| Juno — Feedback Tetris | open signal paths echo into solid acoustic partitions | the lit service set is one clean channel; frantic toggling feeds delayed copies | connection requires an open channel |
| Cal — Memory Radio | receiver fragments hold rooms in moments that have already ended | dwelling on a lit receiver loops it; darkness lets the phrase finish and the door release | presence is not preservation |
| Omar — Unrepairable | every revisited machine returns with a new impossible fault | inspection reveals the damage but cannot restore it; moving on preserves distance | some things are not repairable |
| Mae — Contradictory Antiques | left and right routes present incompatible histories and rejoin at the same object | light shows one provenance, darkness lets the other remain audible | contradiction is survivable |

These are navigation and pursuit grammars, not six minigames. No dream adds an
inventory, dialogue choice, repair interaction or bespoke control. Peter remains
the second case. The order of Juno, Cal, Omar and Mae remains an owner decision,
so run length belongs to campaign slot data rather than case code.

---

## MINA'S FIRST RUN — EXACT PLAYABLE SCRIPT

Target: **14–28 seconds**, with a first-time median of 22–26. The cap is long
enough to learn one decision and two audible hazards, short enough to end before
the player masters either.

| Time / station | Image and sound | Intended learning |
|---|---|---|
| onset, 2–3 s | waking mix narrows after Mina's resolved conversation; committed state is already saved | this is happening after the work, not undoing it |
| 0–5 s, `D00` | player opens their eyes standing at the 4B threshold; service lamp already lit; a warm 4B practical waits ahead where 4B cannot be | move toward recognition; no tutorial text |
| 5–11 s, `D01` | beam reveals `DOOR`, `FLOOR`, `PLAYER`; label clicks answer behind; a borrowed shadow crosses one transverse wall; twelve metres down the hall a hollow runner gives one dry creak two steps ahead | light supplies knowledge and position to the Tenant; sprint is not always safe |
| 11–17 s, `D03` | elevator door stands open; draught and chain come from below; stair connector remains acoustically dry | sound can veto a visually inviting route |
| 17–20 s, `D04` | a locally exact bathroom is followed by the same wet wall again | global layout is wrong |
| 20–26 s, `D05` | Vantry trunk hum rises; its arc reaches only while the beam paints the conduit; darkness leaves a clean narrow passage | light can activate the danger it reveals |
| 26–28 s, riser end | the warm practical turns on beyond a sealed grille; captions become assertions; the Tenant reaches the service branch from the shorter side | the guiding light was never a reachable exit |
| wake | black, one absent fifth beat, eyes open at the authored 4B bedside; no failure screen; K6's factual `REFRIGERATOR` residue remains | the passage counted without becoming proof |

**AMENDED 2026-08-17 — the hollow runner moves from D04 to D01, by owner
ruling ("change the fiction").** This table used to script the runner into
`D04_BATHROOM_PROCESSION`. The N2 catalog places its socket in
`D01_F04_LONG_HALL`, and D04 carries no hazard sockets at all, so the script
and the built maze disagreed and the hazard could not be implemented from
either.

The catalog is the harder thing to move: its SHA is what Gate A's audit
describes, so re-siting the socket would invalidate a closed gate to satisfy a
sentence. The owner ruled the sentence changes instead.

It is also the better fiction, which is why the ruling was cheap. The runner's
lesson is *sprint is not always the answer*, and D01 is the only module long
enough to tempt a sprint — 19.30 m of straight hall, with the socket twelve
metres down it. D04 is a 9.60 m run of four bathrooms whose own lesson is that
the layout is impossible; a board breaking there would have competed with it.
The two hazards now sit where their lessons do, and `D01`'s row teaches both
halves of the light decision and the sprint in the one place the player has
room to make either mistake.

Nothing else moves. The socket, the catalog, Gate A's audit and the 0.90 s
warning the runner owes are all untouched; only this table was wrong.

If the player keeps the light on or chooses the shaft, the run ends earlier. If
they play cleanly, the service graph—not a speed cheat—delivers the final
capture. Refusing the last grille is valid; the approaching signal eventually
reaches them. There is no fake door interaction and no invisible timer
displayed. The complete `D09` fold is held for the final campaign run, when the
player has enough learned geography for recognition to hurt.

---

## CAMPAIGN LENGTH WITHOUT META-PROGRESSION

Nothing is earned or carried inside the maze. The saved seed makes the building
learnable; case order opens a longer authored budget.

| Campaign slot | Maximum run | New demand |
|---:|---:|---|
| 1 — Mina | 28 s | light acquisition, shaft, signal trunk |
| 2 — Peter | 38 s | first branch and hesitation grammar |
| 3 | 50 s | first rhythmic hazard |
| 4 | 62 s | `D06`/`D07` order becomes legible |
| 5 | 76 s | two hazards can interact with pursuit |
| 6 | 90 s | complete ring and terminal return are recognisable |

Performance does not lengthen the leash. There is no best time, distance,
unlock, shortcut, collected object or resident congratulation. Player knowledge
is real; character progression inside the dream is not.

---

## VISUAL AND AUDIO LANGUAGE

### Image — OWNER RULING 2026-08-17: COOL IS THE DEFAULT

**THIS SECTION IS SUPERSEDED AND THE SUPERSESSION IS DELIBERATE.** On
2026-08-17 the owner ruled, in order: *this is a demonstration project of what
we can create, the rule of cool is key — make it good, not correct*; *let the
maze breathe, make it unsettling, disorienting, like a funhouse made to
distract and terrorize*; *rewrite our design to default to cool across the
board*; and *make the whites map to a molten golden liquid reflection*.

That retires, by name, the restraint language that stood here: soot black and
dull brass as the palette, the ban on anything past one restrained accent, the
requirement that surfaces stay dirty and plausible at touch distance, and the
arm's-length recognition clause in §THE EXPERIENCE CONTRACT. The old text is
not wrong about horror. It is a different game, and it is no longer the one
being built.

**THE FRIEZE IS THE WORLD.** The dream is Klimt's Stoclet Frieze — *The Tree
of Life, Expectation and Fulfilment* — taken apart and hung on the
architecture. The load-bearing fact about that painting is that it is not one
texture: it is five pattern languages sharing one palette, each bounded by flat
ground so none degrades into wallpaper. So each surface class wears exactly
one, and the assignment is functional rather than decorative:

| Surface | Motif | Why |
|---|---|---|
| walls | spiral tendrils | the tree: gold *line*, a wire that coils — structure, not fill |
| floor | mosaic blocks | the textile, underfoot |
| ceiling | canopy over starfield | the tree closes overhead in thickets and parts onto night |
| doors | chevrons | Expectation's robe: sharp, directional, a way *through* |
| hazards | concentric eyes | Fulfilment's robe — the watching mark, reserved for what can hurt you |

The reason for one motif per class rather than one skin everywhere is that
**ornament stops being decoration and becomes wayfinding.** In a maze whose
entire job is to lose you, the pattern says what a thing *is* — and if a
surface is watching you, it is because it is dangerous.

**ONE DEPARTURE FROM THE PAINTING, DELIBERATE.** The frieze is gold on cream.
Rendered literally under one hot lamp, that cream ground is the brightest thing
in frame and blows to white the instant the beam touches it. So the VALUE
structure inverts while the hue structure does not: Klimt's marks, palette and
bounding rules on a dark ground, so the leaf is the bright thing. That is what
*barely lit by a guttering lamp* requires, and it is how gilding reads at night.

**THE GOLD IS METALLIC, NEVER EMISSIVE.** Gold leaf is not a light source; it
is a mirror with a colour. Emission would have been easier and would have
destroyed the game, because a world that glows needs no lamp and the light
decision is the one mechanic this passage is built on. There is no ambient at
all, and beyond the lamp's pool is pitch blackness. The consequence is the
point: **the world is only beautiful where you are looking, and being lit is
what is hunting you.**

The one sanctioned exception is the stars in the canopy's open spaces. A star
is a light and not a leaf.

**THE WHITES ARE MOLTEN.** Every pale area is liquid metal. Under the beam the
ornament's own coordinates flow, the surface beads and re-forms, and roughness
collapses toward a mirror; away from it, the gold is cold and solid. What the
molten metal reflects is a world that exists nowhere in the scene — the Orison
as Klimt would have painted it, its residents gold-robed and facing you, one of
them without a face. See `KLIMT_REFLECTED_WORLD_PROMPTS.md`. Because the
reflection is gated on lamp proximity, **the dead are visible exactly and only
when you are spending the light that draws the Tenant.**

**SUBSTANCE FLOWS; STRUCTURE DOES NOT.** This narrows the old rule rather than
deleting it, because half of that rule was fairness and not taste. Topology
still changes only across occlusion: rooms, connectors and route never
rearrange in view, and a player must never lose a way out because the building
moved while they were looking at it. Surface may move in view. Substance flows,
structure does not.

**THE MAZE BREATHES.** Dense ornament against bare ground, never uniform
clothing. This is Klimt's own bounding rule and it is also the only way the
wayfinding claim above can be true: signal requires ground, and a corridor
ornamented edge to edge is not ornamented at all — it is textured, and texture
is noise. Bare ground is not unfinished. It is the silence the ornament is
measured against.

**IT IS A FUNHOUSE, BUILT TO DISTRACT AND TERRORISE.** The maze is not a
neutral space that happens to be wrong; it is a made thing with an intention
toward the person inside it. The domain drifts, so the wall you looked away
from is not quite the wall you look back at. Jewels in gold settings hang in
the tendrils, shed as rain, and set into the floor's mosaic — so the ground
underfoot is visibly what fell off the ceiling.

**THESE TWO RULES ARE NOT RESTRAINT AND ARE NOT SUPERSEDED.** They are safety
and accessibility, they survive every ruling above, and no appeal to the rule
of cool reaches them:

- **No strobe, and no flashing at photosensitive frequencies.** Every animated
  element here — the ornament's breath, the domain drift, the melt, the
  starlight, the lamp's own warm-up and pop — runs well under a hertz or is a
  single transient on a deliberate player action, and the lamp's transient is
  rate-limited so that mashing the switch cannot produce a flicker.
- **No forced camera roll, fisheye sprint effect or chromatic-aberration
  assault.** Disorientation is bought with space, ornament and pursuit, never
  by taking the camera away from the player.

Repetition remains architectural: too many identical doors, one seam
returning, the same worn stair edge above itself. That was never restraint —
it is the maze's whole method.

### Sound

- Mix order: immediate hazard, Tenant bearing, radio/lamp response, route cue,
  Room 0 hum, case grammar, room tone.
- The four-part motif remains short — short — pause — long — missing. Capture
  cuts on the absent fifth position; it does not complete the theology with a
  stock impact.
- Hazard cues are spatial sources and remain localisable on ordinary stereo.
  Headphones may improve them but are never required.
- The Room 0 hum is a vital sign, not the Tenant's voice.
- Silence is mixed. Turning the light off removes visual certainty, not every
  sound bed.

---

## ACCESSIBILITY IS PART OF THE FIRST BUILD

- **Always warn before sleep:** forces gradual onset.
- **Dream pursuit — Reduced:** slows acquisition and capture while preserving
  the light relationship and the same topology.
- **Dream pursuit — Transition only:** a 10–12 second hazard-free passage ends
  in the same wake and residue for players who cannot use a chase.
- **Directional danger captions:** optional concise cues such as
  `[CHAIN BELOW — LEFT]`; these are accessibility presentation, not diegetic
  Mina captions.
- **High-contrast edges:** lifts immediate floor/shaft separation without
  brightening the entire scene.
- **No flashing:** default and non-negotiable; light effects cut or breathe
  below hazardous frequencies.
- **Motion comfort:** no forced head roll, violent FOV pulse or compulsory wake
  paralysis. Any bedside immobility beat is skippable.

All three pursuit modes produce the same campaign state. Horror intensity is
not a difficulty gate and never changes what the player is allowed to know.

---

## OWNERSHIP AND SAVE CONTRACT

| Concern | Owner | Saved facts |
|---|---|---|
| case/job eligibility | existing `CoreLoopDirector` and job data | existing `dream_pending`, case and job facts |
| onset timing/protection | new `SleepPressureDirector` | pressure seed/state and armed request only |
| scene transition/run/outcome | new `DreamDirector` | active flag, case/profile id, maze seed/revision, ending outcome |
| topology | `DreamMazeBuilder` plus generated module data | campaign seed; never live node transforms |
| pursuit | `DreamPursuer` reading a profile and graph | no transform or confidence save |
| hazards | data-authored sockets and one shared hazard base | no per-run persistence |
| waking residue | existing `RealityState.apply_waking_residue` | stable residue id and factual payload |

The clean scene boundary is a small persistent `CampaignShell` containing the
loop, sleep and dream coordinators plus a replaceable `WorldSlot`. `BuildingRoot`
and `DreamMazeRoot` do not render or simulate together. This avoids hiding a
full eight-floor building behind the dream and avoids placing the maze at an
invented far-away coordinate in the waking `World3D`. The shell contains no
case, repair, shop, dialogue, pursuit or hazard rules.

### Save/load boundaries

1. `dream_requested` armed but protected: restore the armed onset once.
2. On entry: commit `dream.active`, case/profile id, seed and maze revision
   before replacing the waking world.
3. Loading an active dream reconstructs the same graph and restarts at `D00`.
   It does not attempt to serialize a chase frame.
4. On ending: commit outcome and `return_pending`; apply the stable residue
   idempotently; rebuild the waking world; call the existing wake boundary;
   clear `return_pending` last.
5. Loading during that final transaction reconciles forward to the bedside.
   It cannot duplicate residue, resurrect an item or reopen a case.

**N4 closed this substrate on 2026-08-15.** `CampaignShell` now keeps one
persistent CoreLoopDirector and DreamDirector around an exclusive one-child
WorldSlot. `DreamBoundaryTest.tscn` passes 36/36 checks using the real JSON path
at armed, entered, active, return-pending and awake, including same-seed D00
reconstruction, production BuildingRoot injection and one idempotent Mina
residue. The exact 64-bit campaign seed is stored as sixteen hexadecimal digits
so JSON cannot round it. Production intentionally remains armed in waking
Orison until N5's SleepPressureDirector calls entry; DreamMazeRoot currently
contains only the boundary payload, not production maze geometry.

**N5 closed protected onset on 2026-08-15.** One persistent
`SleepPressureDirector` now selects an authored onset form once from the exact
campaign seed, with Mina fixed to a 2.60-second gradual form and the shipped
Always-warn setting able to force gradual for later profiles. The existing
`call_locked` authority, the real player floor state, and narrow elevator and
traffic owner queries pause but never cancel the request. Real-file midpoint
restore and one-entry proof pass 20/20; production A/A/B/C frames and measured
pixel deltas are recorded in `art/renders/dream_onset_n5/README.md`. N5 adds no
maze art, Tenant or hazard.

**N6 closed the maze and the Tenant on 2026-08-15.** `DreamMazeBuilder`
assembles the N2 catalog into runtime geometry, and `DreamPursuer` walks the
chain as an invisible CharacterBody3D wearing the `mina_vale` mesh forced to
`SHADOW_CASTING_SETTING_SHADOWS_ONLY` — the Tenant is a shadow with a
collision body, never a visible figure. Its pursuit contract is seeded once
from the exact campaign seed, so a reloaded dream chases identically.
`DreamPursuitTest.tscn` passes 39/39. Door approach waypoints were added after
the pursuer oscillated in openings; passed waypoints are pruned so a route
never doubles back.

**N7 opened the ending on 2026-08-16, steps 1–6.** The run can now end three
ways and each is fair:

- **One funnel.** `DreamMazeRoot._commit_outcome()` is the single exit. It
  latches, so a simultaneous capture and contact cannot double-commit, and it
  refuses outright rather than half-succeeding when no CampaignShell owns the
  transaction.
- **A clock.** The slot's authored ceiling (28 s for Mina) is read from the
  catalog, and expiry folds the pursuit — the Tenant is re-placed on a chain
  waypoint ahead of the player rather than the run simply stopping. The fold
  re-places without rerolling the seeded contract.
- **Hazards in the plan.** `DreamMazeBuilder` emits `plan.hazards` from
  catalog sockets, mirroring the local point about its module's depth axis
  when the seed mirrors the module. Hazards never enter the door list, so a
  socket can never cut a real opening.
- **The fairness contract.** `DreamHazard` runs tell → condition → contact in
  that fixed order. The tell is **unconditional**: you hear the trunk whether
  or not your lamp is on and whether or not the danger is currently live. A
  hazard that could contact before its tell started would be a bug by
  construction.
- **The Vantry signal trunk** is the first live hazard and the one that proves
  the pattern. Its condition is `lamp_on` — the arc reaches for the beam, so
  darkness leaves a clean narrow passage. This is the ruled lesson of §"THE
  LIGHT IS THE GAME" made mechanical: light can activate the danger it
  reveals.
- **The open lift void is a hole, not a radius.** The builder subtracts its
  mouth from the floor slab with the same rectangle cut the doors use, lines
  the shaft below so a fall reads as a shaft rather than as the world running
  out, and the player falls through real missing floor under real gravity.
  The hazard only reads the result. Nothing about the void is authored twice:
  its mouth is derived from the socket's own `clearance_radius_m` of 0.45,
  spent as a half-side to give a 0.90 m square — near enough the 0.91 m
  connector width to read as a lift doorway laid into the floor, the one you
  would have stepped through if the car were there. (Half of 0.91 is 0.455,
  not 0.45; the 10 mm is inert against a 0.66 m capsule, but the two numbers
  are not the same number and this document should not say they are.)
  Deriving rather than authoring leaves the catalog SHA untouched, so N2's
  Gate A audit still describes the shipped catalog. The Tenant translates in XZ without gravity, so a shadow
  crosses the open shaft mouth without falling in, which is correct for what
  the Tenant is.

`DreamHazardTest.tscn` passes 30/30 across five blocks, and measures the
fairness bar rather than asserting it: every impact records when its tell
started, how far away the player was, and the realised warning in seconds,
and `unfair_impacts()` answers Gate C's question as one list that must stay
empty. Perception rows carry an eight-sector bearing and never a distance, so
directional captions convey what the ear conveys and nothing the eye could not
have earned. Mina's profile allowlist arms three of the four placed sockets;
the slot-3 rhythmic counterweight sits in her D03 unarmed, which is how a
shared catalog serves six cases.

The Gate C machine harness and the N7 render record landed the same day; see
the Gate C entry above. Measuring the perception channel also caught a live
bug that reading it had not: the sector table named left as right, because
`Vector3.signed_angle_to` about +Y is positive counter-clockwise while the
table reads clockwise. Every directional caption was mirrored.

**The production dream WorldEnvironment landed 2026-08-17**, along with the
carried black level and the ruled receding practical, and the finding that
came with it is worth keeping: the dream had shipped with no environment at
all, because `CampaignShell` frees the waking world that owns one and
`DreamMazeRoot` built no replacement. Lamp-off was literally a black frame —
the thing §"THE LIGHT IS THE GAME" forbids in those words. It went unseen
because `dream_pursuit_shot.gd` built its own environment and two OmniLights
frankly named `RecedingOrientationControl` and `NearestFloorBlackLevelControl`
before photographing anything, so N6's proof frames demonstrated navigable
darkness in a scene no player could enter. Record and paired frames:
`art/renders/dream_env_n7/README.md`.

**The hollow runner's module was ruled 2026-08-17.** The owner chose "change
the fiction": §"MINA'S FIRST RUN" now scripts the runner into D01, where the
catalog's socket has always been, and the catalog, its SHA and Gate A's audit
are untouched. See the amendment note in that section for why D01 is also the
better home for the lesson.

N7 steps remaining: the trunk's lit beam-splash confirmation.

Signals remain narrow: `dream_requested(case_id, profile_id, window)`,
`dream_entered(case_id, seed)`, `dream_ended(case_id, outcome)` and the existing
`waking_residue_applied`. No dream owner advances WorkOrders or RealityCases.

---

## PROPOSED FILES — FIRST MINA GRAYBOX ONLY

```text
game/data/dream_module_catalog.json
game/data/dream_profiles.json
game/scripts/dream/sleep_pressure_director.gd
game/scripts/dream/dream_director.gd
game/scripts/dream/dream_maze_builder.gd
game/scripts/dream/dream_pursuer.gd
game/scripts/dream/dream_hazard.gd
game/scenes/dream/DreamMazeRoot.tscn
game/scenes/campaign/CampaignShell.tscn
game/tests/DreamMazeGenerationTest.tscn
game/tests/DreamLightTest.tscn
game/tests/DreamLoopTest.tscn
game/tests/DreamMazeShot.tscn
art/data/gen_dream_maze.py
art/data/dream_maze_layout.json          # generated control assembly
art/renders/dream_maze_n2/dream_maze_top_down.svg
art/blender/build_dream_modules.py
```

Do not create six scenes, six directors or six pursuer scripts. Mina proves the
shared contract; Peter proves the profile seam; only then do the remaining four
profiles become production work.

---

## ACCEPTANCE GATES

### Gate A — deterministic space — COMPLETE 2026-08-15

N2 closed this gate at canonical seed 0. The source catalog, generated assembly,
dimensioned drawing and reproduction record live at
`art/renders/dream_maze_n2/README.md`. Result: 10 modules, 12 directed edges,
8 hazard sockets, 18 live source-provenance checks, 100/100 deterministic
seeds and 0 unresolved findings. The reproduction record reports structural
diversity with the seed value excluded from its identity hash. No Godot runtime
claim is implied; that begins at Gate B.

- 100 generated seeds pass overlap, connector, capsule, step, swing,
  reachability, hazard-route and stable-hash audits.
- Repeating one seed produces byte-identical graph data.
- A top-down drawing dimensions every module, connector and hazard socket.

### Gate B — the light decision — COMPLETE 2026-08-15

N3 closed this gate in a disposable 42.00 × 3.20 × 3.00 m control corridor,
not production maze art. Across eleven paired fixed seeds, median capture is
3.425 s with the lamp held on, 11.358 s held off, and 11.225 s when extinguished
after acquisition: light-on shortens survival by 69.8%, and switching off buys
7.800 s. A separate real `StaticBody3D` wall blocks acquisition while its open
end permits it. Keyboard L, controller left shoulder and touch LAMP reach the
same `PlayerController.toggle_lamp()` owner. The only diagnostic figure is a
`SHADOWS_ONLY` capsule and never enters the beauty pass. Exact geometry, raw
per-seed results, corrected black-level renders and the rejected first-run
failure are recorded in `art/renders/dream_light_n3/README.md`.

- In paired deterministic runs, light-on shortens capture by at least one third.
- Light-off buys at least six seconds after acquisition without producing an
  indefinite safe state.
- Acquisition never crosses an opaque wall; the shadows-only proxy never renders
  directly in beauty frames.
- Keyboard, controller and touch drive the same public light toggle.

### Gate C — fair darkness — TWO OF THREE CLOSED 2026-08-16

- **NOT CLOSED, and not closeable by a script.** In blinded tests, each of
  Mina's three hazards is identified by bearing and type before contact in at
  least 80% of trials. This is a human playtest. `DreamPerceptionTest.tscn`
  proves the *precondition* — that from all sixty approaches there was
  something honest to identify, correctly aimed, in time — and holds itself to
  100% rather than 80%, because if the machine side is imperfect the human
  number measures our bugs instead of their perception. The three cues are
  mutually distinguishable (`TRUNK HISS`, `CHAIN BELOW`, `DRY CREAK`); whether
  players *do* identify them is theirs to answer.
- **Closed.** Every impact log includes the tell start, player distance, light
  state and causal hazard id. `DreamHazard.impact_record()` carries all of
  them plus the realised and owed warnings, and
  `DreamHazardField.unfair_impacts()` reduces the question to one list that
  must stay empty.
- **Closed at the data layer.** Directional-caption mode conveys the same
  information without revealing hidden geometry: rows carry an eight-sector
  bearing and a cue, never a distance, module id or position, and the
  direction is restated whenever the sector it names stops being true.
  `DreamCaptionLayer` renders each tell as the cue and the sector and nothing
  else, capped at three readable lines, under the
  `dream_directional_captions` setting — off by default, because the mix
  already carries this and the dream's grammar is listening.

Three measurements per hazard, all warned, all fair, all bearing-true. The
routed approach a player really makes gives 1.12 / 1.58 / 0.92 s against
0.90 / 0.90 / 0.75 s owed. Ten in-room bearings each locate the best in-room
margin at 1.12 / 1.09 / 0.92 s. Full numbers, and a correction to how this
paragraph first read, in `art/renders/dream_hazards_n7/README.md`.

*This section previously claimed "sixty approaches, twenty bearings per
hazard". It was one approach replayed twenty times: the sweep's route
discarded its bearing argument on every path slot 1 actually takes. Corrected
2026-08-16 after adversarial review.*

**Binding constraint, on the dream acoustic graph.** The authored tell radii
(4.6–5.5 m) exceed the rooms' short axes, so a tell is a room-entry event
rather than a proximity one and a warning can only be measured as time
actually walked.

The constraint holds, but the first reasoning given for it here was wrong and
is corrected. It claimed "no room is that deep", which described
`D03_LIFT_VOID` (4.10 — 3.50) and silently generalised:
`D05_SERVICE_RISER` is 6.50 — 2.08 and `D01_F04_LONG_HALL` is
19.30 — 2.08, and every room here is long enough on its long axis to
spend its whole tell radius. The real reason is that **the sockets sit
mid-room**, so the walk from a doorway to a socket is short however long the
room is.

That is now measured directly rather than inferred. With the tell occluded to
the hazard's own room, a player crossing the threshold gets **0.52 s** at the
trunk and **0.19 s** at the void, against the 0.90 s their sockets owe. Only
the hollow runner, whose socket sits 12 m down the long hall, clears its bar
from its own threshold at 0.92 s.

So when the dream-scoped graph is built it must **attenuate** hazard tells
across a wall and must not **silence** them, or Gate C breaks on the day it
lands. `DreamPerceptionTest.tscn` recomputes the doorway margins every run and
prints an OCCLUSION VERDICT line; it is that work's acceptance check.

### Gate D — the complete Mina passage — CLOSED 2026-08-16

**The two halves are now connected.** `GateDJoinTest.tscn` plays the Mina
shift inside a real `CampaignShell` and lets the production path carry it into
the real dream. Three runs, one per ending: `capture` 69/69 in 38 s,
`contact` 71/71 in 35 s, `fall` 71/71 in 34 s — each a full played shift to
its own rebuilt bedside, all inside the documented 60 s bound. World sequence
`waking -> dream -> waking`. `GoldenLoopTest` is untouched and still 87/87.

What follows is the record of what the seam was, because it explains the
harness's shape.

- `GoldenLoopTest.tscn` runs the whole continuous Mina shift and passes 87/87,
  but it instantiates `scenes/building/orison_root.tscn` **directly** and
  answers the dream request with a test-only `DreamStub` that records one
  entry and calls `notify_wake_complete()`. Its own comment is honest about
  this: "No production dream mechanics." The stub predates N4.
- `DreamPursuitTest.tscn` runs the real `CampaignShell`, the real
  `DreamDirector` entry, the assembled maze, the Tenant and a real capture
  through to wake — but it reaches that state through
  `_seed_completed_shift()`, which writes the finished job facts straight into
  `RealityState` rather than earning them by playing the shift.

So no test yet walks the whole thing: shift played, dream entered for real,
passage traversed, waking world rebuilt, bedside reached.

The seam is small, which is the good news. `CampaignShell.waking_scene_path`
defaults to `res://scenes/building/orison_root.tscn` — **the same scene
GoldenLoopTest already instantiates standalone**. Joining them means spawning
the golden loop's world through a `CampaignShell` instead of directly, then
deleting the stub and letting the production `SleepPressureDirector` call
entry. Nothing needs redesigning for that to be possible.

Recommended as a new harness rather than an edit to `GoldenLoopTest`:
that test is the authoritative waking-side proof, it was repaired recently by
a parallel session, and destabilising it to gain dream coverage would be a bad
trade. Its 87 checks should keep proving the waking shift; a Gate D harness
should prove the join.

Gate D's four bullets, scored honestly:

- ~~One continuous production run enters after the complete Mina case,
  preserves every K6 fact, traverses the real dream scene, ends, rebuilds the
  waking scene and returns to the authored 4B bedside with one residue.~~
  **CLOSED.** The strongest part is the rebuilt world: the point reads
  repaired and the fault reads quiet because `ChirpHunt.setup()` reconciled
  them from the committed job stage, in a world built after the one that did
  the repair had been freed. That is the record reconstructing the building.
- **Owned elsewhere.** Real-file save/load at armed, entered, active,
  return-pending and awake is `DreamBoundaryTest` (36/36). Gate D takes the
  three checkpoints that bracket the join —
  `conversation_complete | dream_pending | wake_complete` — rather than
  re-proving persistence breadth `GoldenLoopTest` already owns.
- **Reported and discovered job origins converge on the same dream profile — MEASURED IN PART, STRUCTURAL IN PART.** Gate D opens on a throwaway
  campaign played from the *discovered* origin and proves the measurable
  half: that it issues and converges on the **same job** in the same stage
  without duplication. The profile then follows from that job, because
  `CoreLoopDirector` reads `dream_profile_id` out of the job library and the
  origin has no path to influence it.

  An earlier version of this entry claimed the bullet CLOSED on a check
  comparing `ctx.profile_id` against the profile the discovered run recorded.
  Adversarial review showed both sides resolve to the same job-library field
  on the same object, so that check could not fail; the very argument offered
  for its sufficiency ("the profile is read from the job, so the origin
  cannot change it") is the reason it was unfalsifiable. It has been folded
  into the arm-time assertion and the wording corrected. Genuinely closing
  this needs the discovered origin played to a second real entry, which is a
  second full shift and does not fit the run budget.
- ~~Capture, shaft and electrical outcomes all wake without a game-over
  state.~~ **CLOSED, all three measured.** `GateDJoinTest` takes a
  `GATE_D_OUTCOME` environment variable and drives each ending through its own
  played shift to its own rebuilt bedside: `capture` 69/69 in 38 s, `contact`
  71/71 in 35 s, `fall` 71/71 in 34 s. None is a game-over; each wakes at the
  authored 4B bedside with the residue intact. The steered runs teleport
  *near* the socket and then walk in under the production controller — the
  same split the waking half uses, where travel between beats is a teleport
  but every interaction is real.

  Parking the Tenant for a steered run is not decoration. Capture and the
  hazards share one latch, so the first arrival wins. The first attempt parked
  it at its own `_far_spawn`, which places it in the LAST chain module — and
  the trunk's `D05_SERVICE_RISER` is at that end, so the approach point came
  out **0.80 m** from the Tenant against a **0.75 m** capture radius and the
  run was captured on the first physics frame after the teleport, every time.
  It is now parked at D00, the other end of the chain, and the harness
  asserts the separation rather than assuming it.

**What the join actually cost, recorded because it was not obvious.** The
production onset clock cannot be used here. Onset is 2.60 sim-seconds, which
at `SIM_SCALE` is 0.74 wall seconds after the case resolves — and at that
moment every one of `SleepPressureDirector`'s five gates passes, because the
body is parked at the 2A ceiling point, outside the elevator column and the
traffic band, with `call_locked` already false. So the dream enters in the
middle of the harness's own post-arm assertions and `CampaignShell` frees the
waking world underneath them. It is deterministic, not a race, and it
surfaces as a use-after-free far from its cause. `sleep_manual_clock` lets the
harness say when; `advance_for_test` still runs the exact production
`_advance` body, all five gates, and the real `enter_armed_dream()`. The only
proof surrendered is that engine delta drives the clock, which
`SleepPressureTest` already owns.

Two smaller traps, both recorded so the next harness does not re-find them:
`DreamBoundaryTest._exclusive()` counts the `waking_world` group, which only
the boundary *stub* joins — the real `OrisonRoot` joins `building_root`, so
copying that helper reports a false failure on a correct join. And
`CampaignShell` removes and `free()`s a world immediately rather than
deferring, so every world-owned reference must be re-acquired through
`world_changed` rather than cached.

### Gate E — image, audio and performance

- A/B renders prove no module pop is visible across its intended occlusion.
- Lamp-on, lamp-off, hazard and capture frames remain readable at production
  black levels without exposing a Tenant model.
- Stereo and accessibility-caption cue tests pass.
- The isolated dream scene meets 16.6 ms at its critical stations on the pinned
  renderer, and an Android-class device is tested before calling the slice done.

### Gate F — fresh players

At least four of five first-time players can say, without being told:

1. the service lamp helped them see and helped the thing find them;
2. why their first hazard or capture happened;
3. that the maze was the Orison arranged impossibly; and
4. one Mina truth about labels, assumptions or blank silence.

If they call it “the narcolepsy monster,” representation has failed even if the
chase is frightening.

---

## OWNER RULING — 2026-08-15

All five production decisions are approved:

1. The just-integrated case owns its one **release-print** campaign dream and is
   quiet after wake.
2. Capture, fall or contact wakes the living player; there is no death or
   failure screen.
3. The maze is the deterministic ten-module ring, not unconstrained fractal
   room generation.
4. Campaign ceilings are 28 / 38 / 50 / 62 / 76 / 90 seconds.
5. The player's own shadow remains endgame material outside the six-case build.

This ruling closed design review. N2's measured module substrate closed Gate A
later the same day and opened N3's disposable light/pursuit control corridor. It
does not waive any remaining acceptance gate above.
