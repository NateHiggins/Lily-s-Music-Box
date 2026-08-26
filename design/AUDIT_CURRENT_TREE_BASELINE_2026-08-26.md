# Current-tree baseline — 2026-08-26

Checkpoint under test: pushed `f7db405` plus the K1 release-gate corrections
committed with this report. Platform: Windows,
Godot 4.7.1 Forward+, one serialized instance through
`tools/run_godot_serial.ps1`, 60-second process ceiling. Engine output was
redirected to temporary logs and only verdict/error lines were reviewed.

This is the K1 baseline record, not a completion claim. It names what is green,
what is inherited, and what now blocks the integrated golden-shift gate.

## Result matrix

| Gate | Result | Evidence |
|---|---|---|
| `FirstShiftOpeningLiveTest` | **PASS, 0 failures** | Production arrival, watch apparatus and opening-report route complete under the ceiling. |
| `LightingAudit` | **PASS** | 127 spaces; 11 intentionally ambient/dark. |
| `WalkTest` FAST, x4/240 | **FAIL, 2; verdict printed** | The established authored-job/chirp expectation and boiler 23-mesh merge failures reproduce. No new FAST failure. |
| `WalkTest` FULL-PHYSICAL, x4/240 | **FAIL, 2; verdict printed** | Completes the physical route, rider-carrying lift trip, Case 01, street, roof and Room 0 under 60 s. Only the two established failures recur. |
| `WalkTest` FULL-CASES, x4/240 | **FAIL, 2; verdict printed** | Completes all eight calls, convergence, broadcast, Evelyn and sanity in a complementary production boot under 60 s. Only the two established failures recur. |
| `GoldenLoopTest` | **PASS, 87/87** | Timed phase markers measured an 18.1 s boot and symmetric 16.4/16.1 s physical travel legs. Matching the established x4/240 solver discipline and retaining a 57 s internal guard completes in 53.7 s beneath the runner's hard 60 s ceiling. |
| `DreamTentacleTest` after correction | **PASS, 27/27** | The deterministic pre-tree global-transform engine error is gone; an unrelated resident-navigation error can still be emitted by the production scene. |

No parse error was observed in these runs.

## Defects distinguished by the baseline

### Product-path blockers

The former monitor-door blocker is closed. `ROOF_DOOR_01` was correctly placed
at the only stair enclosure, but its generated opening omitted the existing
`swing="out"` egress convention. The leaf therefore swung across the player's
approach and stopped the capsule at z=2.9. The generator now authors the egress
swing, both generated layout copies agree, SR7-Q's closer remains green
(116/116 focused, 35/35 live), and FULL walks the body through to z=4.5.

GoldenLoop's red was measurement debt, now resolved rather than hidden. Its
old x3.5 run reached `return_leg` at 36.6 s and the repair boundary at roughly
52 s; the 52 s watchdog necessarily interrupted a healthy mirrored route.
x8/480 overloaded this production scene and advanced less far. The smallest
safe change—x4/240—keeps capsule displacement per physics step stable. Its
permanent block timings show boot 18.1 s, outbound 16.4 s, return 16.1 s and all
remaining logic under 1.7 s. The internal guard is 57 s, still subordinate to
the runner's non-negotiable 60 s process ceiling.

WalkTest's monolithic FULL was also measurement debt. Permanent phase markers
showed that its physical prefix and its eight authored call performances were
both healthy but could not share one 60-second process. Random resident lift
use added more than twenty seconds because independent service was taken only
after a resident trip began. FULL now takes the service key before simulation,
combines its duplicate empty and occupied shaft trips into one real
rider-carrying F01→F06 journey, and exposes a production-neutral test travel
multiplier. `CallInterface.fast_factor` makes the existing test hook explicit;
shipping remains 1.0 while WalkTest uses 0.02 and still observes every verb,
consequence and transition. The release proof is honestly sharded: PHYSICAL
owns traversal through Case 01/Room 0; CASES owns the complete call and
presentation batch. Both boot production independently, print verdicts, and
together retain the former coverage without relaxing the runner ceiling.

### Runtime errors that are not yet gate failures

- Resident routines repeatedly report no wall-safe route on F01–F04 during
  long production boots. This is consistent with the already-open navigation
  work in `TASKS.md`; it is not silently attributed to the golden-shift logic.
- Waking tentacle construction asked a `ReflectionProbe` for its global
  transform before adding it to the tree. The probe is now parented before its
  global position is assigned; focused proof passes 27/27.
- Found-art placement warns that `cam_noel_witches` has no legal wall. This is
  a named presentation warning, not a parse or route failure.

### Established baseline debt

- FAST's authored-job/chirp expectation.
- Boiler long-parts merge at 23 meshes.

These remain baseline debt until separately ruled or repaired; their recurrence
must not normalize new failures.

## Performance status

The historical eight-station numbers are not promoted to current evidence; the
production harness now owns eleven stations. Its aggregate run warms all eleven
and can no longer finish under the 60-second ceiling, so current evidence must
use `PERF_STATION` with one fresh serialized process per camera.

The first 2560×1440 Forward+ sweep at the shipping 64-light/16-shadow budget
produced the following table. It is retained to show how the diagnosis moved,
but it is **superseded as production evidence**: the detached benchmark camera
moved while the player, carried shadow-casting lamp and streaming origin stayed
elsewhere. Composition cameras also silently inherited a player light despite
occupying positions no body can reach.

| station | objects | calls | primitives | mean ms | fps | status |
|---|---:|---:|---:|---:|---:|---|
| lobby | 22,754 | 22,620 | 23,384,479 | 23.81 | 42 | OVER |
| atrium eye (7 storeys) | 26,276 | 26,143 | 37,219,096 | 33.33 | 30 | OVER |
| corridor F04 | 15,685 | 15,685 | 18,333,849 | 16.67 | 60 | OVER |
| apartment 4B | 4,082 | 4,082 | 5,774,976 | 11.67 | 85.7 | PASS |
| street elevation | 17,480 | 17,480 | 13,133,510 | 27.45 | 36.4 | OVER |
| roof | 2,466 | 2,466 | 662,076 | 6.25 | 160 | PASS |
| Harukiya (16 fixtures) | 5,327 | 5,067 | 6,266,534 | 11.67 | 85.7 | PASS |
| arcade cluster (5 live) | 3,747 | 3,484 | 5,143,404 | 10.00 | 100 | PASS |
| Passage throat reveal | 3,158 | 2,898 | 945,578 | 8.33 | 120 | PASS |
| Passage hall southbound | 3,590 | 3,184 | 903,974 | 9.26 | 108 | PASS |
| Passage hall northbound | 6,166 | 6,024 | 3,704,731 | 11.11 | 90 | PASS |

Lobby and atrium improve on the old indicative map baseline (28.78 ms and
41.24 ms respectively), but neither meets 16.6 ms. Corridor F04 sits on the
boundary but fails the strict target at 16.67 ms. Street elevation is the third
clear hotspot at 27.45 ms, while apartment 4B, Harukiya, the arcade cluster and
two Passage views and the unmodified production roof all pass. This concentrates
the current breach in lobby/atrium/street long views rather than Passage content,
separates exterior composition cost from Harukiya's sixteen fixtures, and
supersedes the earlier unpaired hidden-fixture diagnostic with no license for
that withdrawn candidate.

The corrected instrument declares every station `playable` or `composition`.
Playable stations move body, eye, carried light and streaming origin together;
composition cameras have no invented player light. It also adds the two
gameplay views the old list lacked. Corrected rows so far:

| station | class | objects | calls | primitives | mean ms | fps | status |
|---|---|---:|---:|---:|---:|---:|---|
| lobby | playable | 15,797 | 15,669 | 13,401,880 | 18.06 | 55.4 | OVER |
| atrium eye (7 storeys) | composition | 26,316 | 26,183 | 37,225,302 | 33.33 | 30 | OVER |
| atrium F03 landing | playable | 21,149 | 21,149 | 36,040,694 | 23.70 | 42.2 | OVER |
| corridor F04 | playable | 9,245 | 9,245 | 9,305,874 | 12.96 | 77.1 | PASS |
| apartment 4B | playable | 2,883 | 2,883 | 3,644,382 | 10.61 | 94.3 | PASS |
| street elevation | composition | 17,504 | 17,504 | 13,162,494 | 27.08 | 36.9 | OVER |
| carriageway north pavement | playable | 10,162 | 10,162 | 9,867,193 | 16.67 | 60 | OVER (boundary) |
| roof | playable | 2,544 | 2,544 | 687,568 | 6.45 | 155.0 | PASS |
| Harukiya (16 fixtures) | playable | 5,110 | 4,849 | 5,813,296 | 11.31 | 88.4 | PASS |
| arcade cluster (5 live) | playable | 4,016 | 3,753 | 5,756,000 | 10.61 | 94.3 | PASS |

The original atrium-eye lens is over the open void: moving the player there
made the body fall to B1 while the detached lens stayed aloft. It remains a
useful worst-case composition camera but is not cited as gameplay performance.
The F03 landing is a real player position and proves a material 23.70 ms breach.
Carriageway, like corridor F04 in the superseded sweep, misses the strict gate
by 0.07 ms and is treated as a boundary measurement rather than as equivalent
to the clear long-view hotspots. Correct feet-based streaming moves corridor
F04 from 16.67 to a clear 12.96 ms pass and lobby from 23.81 to 18.06 ms. The
remaining three corrected stations are owed.

The corrected landing census explains the shape: roughly 1,314 visible calls
and 19,299 shadow calls. The frame is dominated by repeated caster submission,
not visible scene complexity. Blind prop merging and a 12 m prop cull were
rejected by current decomposition; neither improves this frame reliably.

A focused shadow-budget sweep keeps all 64 lights and changes only how many
ranked fixtures cast. Fresh-process landing results: 64/16 = 23.70 ms; 64/8 =
18.02 ms; 64/6 = 16.67 ms (strict boundary fail); 64/5 = 15.28 ms (pass,
16.18 ms wall average). This is a measured bound, not yet a shipping policy.
The 64/5 result repeated at 15.28 ms. Its frozen same-camera visual pair prices
at 0.01761 RMSE on the architecture crop against a 0.01098 temporal floor
(1.60x); inspection finds no lost railing, landing, relief or practical-light
legibility. That clears the playable atrium candidate, but not a global cap:
representative interiors and the exterior still require paired review before
production lighting changes.

Both FULL shards now print final verdicts below the wall-clock ceiling.
GoldenLoop prices its complete route at 53.7 s. Performance evidence is being
rebuilt on the corrected thirteen-station instrument. Serialized measurement
is interleaved with Claude's K2 proof runs without contention.

## Next executable order

1. Finish the remaining three corrected performance stations, then measure the
   shadow-budget policy against the playable atrium landing with a visual A/B.
2. Continue K2's human fresh-save playthrough and K3's eleven-boundary
   save matrix.
