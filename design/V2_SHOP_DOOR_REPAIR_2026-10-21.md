# V2 responsiveness, targeting and existing-content repairs

Evidence class: **INERT**. Scoped repair report and issue log; not whole-V2 or
human acceptance. Original schema-2 contracts remain separate from diagnostics.

The measured movement route is substantially faster and its worst spikes are
smaller, but it remains below a 60 FPS target. Existing native detail, physical
obstructions and mechanical/save authorities are retained. The reticle follows
the actual operable part and accepted constraint state.

## Performance method and results

Actual windowed Forward+ world, RTX 4080, 1280 x 720, VSync off, uncapped. The
same two-cycle controller route covers movement, turning, cell changes, detailed
furnishings and shop-door grabs. The longer physical repair route additionally
covers fault diagnosis, procurement and repair. A separate full-world diagnostic
measures actual Space camera entry, free-cursor selection, hand movement and exit.
There is no original-source before sample for that camera transition, so no
transition-speed improvement is claimed. Raw wall-frame samples and
original wrapper receipts remain under **art/reviews/v2_responsiveness_20261021/**
and **art/reviews/v2_shop_door_repair_20261021/**. Percentiles use sorted sample
at min(N-1, floor(N*p)). Timed routes produce different sample counts.

| Route / version | Frames | p50 / p95 / p99 / max, ms | Frames >100 ms |
|---|---:|---|---:|
| Original two-cycle route | 801 | 71.343 / 104.288 / 547.389 / 1093.229 | 47 |
| First reticle/cache checkpoint | 821 | 72.474 / 107.131 / 148.586 / 275.787 | 57 |
| Raw-buffer/fitting checkpoint | 985 | 43.814 / 65.777 / 105.076 / 261.808 | 14 |
| Reflection-repair control | 986 | 42.993 / 65.951 / 110.096 / 266.981 | 16 |
| Final two-cycle route | 1010 | 40.008 / 59.447 / 108.420 / 267.882 | 12 |
| Earlier 94-waypoint repair route | 3157 | 31.937 / 67.392 / 279.031 / 2327.624 | 68 |
| Final 94-waypoint repair route | 3518 | 30.814 / 64.495 / 118.695 / 364.821 | 42 |

Both final controller routes pass: **16** and **94 waypoints**, respectively,
with no failures or Script Errors. The short route has **one** frame over 250 ms;
the long route has **five**, down from **45**. The final long-route maximum
occurs in the hardware-counter phase; another counter frame reaches 344.546 ms.
The sampled process counter reaches 342.669 ms nearby, main-view GPU remains
about 15–16 ms and pipeline counters do not advance on those two frames. This
locates remaining CPU-side work without identifying an exact callback or
asset-I/O duration. Detailed physics instrumentation is disabled in the full
route; its raw zero rejection counter is not evidence of zero guarded contacts.
The separate paired stair controls provide that attribution.

Per-phase distributions keep both short-route cycles separate in
**final_phase_comparison.json**. Persistent driver/cache history was not reset;
combined-route gains are not assigned to one individual repair. Final in-run
controls show live-reference drift (34.818→41.360 ms medians), so they do not
support exact script-cost subtraction. Frozen depth-view controls bracket
28.932 ms with that view disabled versus 30.105/30.415 ms reference/restored controls.
These diagnostic controls are separate from live-route qualification. The separate
quiet Space-camera diagnostic passes 27 checks over three enter/cursor/drag/exit
cycles: 894 frames, p50/p95/p99/max **37.919/46.117/56.636/180.686 ms**,
one frame over 100 ms. Entry dispatch costs **19.746–20.237 ms**; exit dispatch
**1.355–1.440 ms**. Seven sampled frames per entry window peak at **77.466,
61.902 and 60.638 ms**. These small windows are retained individually rather
than presented as stable tail percentiles. Dispatch time is CPU work, not
input-to-display latency. The first functional pass overlapped static tests and
is excluded from timing conclusions; its original results remain.
The main-view median CPU/GPU counters were 16.287/11.486 ms in the fitting
checkpoint. These omit other views. Engine process/physics counters lag and
are not additive traces. Pipeline counts establish compilation activity, not
precise shader compilation time. No input-to-photon latency measurement is
claimed. Script isolation, physics-stage timings, raw fitting/cache timings,
streaming lifecycle checks and paired depth-view rendering controls separate
the major costs without attributing every frame to a single subsystem.

The paired stair route reproduced 3120.604 ms and 2755.988 ms original maxima;
the guarded candidate reaches 241.863 ms. Ordinary sliding still resolves all
blockers. Atomic native fitting and retirement can still produce roughly
250 ms frames. Cooperative work yields between operations, not inside each
native operation. Rejected retirement and final-slot-upload candidates did not
improve the worst frames and are not retained.

## Concise issue log

| Location / severity | Reproduction and evidence | Repair | Verification |
|---|---|---|---|
| Player targeting / medium | Legacy dot gave no latch, refusal or travel-stop state and duplicated target work | Restrained keylined ring, warm grabbed ring, blocked cross, stop bars and inspection arc; one authoritative target resolver, no hover scan while grabbed | 54 windowed actual-input checks: specific parts, primary grab, motion, next-click release, limits, locked refusal and free inspection cursor |
| Eleven arcade thresholds / high | Original leaf collision bottom and terrazzo top both at 10 mm; physical sweep refuses motion | Native lower edge at 16 mm gives 6 mm clearance; original upper bearing at 2090 mm retained | 161 final door checks, all eleven 0–90 degree sweeps sampled every degree, native/render review |
| Arcade leaf/jamb envelope / high | Failed 55 mm candidate contacts retained stock near 76–77 degrees; old 100 degree stop overtravels near 94 | Fit original 44 mm bearing and physical 90 degree stop; query shell plus six pull/support shapes through existing mask, self-exclusion and 1 mm margin | Original failed source/export/log retained; no wall, floor, player or stock exclusion; legacy finite 100 degree save restores at fitted stop |
| Arcade construction / medium | Empty lower field, separated glazing and pulls in glass field | Thirteen closed native stocks, lower panel, flush joinery, rebated glass and stile-supported pulls; existing custom oak/brass/glass | Blender review, imported UV/PBR/mip checks and eleven installed open-leaf views |
| Passage persistence / high | Shop leaves outside original household adapter scan lose partial angles | Explicit stable actors register with existing household save authority | Actual disk save, world destruction and reconstruction preserve eleven angles and effective locks; old absent records retain defaults |
| Service 2B radiator / high frame cost | Repeated tree search costs about 8 ms/frame in isolated controls | Weak WorkOrders owner cache; mutable job state stays live | Nine late-create, detach, retirement and replacement controls; physical service/save renewal |
| Eight fire nozzles / high frame cost | Unchanged pose submissions cost about 5.6 ms/frame in isolated controls | Exact submitted-world, accepted-local and parent-world guards | Actual carry/thread/inspection and ancestor-PhysicsServer controls; no tolerance change |
| Warm native fittings / high spikes | Repeated full-buffer serialization and copying | Read complete native buffers once, hash raw bytes directly, preserve all resource properties; bounded 96 MiB collision cache | 73 mutation/copy/lifetime checks, 279 exact fitter comparisons; druggist operation about 124→76 ms, hash about 78→39 ms |
| Streamed arcade fabric / high spikes | Canopy, throat, lantern, clock and retained finishes share one atomic task | Same ordered operations may yield between fittings under existing staging budget | 52 actual route waypoints, all 13 cells ready before protected gateway, four unique native batches and 34 exact replacement boundaries |
| F02 fire-line stair / high stalls | Walking into tall cabinet-side stock causes repeated expensive step casts | Previous resolved opposing contact above legal 0.30 m step skips redundant step casts; ordinary collision sliding retained | 27 actual waypoints and nine low-step/tall-wall/headroom/removed-wall controls; paired original/candidate/restored timings |
| Caption retirement / script error | Subject frees reparented Label3D before owner cleanup | Validate Variant before typed live reference | Live/freed/repeated cleanup and 94-waypoint physical repair route; no case/text/timing change |
| Lamp scene-depth view / high render cost | Redundant shadow atlas and fixed-light work in unshaded depth view | Atlas zero, V2 occlusion and guarded depth-light isolation; shared defaults unchanged | 32 atlas/occlusion and 16 light-isolation nonvacuous byte comparisons across four native stations; 11 layer/lifecycle checks; shared Dream 50 checks |
| Depth-light ownership / regression risk | Independent layer-one camera or reserved-layer geometry could lose light/depth | Restore only owned light layers on retirement; independent camera disables optimization; late reserved geometry restores full depth | Actual world camera/geometry fallback controls; PBR A/B/A differences below restored-control variation; frozen depth controls save about 0.4–0.9 ms indoors and 2.7–3.3 ms roof |
| F03 B bath / F06 B kitchen / medium glare | Persistent clipped white surfaces survive lamp/all-light/receiver/SSIL controls | Disable duplicate diffuse reflection-probe ambient only; retain specular, sky, box projection, fixture output, SSIL and shadows | Normal/ambient/interior/intensity/zero/restored controls; broad clipping falls 75.608%→0.0026% and 37.535%→0.0056%; fresh composed witnesses reviewed |
| Mina bookshelf silhouette / diagnosis | Raised black silhouette previously suspected stray geometry | Retained: diagnosed cast shadow | No geometry removed on that diagnosis |

## Qualification, failures and limits

The fresh LF-executed **surface_final_v6** passes **40,140 technical checks**.
Independent qualification and canonical publication pass: **28,339 draws,
6,436 materials and 530 textures**, normalized input hash
**09a56bdb883265b8caa86502e26e95c27842a3ae1038c03c8a20b09fb1b61ea6**.
The prior broad review inspected 242 frames on 21 sheets with identical normalized
rendering inputs. Twenty fresh v6 witnesses were reviewed on three sheets; both
glare repairs were also viewed full resolution. This is agent technical review.
Two old omitted-prop stations face walls; they do not prove those props' appearance.
Small lamp/glass highlights still clip and remain appearance polish.

The first surface renewal v5 passed technical assertions but **failed independent
publication** because its executed CRLF root hash differed from normalized LF.
Its exact executed source, receipt, inventory, renders and logs are preserved.
No receipt was edited or repinned. Fresh v6 execution repaired that evidence gap.

Fresh first-slice proof independently verifies **359 serialized / 360 printed
checks**, actual disk save and CampaignShell reconstruction. Its dialogue/call
and prior-job fixtures remain explicit. Fresh upper proof verifies **69 rooms /
11 collision-bearing legs / 993 checks**. Both original packets are published
with predecessor packets preserved. Fresh service proof verifies **27 rooms / six direct connections**; public
landing proof verifies **six rooms**; exterior proof verifies **six regions /
six routes**. All three original packets are independently published with their
predecessors retained. The settled camera census accounts for all **226 areas**:
**225 captured / 900 views**, reviewed on **29 contact sheets**, plus three
full-resolution west-opening alcove views reached through an actual three-point
walk. The initial diagnostic parse failure and cabinet-blocked approach remain;
the corrected route follows the authored lobby opening around retained stock.
No interior capsule stance is claimed for that shallow recess. These cameras
check broad appearance and continuity; they do not grant access or fine-contact
acceptance. The ladder is visible in the renewed laundry view. The restroom
view shows the mop and upper bucket but crops its lowest contact. Final timed
movement routes pass with the distributions above. All seven published
qualification packets independently reverify against the final normalized
production/runtime sources after the runs and line-ending cleanup.

Residency's inherited five-second stationary readiness assertion failed with
cooperative fitting. The original failure remains. The replacement exercises
ordinary street approach and requires all thirteen cells before the protected
gateway; measured approach 14.596 seconds. This is not a five-second guarantee.
The old E-prompt and retired floating-ornament expectations were replaced by
actual hand operations and explicit current native-batch predicates. Teardown
passes five checks with drain 1351.799 ms. These are diagnostics, not ledger grants.

A proposed native safety-wire convex substitution was rejected despite faster
capsule casts: ray-boundary error reached 0.282 mm. Original native triangles
remain. Rejected collision-branch timing (player fell), failed fixtures and
original timeout receipts remain in **diagnostic_dispositions.json**. Seven
existing Texture RID shutdown warnings persist; no leak-free claim.

Bodega preflight caught an old DoorProp source binding. The original Blender
recipe reproduced byte-identical export **a780cffaed39caf71a51e0ad2cb985256060455f6e75464d59dadc40692d140a**;
only binding metadata changed. No generated glTF hand edit or validator waiver.

## Management report

REPORT - V2-RESPONSIVENESS-EXISTING-CONTENT - 2026-10-21

Branch: **codex/v2-acoustic-topology**. Pushed repair checkpoints:
**120c8fc9**, **f82a4f08**, **f4f41258**, **1762e9fd**.
Validation HEAD: **87ce3dad**; origin/main and merge-base:
**21f0b1fc27ac8e25c8466fe1ed2ce64019ee7ede**. The final report/artifact commit follows
these unchanged production sources. The board captured identical tested source
bytes before that checkpoint. **Protected 17/17 pass**, selector **V2**;
explicit V1 rollback remains. **final_board_registered/board.json** records
**109 PASS / one existing INCOMPLETE**, **98 tools tests passing**, zero comparison
regressions and zero NEW reader fields. Completeness exits **2 (INCOMPLETE)**;
spatial, systemic, period, reader and every tools test exit **0**. Each gate
and test has its individual real result in the board; Godot outcomes bind to
the named original wrapper receipts and separate test-written contracts.

Six scope blocker counts, ordered FIRST_SLICE_TECHNICAL / FULL_BUILDING_RUNTIME /
FULL_BUILDING_STRUCTURAL / GOLDEN_SHIFT_V2 / PRODUCTION_CUTOVER / V1_RETIREMENT:
**0/26/56/1/73/75 → 0/25/21/1/38/40**. Thirty-eight source-bound requirements
regain spatial proof from renewed physical cohorts; the full changed-id list is
in the board comparison. Status counts are ABSENT **4**, PROGRAMMED **29**,
SPATIALLY_PROVEN **172**, RUNTIME_PROVEN **34**, HUMAN_ACCEPTED **1**; ANCHOR_ONLY and SHELL_ONLY **0**.
The starting board was already dirty (751 paths), so this is a diagnostic
comparison, not a clean merge-base certificate.

Worktree clean at end: **no**. Shared untracked assets/UIDs remain untouched;
line-ending-only source/import churn has been checked and cleared. Only named
owned paths are staged; no unrelated semantic edits were restored. The
in-place management verifier requires a fully clean tree, so no clean candidate
certificate is claimed. Do not stage other contributors' files to manufacture one.

Outside expected boundary: **19 appended test-only spatial fixture bindings**
retain every previous manifest row and all live classifications. Two pre-existing
incidental references remain. No audit predicate or baseline changes; the original
comparison failure is preserved in **final_board/**. One reviewed collision-name
declaration inventories existing generated stock; household registration repairs
existing persistence; source-bound fixture renewals retain
original failures; shared optical helpers gain optional V2 behavior with unchanged
defaults. No protected world authority, gate predicate or failed receipt is waived.

Open findings: **250–365 ms** frame spikes remain, including atomic fitting/
retirement and counter-phase CPU work; sustained 60 FPS is unqualified. Fine
appearance and lowest mop-bucket contact, small clipped highlights, shutdown warnings
and existing full-V2 ledger blockers. Discovery does not establish acceptance.
Decision needed from owner: **none**. No main merge or whole-V2 completion claimed.
BLOCKED - management candidate clean-tree prerequisite unmet; scoped repair/verification pass complete.
