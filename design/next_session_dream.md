# ORISON — DREAM WORLD SESSION KICKOFF

Authoritative as of 2026-08-18. Everything below is committed and pushed to
`main`. The tree is SHARED with a parallel lane (Codex and/or another Claude):
**stage by exact path, never `git add -A`.** Your local `HEAD` can move between
your own commands because the other lane commits into the same working tree —
check before you assume. One Godot instance at a time, and after ANY timed-out
godot command check `Get-Process -Name godot*` before launching another.

**Read first, in this order:** `design/THE_TENANT.md` — it is the reason for
everything else and it changed last. Then
`design/DREAM_SURFACE_REDESIGN_BRIEF.md` with the four plates in
`art/reference/dream_surface/` open beside it. Then
`game/scripts/dream/dream_room_builder.gd` top-to-bottom; its header is the
architecture.

---

## THE RULINGS THAT GOVERN EVERYTHING

- *"this is a demonstration project of what we can create, the rule of cool is
  key. Make it good, not correct."*
- *"the fractal is the dream world. it contains multitudes"* — a persistent,
  convoluted Orison being actively forgotten and misremembered, entered at a
  point chosen per case.
- **Who she is (2026-08-18):** *"our poltergeist is a higher dimensional
  consciousness, she/her, wanted for public indecency, extremely dangerous,
  easily embarrassed, a transfem metaphor if you will"* — looking for love,
  carrying her own trauma, reconciling it by helping the residents face theirs.
  Revealed through action only. **Eventually the player can speak to her and
  romance her, if they play right.**
- **What the light does:** it is a DETERRENT, not a beacon. It exposes her and
  she withdraws in shame. It also tears reality open and reveals the gold
  matrix underneath, and shows hazards that are invisible without it.
- **Where you wake:** a seed-chosen room that holds until a case is solved.
- Two rules survive every ruling and are safety, not taste: **no flashing at
  photosensitive frequencies, and no forced camera roll/fisheye/chromatic
  assault.**

---

## WHAT IS TRUE NOW

**`DreamRoomBuilder`** (`game/scripts/dream/dream_room_builder.gd`) turns the
atlas into space. 175/175 in `DreamRoomBuilderTest`.
- Rooms placed against the door you came through. Nothing reconciles globally;
  the building does not close. That refusal is the thesis.
- **The pocket is short-term memory:** the last 3 rooms walked plus every
  neighbour of the current room. Inside the trail you can retrace; outside it
  the same door opens somewhere else. A door that cannot be honoured without
  overlapping a live room is SEALED (~20% of onward doors on a long walk —
  a tuning knob, not a bug).
- **Pocket adjacency replaces `chain_route`:** `route()` is a BFS over open
  doors emitting near/centre/far triples. It is re-derived every physics frame,
  caches nothing, returns the same answer twice, and every segment stays inside
  architecture — the test walks each at 20 cm and reports 0.000 m outside.
- **The fairness clamp.** SCALE drift may grow a room freely and may only
  shrink it while every armed hazard keeps the doorway warning the authored
  module gave it, or the warning it is owed, whichever is less. Measuring it
  turned up that **6 of 8 authored sockets are already below their owed warning
  from their own doorway** — the shipped dream passes Gate C only because the
  tell crosses the wall. If an acoustic graph ever occludes tells, Gate C
  breaks that day for those six.
- **Faults as space:** REPETITION rebuilds the previous room's module at its
  size with the doors moved; BLANKING drops lintels so openings run floor to
  ceiling; SCALE and CONFABULATION were already space. **RECURSION is NOT
  expressed and its cost is unmeasured** — the suite says so in its own output
  rather than passing quietly.
- **The waking room does not arm.** Every other room's fairness rests on the
  approach; the waking room has none. Found because the player could wake
  inside a hazard and the run ended by contact in the first frames.
- **Scars:** unarmed sockets travel in the plan and are visible, with a
  material pinned to zero reveal so they never turn gold at any light level.
  A live hazard is the dream showing through; a scar is only the real building.

**`DreamMazeRoot`** builds the fractal behind `DREAM_FRACTAL=1`. All three
chain-bound production sites are gone (`_build_practicals` finds rooms by name,
`_update_practical` lights the first door of the room you are in — a lure
rather than a corridor marker, `_cap_fold` brings her to the door you came in
through). `DreamHazardField.rearm()` exists because `setup()` zeroes
`elapsed_s`, which is the clock Gate C measures against.

**The light is inverted.** Lit she moves at 3.35 m/s (outpaceable), dark at
6.35 (not). Measured deterrent: 5.383 s vs 2.800 s on the chain, 2.808 vs
1.458 on the fractal. The cost of light moved from her to the building — the
trunk's `lamp_on` condition, and the gold overcoming reality.

**Two save keys.** `dreams_had` (nights, drives decay) and `spawn_anchor` (=
`cases_resolved()`, drives where you wake). Deliberately not one number: a
retried passage must wake in the same room and still find the building a night
more forgotten. The case id is also folded into the atlas seed, so **a new case
is a different building**.

---

## TEST MATRIX — the state you must not regress

| Suite | chain (default) | `DREAM_FRACTAL=1` |
|---|---|---|
| DreamAtlasTest | PASS 22/22 | PASS |
| DreamBoundaryTest | PASS 39 | PASS |
| DreamPursuitTest | PASS 39 | PASS |
| GateDJoinTest | PASS 69/69 | PASS |
| DreamRoomBuilderTest | PASS 175/175 | PASS |
| DreamFractalRunTest | SKIPPED | PASS 20/20 |
| **DreamHazardTest** | PASS 42 | **FAIL 6** |

`DreamHazardTest` on the fractal is the **only** thing between here and
deleting the flag. Its five named failures are chain-topology assertions, and
the contract question they turned on is already ruled: unarmed sockets ARE
carried now, so "the counterweight is placed but NOT armed" should pass once
the count expectations stop assuming a fixed five-module chain. Three script
errors in that run are `_hazard()`-style lookups that return null and get
dereferenced — they ERROR rather than fail, taking their blocks with them.

---

## THE WORK, IN ORDER

### 1. THE SURFACE REDESIGN — the biggest gap between vision and build
Read the brief. The four plates are ONE SURFACE AT FOUR LEVELS OF EXPOSURE:
infection → medallion → rupture → breach. The governing change is that
**exposure must PERSIST AND ACCUMULATE** — today `heat` is recomputed from the
lamp cone every frame, so gold appears while lit and vanishes when the beam
moves, and every plate shows the opposite. Build a per-room exposure field fed
by both the lamp and `DreamAtlas.decay()`, seeded from the atlas's existing
`aspect(id, salt)`. Under `THE_TENANT.md` that field is also **how much of her
you have uncovered**, and she should avoid the rooms where she is most exposed
— behaviour for free from a field that had to exist anyway.

Use **interior mapping** for the nested frame-tunnel: an infinitely receding
interior on one flat quad, no geometry, no extra draws.

**The current shader is still "a painting on a wall"** — it mixes `real_wall`
and gold in the albedo of a flat surface. Volumetric tentacles that occupy the
corridor and cross in front of the camera are geometry, not a fragment term.
That is the real distance left to travel.

### 2. ADD THE DREAM PERF STATION FIRST
`game/tests/perf_probe.gd` has no dream station and nothing has ever measured
this frame. Per-pixel GPU work is free here (TASKS.md §P — submission-bound,
not fill-bound); **draw submissions are not**. The tentacles are the first
thing in this whole direction with a real submission cost. Measure before they
land, not after.

### 3. MOVE `DreamHazardTest` AND DELETE THE FLAG
`DreamMazeRoot.fractal_enabled()` is explicitly temporary and says so.

### 4. PRICE RECURSION BEFORE BUILDING IT
Nothing in the project does nested enterable space. 29 of 400 deep rooms ask
for it.

### 5. THE EMBRACE
`_on_captured` commits an outcome and nothing else. The staging is specced in
`THE_TENANT.md`: gold closes from every edge at once because a
higher-dimensional embrace has no direction; **the lamp stays lit and shows
only gold**; reverb collapses; her eyes close; warm; a 1.5 s iris and never a
strobe. Depends on eyes existing as elements (surface brief workstream F).

### 6. HER SPEECH AND THE ROMANCE — last, deliberately
Every hour spent on her silence is what buys it. Do not start here.

---

## OWNER DECISIONS STILL OPEN

1. **`_carry_pursuer`** — unruled across five commits now. When the pocket
   forgets the room she was standing in, she is put back on the trail behind
   the player, because a body outside every live room routes by straight line
   through walls. The consequence: **outrunning the building's memory buys
   distance.** It is bounded by the 28 s ceiling and `_cap_fold`, and it pushes
   the player onward rather than back. But it is a real reprieve the ring never
   offered.
2. **What changes between passage one and passage six.** Her arc is only
   visible in how the six dreams differ, and that is undesigned. The clock that
   should drive it is `cases_resolved()` — the people she has managed to help —
   not `dreams_had`.
3. **The sealed-door rate** (~20%) and whether that reads as intended.

---

## TOOLCHAIN, VERIFIED

```
cd art/data && python gen_layout.py            # self-validating
cp the FIVE json to game/data/                 # fixture_light_map is the forgotten one
"/c/Program Files/Blender Foundation/Blender 5.2/blender" -b -P <abs>/art/blender/scripts/build_orison.py
C:/devkit/bin/godot.cmd --headless --path game --import      # bare `godot` fails
C:/devkit/bin/godot.cmd --headless --path game res://tests/<Scene>.tscn
DREAM_FRACTAL=1   # build the fractal instead of the chain
DREAM_PLAIN=1     # graybox materials; MUCH faster, and a control, NOT a verification
godot --path game res://tests/DreamWalk.tscn   # walk it; F identifies what is under the crosshair
```
Render/shot harnesses need a REAL WINDOW; `--headless` reports zero draws.

---

## THE LESSON THIS SESSION LEARNED THREE TIMES

**Grep the log before you believe the result.** Every run:

```
grep -ciE "SCRIPT ERROR|SHADER ERROR|as a 64-bit signed"
```

Three separate times a green-looking result was sitting on top of a broken
file, and each time the failure looked like something else entirely:

1. `dream_room_builder.gd` failed to parse. Boundary, Hazard and Pursuit all
   printed **PASS** because the chain path does not touch that file.
2. `##` is GDScript doc syntax and a **tokenizer error in GLSL**. The shader
   did not compile and `DreamFractalRunTest` printed **PASS 20/20** — Godot
   falls back to a default material silently.
3. `0x9E3779B97F4A7C15` exceeds signed int64. `DreamAtlas` stopped loading for
   any caller naming a case; nine boundary failures and Gate D red **presented
   as a topology regression from an unrelated change I had just made.**

And two more of the same shape:
- `_rect()` answers a miss with a **zero rect**, not an empty array. Two bodies
  got placed at the world origin outside everything, producing 701 route
  violations and three identical capture times that read exactly like a pocket
  bug. The builder's own suite reporting 0 breaches is what said otherwise.
- **Do not tune a threshold until it passes.** The first inverted lamp
  thresholds were a symmetric guess and failed at 1.37x. Set them from
  measurement with margin and say that is what you did.

The Bash tool's working directory persists between calls; a stray `cd` will
make `--path game` fail with "Invalid project path".
