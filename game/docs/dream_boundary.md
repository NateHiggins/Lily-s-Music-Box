# Dream boundary — production contract

*Landed as N4 on 2026-08-15. The ruled experience remains in
`design/ORISON_MAZE_BRIEF.md`; this file describes the runtime that exists.*

## Scope

N4 adds the persistent campaign shell and the forward-only dream transaction.
It does not add sleep-pressure timing, onset presentation, maze geometry,
pursuit, hazards or a playable dream. A completed Mina shift arms the boundary;
N5's SleepPressureDirector is now the sole production owner allowed to call
`enter_armed_dream()` after its warning and safety gates.

`DreamMazeRoot.tscn` is deliberately only a boundary payload with a
`D00_4B_THRESHOLD` marker and the saved reconstruction context. It is not a
graybox maze and must not be reviewed as dream art.

## Scene ownership

```text
CampaignShell                         persistent
├── CoreLoopDirector                  persistent; rebinds waking services
├── DreamDirector                     persistent transaction owner
└── WorldSlot                         exactly one in-tree child
    ├── OrisonRoot                    waking, or
    └── DreamMazeRoot                 dreaming — never both
```

`GameBoot.begin_game()` loads `CampaignShell.tscn`. The shell removes and frees
the old WorldSlot child before instantiating the replacement. BuildingRoot uses
the shell's CoreLoopDirector when it is a descendant of a campaign shell;
focused tests and tools that instantiate BuildingRoot directly retain their
local coordinator. The persistent coordinator drops scene-owned WorkOrders,
player and layout references whenever waking Orison leaves the tree and binds
the rebuilt owners on return.

## Transaction state machine

| Phase | Durable meaning | Active WorldSlot child | Legal next operation |
|---|---|---|---|
| `awake` | no dream transaction is open | waking | an eligible `dream_requested` arms identity |
| `armed` | case/profile/window and exact campaign seed are committed | waking | SleepPressureDirector calls `enter_armed_dream()` after protected onset and stable-floor checks |
| `entered` | `active=true` and reconstruction identity committed before replacement | waking for at most the deferred swap boundary | CampaignShell replaces waking with dream |
| `active` | DreamMazeRoot is the sole world; a load reconstructs at D00 | dream | `end_dream(capture\|fall\|contact)` |
| `return_pending` | outcome committed before replacement; return transaction incomplete | dream until deferred swap, then waking | rebuild Orison, accept CoreLoop wake, apply residue, clear last |

The final transition returns to `awake` while retaining the last case, profile,
seed, revision and outcome as audit facts. It does not reopen a work order,
restore a consumed item or mutate case truth.

## Exact saved facts

`RealityState.data.dream_seed` is a sixteen-digit hexadecimal string. This is
the exact 64-bit campaign seed. It remains a string through save data, scene
context and `dream_entered`, because JSON numbers cannot faithfully represent
every 64-bit integer and Godot cannot represent the unsigned high half as a
signed integer. A future generator may consume the two 32-bit halves; it may
not coerce the fact through a floating-point number.

`RealityState.data.dream` contains:

| Field | Meaning |
|---|---|
| `phase` | one of the five phases above |
| `active` | true only for `entered` and `active` |
| `debug_preview` | true only for an F1-started preview transaction; never an earned campaign boundary |
| `case_id` | the just-integrated case, currently `mina_caption_crisis` |
| `profile_id` | data-authored release-print profile, currently `mina_release_print` |
| `window` | the job-authored eligibility/protection metadata |
| `seed_hex` | the exact campaign seed copied into this transaction |
| `maze_revision` | `dream_module_catalog.json.meta.version` at arm time |
| `outcome` | empty before ending; then `capture`, `fall` or `contact` |

No player transform, pursuit confidence, hazard timer or live node identity is
saved. Loading `entered` or `active` rebuilds the same context and starts at
`D00_4B_THRESHOLD`.

## Case presentation profile

The optional `presentation` block in `dream_profiles.json` is validated before
DreamMazeRoot builds geometry. Missing data resolves to the exact inert current
look. Present data must match its case/profile identity and supplies one bounded
bundle: incarnation index, palette/pattern/irradiance/motion parameters, four
substance keys, one reflected-world key, one visual signature and five ordered
fauna costumes.

The existing root material collector pushes that immutable bundle into the
existing architecture, lineage and fauna shader materials. It creates no node,
signal, draw, topology branch or save record. Cal and Omar remain rejected as
production-active presentation ids until their scheduled implementation passes;
data alone cannot activate a dream or waking case. `DreamIncarnationTest.tscn`
is the focused schema/default/collector proof.

`DreamIncarnationPlateCache` is a RefCounted held by the active DreamMazeRoot.
It resolves the four substance sets (albedo/height/normal/roughness) and one
reflected-world plate only when that case is listed as completely shipped in
`dream_plate_catalog.json`. The all-or-none load owns exactly 17 texture
references and a lossless full-mip census; a missing map clears the partial
bundle and never substitutes another case. `_exit_tree()` releases the bundle
before waking resumes. This cache is absent from save data and the scene tree.
`DreamIncarnationPlateTest.tscn` proves load, exact census, failed-case clearing
and wake release.

## Signal contract

- CoreLoopDirector emits
  `dream_requested(case_id, profile_id, window)`. The case and profile come
  from validated job data; DreamDirector does not infer Mina from a job id.
- DreamDirector emits `dream_armed(case_id, profile_id)` after the arm commit.
- DreamDirector emits `dream_entered(case_id, seed_hex)` only after DreamMazeRoot
  is the sole WorldSlot child.
- DreamDirector emits `dream_ended(case_id, outcome)` only after waking Orison
  is rebuilt, CoreLoop accepts wake and `return_pending` clears.
- `world_swap_requested(kind)` is an internal shell seam, not a gameplay event.
- The existing `wake_completed` signal remains the residue boundary;
  MinaCaptionManifestation applies its stable residue idempotently.

DreamDirector calls no WorkOrders or RealityCase transition. Its only core-loop
mutation is the pre-existing `notify_wake_complete()` boundary after waking
services have rebound.

## Restore rules

- `armed`: rebuild waking Orison and resume the saved N5 onset. A repeated
  request is ignored; protection or unsafe footing pauses rather than cancels.
- `entered`: build DreamMazeRoot directly, promote to `active`, start at D00.
- `active`: rebuild DreamMazeRoot with the same case/profile/seed/revision and
  start at D00. A chase frame is never reconstructed.
- `return_pending`: build waking Orison, accept wake if still pending, let the
  waking manifestation apply/reconcile the residue, then clear to `awake`.
- `awake`: build waking Orison. A completed job, spent capsule and existing
  residue remain completed, spent and singular.

This ordering gives every interruption one forward destination. Waking and
dream worlds never render or simulate together, including the single frame
between the durable `entered`/`return_pending` commit and deferred replacement.

## F1 dream preview

In a DEBUG launch, the first open section of the F1 panel exposes **Start
Dreamworld sequence**. It reads the case, profile and window from the same
validated maintenance-job record as production, then runs the real authored
sleep onset, committed DreamDirector transaction, DreamMazeRoot and waking-world
rebuild. It is unavailable when Orison was instantiated without CampaignShell.

The preview is deliberately not a campaign shortcut. It does not issue or close
a work order, resolve a case, grant an item, consume the campaign's next
`dreams_had` count, emit `wake_completed`, or apply waking residue. On ending it
uses CoreLoopDirector's authored 4B bedside placement while leaving the loop
boundary untouched, then clears the preview transaction back to `awake`.

## Proof

`DebugDreamButtonTest.tscn` presses the real production F1 button against an
unearned campaign and passes 11/11 checks: authored arm, real onset, exclusive
DreamMazeRoot, ordinary outcome funnel, waking rebuild, 4B bedside return, and
no job, loop, residue or decay-count mutation.

`DreamBoundaryTest.tscn` uses the production CampaignShell, DreamDirector,
DreamMazeRoot, CoreLoopDirector, WorkOrders, MaintenanceInventory and
RealityState. Its lightweight waking payload omits only the rendered building;
the final block instantiates the real production CampaignShell and OrisonRoot.

The N4 test originally passed 34/34 checks in 14.1 seconds. At each of `armed`, `entered`,
`active`, `return_pending` and `awake` it writes the real JSON file under
`user://tests/`, destroys the live shell and campaign data, reloads, and proves
the required reconstruction. It also proves one WorldSlot child, same-seed D00
restart, one waking residue, closed job, consumed capsule, resolved case,
production BuildingRoot injection and contained test-save cleanup.

The first invocation after adding the new scripts exceeded the external
60-second limit without a verdict and its exact Godot process tree was stopped.
After an explicit editor import, the first completed run exposed two
post-verdict nil-WorkOrders teardown errors; the persistent coordinator now
guards the world-removal frame. Two clean 34/34 reruns then exited in about
14 seconds. A later control deliberately used `f123456789abcdef`; it exposed
Godot's invalid unsigned-high-bit to signed-int conversion after the PASS
assertions. The runtime conversion was removed, the seed now remains exact hex
through save, context and signal, and the same high-bit control passes with no
script error.

N5 extends the same test to 36/36 with direct production carriageway and lift
seam checks; its deterministic N4 clock remains deliberately manual. Full onset
behavior is documented in `game/docs/dream_onset.md`.

Regression proof on the same source: CoreLoopTest PASS; MaintenanceJobTest
PASS; MaintenanceCounterTest PASS; GoldenLoopTest 87/87 PASS; LightingDebugTest
PASS; TitleScreenTest PASS; WalkTest FULL at x8/480 Hz PASS. One Godot instance
was used at a time, with the 60-second external bound.
