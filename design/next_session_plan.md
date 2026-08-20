# NEXT SESSION — START HERE

*Rewritten 2026-08-17. The dream world was rebuilt from its foundations; read
this and then `game/scripts/dream/dream_atlas.gd` top-to-bottom — its header is
the design.*

## 2026-08-20 supersession note

The implementation status below is retained history through the Atlas landing,
but it is no longer the pickup. Read `design/next_session_dream.md` next; its
2026-08-20 checkpoint records the one-world pocket, durable exposure, measured
dream frame, completed recursion price and the owner's queued gold/tentacle
amplification. N10 now has its first geometric slice: batched dark-live hazard
tentacles, owner-true contact paths, first geometric eyes, and mesh-only Orison
furnishing. The immediate dream production task remains TASKS **N10**,
now on a landed Orison wall vocabulary: exact dado, wainscot, picture rail,
cornice, door casings and ceiling medallions cost at most two MultiMesh draws
per live room, and hazard crawlers become closed-lobe wall grafts rather than
ending against blank boxes (`art/renders/dream_orison_walls_v1/README.md`). R1
is also landed: the photographed Orison substrate now survives the complete
Klimt filter, and the one live-growth draw owns reusable tissue, wet-film and
living-gold layers under a bounded readable-black lighting contract
(`art/renders/dream_rendering_r1/README.md`). R2 is also landed: tesserae,
recessed grout, cracked concentric relief and room-bound growth anchors remain
on the existing submitted surfaces (`art/renders/dream_rendering_r2/README.md`).
R3 is also landed: five deterministic anchors per eligible danger, four-of-five
closed or half-lidded rest states, long seeded blinks, fixed local gazes and
exactly one bounded camera tracker remain in the existing one hazard surface
(`art/renders/dream_rendering_r3/README.md`). R4 is also landed: one
hazard-provenant Atlas-wall wound carries real torn plaster/lath/rubble and a
32 m apparent angular/cabled interior on one wall-thin face in the existing
growth draw, while the authoritative wall collision stays intact
(`art/renders/dream_rendering_r4/README.md`). R5 is now landed: the same wound
arrives continuously from retained exposure, shares one Orison/rupture/
living-gold transition controller, confines slow warp to the aperture and
returns one measured 0.42-energy / 3.2 m shadowless world light only at high
retained exposure (`art/renders/dream_rendering_r5/README.md`). R6 is now
landed too: one 384 × 672 camera shares the existing world and shows an
already-live Atlas room through the wound with an odd quarter-turn. Its camera
excludes the wound layer, so recursion depth is exactly zero; it adds no room,
route, collision, hazard, light or interaction and leaves the wall solid
(`art/renders/dream_rendering_r6/README.md`). R7 is closed at depth zero:
recursive rendering adds no decision and enterable nesting duplicates Atlas
traversal while demanding a second collision/navigation/pursuit contract.
Reopen it only for a new case verb the Atlas cannot express. R8, the ruled
capture/embrace, is now landed: one shell closes from every edge over 1.5 s,
the player's chosen lamp state survives, all eyes close, the acoustic room
becomes close and warm, and the existing 4B wake/residue boundary receives the
unchanged outcome after the held final frame. Proof:
`art/renders/dream_embrace_v1/README.md`. Immediate dream pickup is the N7
`DreamPerceptionTest` proof repair, then N9's Peter shared-profile proof.

The parallel street lane's paused coachwork pass is now a bounded T2g
checkpoint with focused contracts and A/A evidence. It does not own the next
dream file and must not be folded into a surface/tentacle commit.

## THE RULING THAT GOVERNS EVERYTHING NOW

> "this is a demonstration project of what we can create, the rule of cool is
> key. Make it good, not correct."

and then

> "the fractal is the dream world. it contains multitudes."

A persistent, convoluted Orison **being actively forgotten and misremembered by
the ghosts that inhabit it**, entered at a random point each night. The
ten-module ring is SUPERSEDED. `ORISON_MAZE_BRIEF.md` §"VISUAL AND AUDIO
LANGUAGE" is rewritten to match.

**Two rules survive every ruling** and are marked as such in that document: no
flashing at photosensitive frequencies, and no forced camera roll, fisheye or
chromatic assault. Those are safety and accessibility, not taste.

## What landed

`DreamAtlas` (`f7b729f`, `e8e6fe2`) — the fractal generator, 19/19 in
`DreamAtlasTest.tscn`. Three properties, each asserted:

- **Identity comes from the PATH, not a position.** Room = hash(seed, door
  sequence). Infinite, deterministic, and needs *no storage* — decay is a pure
  function of (seed, room id, nights). 1000 walks, 0 collisions.
- **The building does not close.** Local placement only; a loop does not return
  you. The test asserts non-closure *explicitly*, because it is the property
  most likely to be accidentally "fixed" by a refactor adding global placement
  — and that fix would take the whole thesis with it.
- **Misremembering is not randomness.** Six named memory faults arriving in
  DECAY ORDER (repetition, conflation, scale, confabulation, recursion,
  blanking), so a room's condition is readable from its symptoms and the
  building stays learnable. 2000 rooms, 0 ordering violations.

**Golden vectors are pinned.** `mix64` and six salts name every room in every
campaign; changing any of them silently renames the whole building for every
save, with no error and no crash. If block E fails, the question is never "what
is the new number" — it is "what did I change, and put it back".

## The next piece, and it is the larger half

Nothing builds geometry from the atlas yet. `DreamMazeRoot` still assembles the
old linear chain and `DreamMazeBuilder` states outright that it handles linear
chains only.

1. `DreamRoomBuilder` — one room, one entry door, placed relative to the door
   you came through; a rolling pocket built ahead and freed behind.
2. Pocket adjacency replacing `chain_route`.
3. The six faults expressed as actual space.

**A contract audit already exists and is accurate — use it rather than redoing
it.** Across 206 checks only ~33 are topology-bound. Boundary 34/36, GateDJoin
68/69, Hazard 34/42, Pursuit 27/39, Perception 9/20 survive verbatim. "Starts
at D00" is exactly 4 checks in 3 files.

- **Retire:** `assemble()`'s chain walk, global placement, `_far_spawn`,
  `_plan_bounds`; the global non-overlap guarantee (downgrade to "no two rooms
  in the LIVE POCKET overlap"); pursuit block A; Gate A's *assembly* half only.
- **Keep — this is the salvage:** `_solid_box`, the door cut, `_door_record`,
  `_connector`, `_opposite`, `_subtract_rect`, `_build_shafts`, `floor_holes`,
  `_material`/`_klimt_material`, `seed_halves`. All already room-local or
  per-joint; `_door_record` is literally "place relative to the door", inverted.
- **Gate A's catalog half gains weight** — its SHA is now the only authored
  geometric fact left in the dream. The catalog is the vocabulary the fractal
  speaks.
- **Needs a save key:** `spawn_path(night)` is only reproducible if the night
  index is durable. `RealityState` has `dream_seed` and no night count.

**A fairness bug the ring could never have had:** SCALE drift (0.80–1.22×)
makes Gate C's owed-warning margins (0.52 / 0.19 / 0.92 s) a **per-room
constraint the builder must enforce**, not measured constants. A room that
shrinks a fifth can put a hazard closer to its doorway than the warning it
owes. Build the clamp; do not discover this in a playtest.

## Two new tasks, neither started — `TASKS.md` §M

**M-AUDIT — material use.** The obvious framing is wrong and the task says so:
the 227-material PBR library *is* shipped (195 of them as `T_ai_materials_*`).
The gap is binding and exploitation — **105 catalog entries and not one
references a texture**, 41 source directories ship no albedo under their own
name, 15 shipped albedos have no normal, and height maps are authored for all
227 with one consumer. Deliver a table and a promotion order.

**M-COVER — rethink coverage.** Tiling is not carrying it any more; triplanar
repeats read as repeats. M1's supertile deferral predates both the dream shader
and the fractal and should be reopened rather than inherited. The free option
is already sitting there: `DreamAtlas` computes a stable per-room id and
nothing downstream uses it to vary texture. Bring frames, not adjectives.

## Still unpriced, and say so rather than guessing

There is **no dream perf station** in `game/tests/perf_probe.gd`. The shader is
now heavy (a dozen-odd fbm calls per pixel) and two particle systems are
written but disabled. Nothing has measured any of it. This frame is
submission-bound rather than fill-bound (`TASKS.md` §P) so it is *probably*
fine — "probably" is doing real work in that sentence.

## Five lessons from the rebuild, all the same lesson

The instrument was the broken thing rather than the subject, five times: an
ambient that was never applied (`ambient_light_sky_contribution` defaults to
1.0), a beam mask nobody had told about the room, **a shader that had not
compiled for hours while the harness reported "4 frames saved"** — Godot falls
back to a default material silently and it looks exactly like a lighting
problem — a melt that was a *cylinder* down the beam axis rather than a pool on
a wall, and a duplicate Godot instance skewing the machine underneath
everything.

So: grep for `SHADER ERROR` after every shader edit **before** looking at the
picture. `DreamEnvironmentShot` now asserts compilation via
`get_shader_uniform_list()` and says outright when frames are the fallback. And
never tune coupled values against each other — fix one reference frame and
change one thing.

## Walk it

```bash
godot --path game res://tests/DreamWalk.tscn
```

`F` identifies whatever is under the crosshair — node, class, material, shader,
and whether it *compiled*. `1`-`6` isolate a surface class, `TAB` hides
non-architecture, `0` restores. Built because three fixed viewpoints are the
right instrument for a regression and the wrong one for a hunt.

---

# PREVIOUS PICKUP — the waking Orison (2026-08-16)

*Still accurate for everything outside the dream. Kept because Gate D, the
skeptic pass and the perf shape below are all live facts.*

## Gate D is joined — 2026-08-16

`GateDJoinTest.tscn` closes the seam this file used to lead with. It plays the
Mina shift inside a real `CampaignShell` and lets the production path carry it
into the real dream: **69/69 checks, 17 blocks, 37 seconds**, consecutive runs
reaching the same committed outcome (`capture`), world sequence
`waking -> dream -> waking`. `GoldenLoopTest` is untouched and still 87/87.

**Three of Gate D's four bullets are closed and the fourth is measured in
part.** (An adversarial review corrected the earlier "all four" claim: the
origin-convergence check compared two expressions that resolve to the same
job-library field, so it could not fail. The job convergence is measured; the
profile following from it is structural. See the Gate D entry.) Each ending is driven
through its own played shift via `GATE_D_OUTCOME`: `capture` 70/70 in 37 s,
`contact` 71/71 in 35 s, `fall` 71/71 in 34 s. See the Gate D entry in
`ORISON_MAZE_BRIEF.md` for the scoring and the traps the join exposed.

## Read this before trusting a number in the dream docs

On 2026-08-16 seven skeptics were run against the claims this work wrote into
the design documents, told to refute rather than confirm. They found real
things, all now fixed and recorded in place:

- Gate C's "twenty bearings per hazard" was **one approach replayed twenty
  times** - the sweep discarded its bearing argument. Fixed; the coverage
  check now counts distinct tell positions instead of loop iterations.
- The acoustic-graph constraint was right for the **wrong reason**. "No room
  is that deep" was false (D05 is 6.50 m, D01 is 19.30 m). The real reason is
  that sockets sit mid-room; the doorway margins are now measured at 0.52 s
  and 0.19 s against 0.90 s owed.
- The DreamPursuitTest flake "fix" was a **tautology** - bounding drift by
  `elapsed_s * top_speed` is the pursuer's own displacement bound. Rewritten
  to establish its premise and test the clock.
- `floor_holes` cut a void mouth for **unarmed** sockets, so a future profile
  placing D03 without arming the void would drop the player into a sealed
  shaft in a run that could not end. Now gated on the profile allowlist.
- `_cleanup()` re-aimed `save_path` at the player's real save while
  persistence was still enabled. Now disarmed first.

The lesson worth keeping: every one of these passed its own test suite. The
adversarial pass is what found them.

## What is worth doing next

~~1. **The hollow runner**~~ **DONE 2026-08-17.** The owner ruled "change the
   fiction", so §"MINA'S FIRST RUN" now scripts it into D01 where the
   catalog's socket always was; the catalog, its SHA and Gate A are untouched.
   Its effect was the other half of the question and was never specified:
   a broken board **staggers the player and hands the Tenant their position**,
   using `PlayerController.stagger()` and `DreamPursuer.last_known_position`,
   both of which already existed. The run does not end — the real cost of
   sprinting is that the thing chasing you now knows where the noise came
   from. `DreamHazardTest` block F, 42/42.

~~2. **The production dream `WorldEnvironment`**~~ **DONE 2026-08-17**, with
   the carried black level and the receding practical. It was not polish: the
   dream had shipped with no environment at all, so lamp-off was literally a
   black frame, and the harness that photographed it built its own environment
   and two control lights. `art/renders/dream_env_n7/README.md`.

1. **The trunk's lit beam-splash confirmation** is the last N7 item.
2. **Gate E** (image, audio, performance) is entirely untouched, and is now
   the largest unstarted block of dream work. It wants A/B occlusion renders,
   readable black levels, stereo and caption cue tests, and a 16.6 ms
   measurement at the dream's critical stations. Note that **no dream perf
   station exists in `Perf.tscn`**, and N7's new lights are draws nothing has
   priced.
3. **Gate F** is five first-time players, and cannot be done by us at all.

## Where N7 got to

Landed and green: one latched outcome funnel, the authored 28 s run ceiling,
hazards emitted from catalog sockets, the Vantry trunk (condition `lamp_on` —
light activates the danger it reveals), the open lift void as a real hole in
the real floor resolved by real gravity, the eight-sector caption channel, and
`DreamCaptionLayer` behind the `dream_directional_captions` setting.

| Test | Result |
|---|---|
| `DreamHazardTest.tscn` | 30/30 |
| `DreamPerceptionTest.tscn` | 19/19 |
| `DreamPursuitTest.tscn` | 39/39 |
| `DreamBoundaryTest.tscn` | 36/36 |
| `GoldenLoopTest.tscn` | 87/87 |

Numbers and findings: `art/renders/dream_hazards_n7/README.md`.

Gate C: two of three bullets closed. The identification bullet is a human
blinded playtest and no script closes it — `DreamPerceptionTest` proves the
precondition at 100% instead.

## One owner decision still blocking work

1. ~~**The hollow runner's module.**~~ **RULED 2026-08-17: "change the
   fiction".** The script was amended to D01, where the catalog's socket
   always sat, leaving the catalog SHA and Gate A untouched. The amendment and
   its reasoning are recorded in place in §"MINA'S FIRST RUN". The second half
   — what a broken board actually *does*, which was equally unspecified — is
   implemented and guarded: stagger plus the Tenant learning your position.
2. **E8b:** degradation per shift or per hour, for the entropy system.

## One constraint later work must not break

The trunk and the void are fair **because** their tells cross a wall — they
were first heard from an adjacent room in 20 of 20 approaches. When the dream
acoustic graph is built it must attenuate hazard tells across a wall and must
NOT silence them, or Gate C breaks the day it lands. Re-run
`DreamPerceptionTest.tscn` as that work's acceptance check.

---

## Previous plan, retained for reference

# Next session: integrate Mina's vertical slice

*Rewritten 2026-08-15; updated the same day after N6 landed. Sequencing
authority beneath `design/CLAUDE_LIVING_ORISON_EXECUTION_PLAN.md`.*

## Read first

1. `design/ORISON_BIBLE.md`
2. `design/CLAUDE_LIVING_ORISON_EXECUTION_PLAN.md`
3. `TASKS.md`, especially §K, §C, §X, §N, §L and §P
4. `HANDOFF.md` for build/test mechanics

The owner has ruled the campaign rhythm: issue, shop, repair, conversation,
narcoleptic dark scramble, wake in 4B, repeat. The owner clarified on 2026-08-15
that “the dream world is our reveal” constrains the **title screen only**. It
does not prohibit designing or building the production dream.

## Immediate next action

**The full `design/ORISON_MAZE_BRIEF.md` is ruled. N2 is complete.** The owner
approved the release-print case binding, capture rather than death, deterministic
ten-module ring, 28–90 second curve and the player's own shadow held for
endgame. The Bible and execution plan carry the ruling. The source catalog,
canonical assembly, dimensioned drawing and audit record live at
`art/renders/dream_maze_n2/README.md`: 10 modules, 12 directed edges, 8 hazards,
18 source checks, 100/100 deterministic seeds, 0 unresolved. The generated
audit records the measured seed-independent structure count.

**The carried-device replacement is complete.** Production now carries the
no-screen Vantry service radiophone through a device-neutral light seam; L
operates its tungsten lamp, R operates its radio/aerial, ORDER reads open work,
and the rear NET/LAMP lamps report their own physical circuits. The old phone
classes remain archived source but are not instantiated. Proof and the complete
dependency census live in `game/docs/service_set.md` and
`art/renders/service_set_q4/README.md`.

**N3 is complete; Gate B is closed.** The disposable 42.00 × 3.20 × 3.00 m
control corridor measured eleven paired fixed seeds: 3.425 s lamp-on, 11.358 s
lamp-off and 11.225 s extinguished-after-acquisition medians. Light-on shortens
survival 69.8%; turning it off buys 7.800 s; real opaque collision blocks
acquisition; darkness always still captures. L, controller left shoulder and
touch LAMP reach the same public owner. The capsule is diagnostic
`SHADOWS_ONLY`, never a Tenant asset. Exact proof is in
`art/renders/dream_light_n3/README.md`.

**K7 is complete.** `game/docs/core_loop.md` now records the code-backed owner
table, maintenance transition graph, coordinator boundaries, exact signal and
save contracts, complete Mina trace and the required generalization before a
second case. It also records two easily missed limits: the coordinator is still
hardwired to Mina's one job, and `conversation_requested` has no production
dialogue subscriber. Do not treat either seam as broader than the code.

**N4 is complete.** Production now boots through a persistent CampaignShell
holding one CoreLoopDirector, one DreamDirector and a one-child WorldSlot.
Waking Orison and DreamMazeRoot never coexist in-tree. The saved transaction
reconciles forward from armed, entered, active, return-pending and awake; the
campaign seed is an exact sixteen-digit hexadecimal fact; case/profile identity
comes from job data. DreamMazeRoot is only a D00 reconstruction payload, not
maze art. Full source-backed behavior and the original 34/34 real-file proof,
now extended to 36/36 by N5's production safety checks, are in
`game/docs/dream_boundary.md`.

**N5 is complete.** CampaignShell now keeps one SleepPressureDirector. Mina's
profile is a 2.60-second gradual warning; later dual-form profiles choose once
from the exact campaign seed; Always warn before sleep forces gradual. The
existing engaged flag and owner-supplied body, lift and traffic gates pause but
never cancel pressure. Midpoint real-file restore and one-entry proof pass
20/20; the production visual pair is measured in
`art/renders/dream_onset_n5/README.md`. The source contract is
`game/docs/dream_onset.md`.

**N6 is complete.** The production DreamMazeRoot now assembles its campaign
slot's module chain from the N2 catalog and the exact campaign seed
(`DreamMazeBuilder`; slot 1 = `D00→D01→D03→D04→D05`, real opaque graybox
collision, one seed-bit handedness, later-slot connectors sealed), spawns the
dream body as the real PlayerController with the lit service lamp, and runs
`DreamPursuer`: one invisible navigation body wearing `mina_vale` forced
shadows-only, moving through per-door approach waypoints on the validated
graph, driven by N3's unchanged measured contract seeded once from the
campaign seed. The 39/39 exact-count proof (`DreamPursuitTest.tscn`) covers
all four ruled points — silhouette never in beauty, walls block acquisition,
the real lamp owner gates pursuit (6.450 s on / 10.742 s off / 10.600 s
extinguished captures at the fixed seed; 0 route violations), capture commits
`end_dream("capture")` through the shell — plus mid-pursuit restore at D00.
Record and production frames: `art/renders/dream_pursuit_n6/README.md`.
Pursuit numbers are data in `game/data/dream_profiles.json`. Hazards, the
terminal fold, run caps, dream audio and case captions were deliberately
excluded. Resolved upstream regression: the two K6 objective-title checks
failed from `b318d84` ("Adopt the service-wire telegram interface"), not
`1f8faa0` — that restyle made `ObjectiveTracker.show_objective` prepend a
fixed `"WORK ORDER / "` label to titles the job library already authors
whole, so the tracker relabelled content it does not own ("WORK ORDER /
WORK ORDER 001 — THE CHIRP", "WORK ORDER / CASE CLOSED — MINA VALE"). The
tracker now presents the authored title verbatim, keeping the restyle's
casing and paper-panel styling. GoldenLoopTest is 87/87 again, and the same
prefix had also been failing `MaintenanceJobTest`, which passes again too.

**Execute N7 next.** Integrate one Mina vertical slice on the landed
substrate: Mina's three ruled hazards (open lift void, Vantry signal trunk,
hollow runner — each with its darkness tell, lit confirmation and
reconstructable cause), the slot-1 run cap with the terminal fold placing the
Tenant on the shorter converging route, the receding in-maze practical one
connector ahead, and the wake outcomes for capture, fall and contact all
reaching the existing seam. Gate C's fairness measures (tell-before-contact
logging) come with the hazards; do not start Gate E polish or Peter.

## Execution order

1. **N7 — integrate Mina's vertical slice.** Preserve N2's graph, N3's light
   binary, N4's scene transaction, N5's onset owner and N6's pursuit contract.
2. **N8 onward — remaining case grammars** only after the shared substrate
   passes Gate C and Gate D on Mina.

M0.5 and M1 are closed historical milestones. Their detailed proof remains in
`design/FINAL_MAP_REDESIGN_BRIEF.md`, `TASKS.md` and `HANDOFF.md`; do not rerun,
reinterpret or reopen them while executing N6.

## Non-negotiable constraints

- Six cases only: Mina, Peter, Juno, Cal, Omar and Mae. Peter is second.
- One Tenant, wearing the just-integrated subject's release print in each
  campaign dream. No new monster or true form.
- Repair changes symptoms; honest conversation changes the rule.
- A call or conversation in progress protects the player from sleep onset.
- The dream never erases committed work.
- `gen_layout.py` owns coordinates; generated JSON/GLB is never hand-edited.
- Visual work gets before/after renders in production lighting and streaming.
- Performance is a release feature. The playable STREET gate closed at T7's
  settled 15.718 ms direct mean; project-wide P1 and the accepted Passage-night
  blocker remain distinct, and every critical-route addition must re-run its
  owning station rather than borrowing the STREET result.

## The next deliverable to the owner

Return one complete playable Mina dream passage: enter after the complete
shift, survive or fail against the pursuit and her three audible hazards,
and wake in 4B with one residue — capture, fall and contact all reaching the
same existing outcome seam, the slot-1 cap closing the run through the
terminal fold, and Gate C's tell/impact logging proving the darkness is
fair. Peter and all later case profiles remain outside N7.
