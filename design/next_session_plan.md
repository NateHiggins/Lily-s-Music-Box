# NEXT SESSION — START HERE

*Rewritten 2026-08-16 after N7 landed. Read this first.*

## The single most valuable next piece of work

**Gate D: join the two halves of the dream.** They both exist and have never
been connected.

`GoldenLoopTest.tscn` plays the whole Mina shift (87/87) but instantiates
`scenes/building/orison_root.tscn` directly and answers the dream request with
a test-only `DreamStub`. `DreamPursuitTest.tscn` runs the real CampaignShell,
the real maze, the Tenant and a real capture through to wake — but reaches
that state via `_seed_completed_shift()`, writing the finished job facts
straight into RealityState instead of earning them.

The seam is small: `CampaignShell.waking_scene_path` already defaults to the
same `orison_root.tscn` GoldenLoopTest instantiates standalone. Spawn the
shift's world through a CampaignShell, drop the stub, let the production
SleepPressureDirector call entry.

Do this as a NEW harness, not an edit to GoldenLoopTest. That test is the
authoritative waking-side proof and was repaired recently by a parallel
session; destabilising it to gain dream coverage is a bad trade.

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

## Two owner decisions still blocking work

1. **The hollow runner's module.** The catalog places its socket in
   `D01_F04_LONG_HALL`; the brief's §"MINA'S FIRST RUN" script says D04, which
   has no sockets at all. Moving the socket changes the catalog SHA and
   invalidates Gate A, so the engineering read is to amend the script. That is
   a fiction change and belongs to the owner. Its effect (what a broken board
   actually *does*) is also unspecified — its profile outcome is `""`, so it
   does not end a run.
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
