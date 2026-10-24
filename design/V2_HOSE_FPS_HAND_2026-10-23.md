# Deployed hose hand and contact study

Evidence class: **INERT**. Working diagnostic; no runtime-contract qualification,
production installation, ledger promotion or human acceptance.

## Report

Branch **codex/v2-acoustic-topology**, starting HEAD **37e41d7b**. Canonical
checkout retains unrelated untracked files and spatial-manifest WIP. Protected
paths and selector are unchanged; ledger statuses are unchanged. No complete
clean-main board or merge-candidate certificate is claimed.

## Combined numerical/contact control

The actual-windowed **combined_v1** replays local seed / local seed plus envelope /
restored local seed at the same F02 floor placement, 1280x720, VSync off. All
world and fitting obstructions remain present. It completed six walked waypoints
and zero diagnostic assertions failed; stderr is empty. Its wrapper receipt
records 181.36 seconds.

| Metric | Local A | Combined B | Restored local A |
|---|---:|---:|---:|
| Frame p50 / p95, ms | 329.769 / 530.365 | 153.285 / 163.923 | 307.233 / 350.194 |
| Frame p99/max, ms | 551.469 | 166.717 | 413.164 |
| Follow-call p50 / p95, ms | 35.522 / 37.087 | 4.316 / 4.469 | 35.330 / 36.537 |
| Presented tip movement sum, m | .434531 | .340008 | .339869 |
| Error-free samples | 40/40 | 40/40 | 40/40 |

The first and restored local legs have different trajectories despite restored
cloth and camera poses. The middle/restored legs are much closer in movement,
and the per-call reduction is substantial, but this is not a perfectly identical
trajectory comparison or a whole-game performance claim. Numerical/physics
starting state needs tighter replay control. Timing scopes overlap.

## Aim and pickup repair

Previously the generic free pickup supplied position only. The candidate now
optionally supplies a hose-mouth direction through real neck pins, with matching
local-seed pins. The resulting native fitting still passes the original physical
sweep before cloth and receiver publication. It does not rotate the visual alone.
An optional once-per-presented-frame hand update bounds repeated catch-up work;
accepted motion is still checked against the live world. Translation toward the
hand precedes turning beside the rack.

The first **aim_v1** diagnostic completed but failed requested aim: it reached
about 58 degrees error, then reported nozzle obstruction. **aim_v2** staged
withdrawal and bounded hand work: 40 calls / 40 sampled frames, p50 143.821 ms,
p95 164.693 ms, max 173.846 ms and zero frames above 250 ms. It still stopped
after .18 m and retained about 80 degrees aim error. These are behavior failures
despite diagnostic completion. **aim_v3** identified the barrel arc cast as the
stopping check; its exact-boundary probe did not identify a collider.

Manual fitting queries now inherit only the carried body's existing collision
exceptions, respecting the shared holder/unlocked-leaf behavior. The visible
PlayPipe is a sibling of its PhysicalNozzle body, so ancestor discovery previously
registered no carried body. The descriptor now names that existing body, and
shared grab binding falls back to ancestor discovery for all existing pickups.
No wall or locked-leaf exception is invented. Coupling, inventory, case and save
authorities remain unchanged. The final played check is recorded below.

**aim_v5** confirms actual sibling-body registration, but the same withdrawal
still stops: p95 117.235 ms, .18 m movement and about 80 degrees final aim error.
That registration repair is necessary ownership work, not proof the jam is fixed.

The **cast_capture_v1** diagnostic preserved the exact failed convex cast and
nearby real collider shapes. **cast_replay_v1** reproduced both fractions exactly:
**[0.47265625, 0.4765625]**. Its sole candidate is the fire cabinet's open
**CabinetDoor/NativeHandCollision**, not a wall or the player. The isolated replay
is a diagnostic equivalent for that cast only, not a world qualification.

Following the owner's passage-first door direction, the candidate now temporarily
excepts that open cover from the carried nozzle and carrier. It retains targeting,
door state and collision with unrelated bodies. It removes only exceptions it
added when releasing or exiting. Native fitting queries consume the same body's
exception list. The full cloth/world/self and wall checks remain in place.

**aim_v6** verifies the effect in the played world: no nozzle-obstructed sample,
.389726 m presented movement and a turn toward the reticle. It then hits
**wide nonlinear projection ceiling** in 31/40 samples; median aim error is
45.889 degrees. Frame p50/p95/max is 145.085 / 168.780 / 208.054 ms, with no
frames above 250 ms. This removes the observed cover jam but still fails usable
aim and performance. Next: local response solving with contact constraints,
followed by an actual walked withdrawal/turn. Do not install this prototype or
describe the hose as usable from these diagnostics.

Shared-grab regressions after explicit sibling-body binding: **book_regression**
passes 89 checks, **stock_regression** passes 72, **door_regression** passes 34;
all three wrapper receipts record completed execution and empty stderr. These
focused actual-input diagnostics retain their own scope. They do not establish
full V2 qualification. Original failures and the exact cast replay remain in
**art/reviews/v2_hose_carry_20261023**. Source archives use LF-normalized hashes;
raw logs and records remain byte-bound under the packet's Git rule.

The first **hose_regression** failed two assertions with zero carry. Source
inspection found its isolated player disables physics and never calls the FPS
hand-follow path after mouse events. The migrated bench explicitly drives that
same PlayerController hand publication after input, retaining the native
obstruction, unchanged release pose and loaded-map checks. Its original failure
is retained. A manual free-point drag does not establish FPS compliance.

**hose_regression_v2** then moved correctly but its old one-event obstacle
expectation did not reach the wall. **hose_regression_v3** drives repeated actual
FPS input until the hand reaches a wider explicit wall, reads the authoritative
feedback method and verifies both current native fitting and cloth clearance.
It passes 21 checks, including blocked feedback and release, in 15.70 seconds
with empty stderr. This is the isolated hand/surface diagnostic, not the missing
played-world aiming or deployment qualification. Both preceding failures remain.

The reader audit retains the same 33 NEW findings in the uninstalled street/tent
programme. This change introduces no new runtime data record; no baseline was
widened. Full gate-board and clean-main candidate verification remain outstanding.

## Remaining work

Broader aiming/carry coverage, full deployment, physical release, moving obstacles, water/supply/valve,
maintenance handoff and coupling-aware save/rebuild remain required. The round
candidate remains outside production. All 15.24 m, native fitting checks,
material and bend bounds, and world/self collision checks are retained.
The broader book/nook qualifications, mirror/avatar, street and systematic V2
coverage remain active. No owner decision is needed.

## Latest batch: shared contact ownership and walked FPS hold

Starting HEAD **ff1ce58e**. **local_contacts_v1** extended the optional local seed
to contact planes, but still hit the same nonlinear ceiling in 31/40 samples.
That experiment did not fix the observed stall. Its raw timings and failure
are retained. The callback remains optional, off by default, and no
separate performance benefit is claimed for it.

**solver_capture_v1** preserved the failing seed, six near-end contact planes,
pins, radii and material lengths. Its original source-name lookup searched only
the building subtree and left the six RID names unresolved; the lookup now
includes the complete scene tree. Do not treat those old unresolved names as
identified collider evidence. **solver_replay_v1** independently reproduces
**wide nonlinear projection ceiling** with those planes; the same numerical
input succeeds without them. It is a numerical diagnosis, not gameplay proof.

The cloth owner now consumes the carried body's live authoritative exception
list, matching the fitting queries. Both its original shell query and capsule
envelope query update together. Release restores the original exclusions.
There is no world-contact answer cache and no extra reticle scan. Walls, locked
leaves, native fittings, self contact, material length and bend bounds remain
under their existing owners.

**carry_contacts_v1** then completes the original standing/turning input with
40 error-free samples and approximately .25-degree settled aim error. The
stronger **carry_walk_v1** and **carry_walk_v2** intentionally expose a further
failure: fixed six-centimetre travel per rendered frame cannot keep up with
actual player movement. The traced receiver reaches the hand, but staged
withdrawal leaves too few turns within the original settling window. The
nozzle body's authored 30 mm offset also needed to be distinguished from the
receiver's intended hand position in that test. Both failures are preserved.

FPS hand travel now follows elapsed time, with up to .6 m requested travel,
the original maximum 8 cm substeps, and a 12 ms prepare-work budget. Every
accepted substep retains native world/self checks and final fitting/commit
checks. The budget is checked between bounded solves; it is not a hard upper
bound on the whole hand update. Existing callers keep their original 8 cm
request / 6 ms prepare defaults. Turning retains the 6 rad/s rate, with a
100 ms elapsed-time cap for low frame rates.

**carry_walk_v3.log.receipt.json** records a completed actual-windowed run with
seven walked waypoints and zero assertions failed. It verifies settled aim
within one degree, actual walked withdrawal while holding, physical native
world/fitting clearance, full material/bend bounds and release cleanup. After
walking, aim settles to zero and receiver-to-hand error is about .7 micrometres;
the first three recorded settling frames reduce aim from 67.4 to 33.0 to zero
degrees. The final capture was visually reviewed. This remains a scoped F02
diagnostic; it is not all-station gameplay qualification or human acceptance.

At unchanged 1280x720 / VSync off, the 40-frame standing/turning window has p50
134.822 ms, p95 143.918 ms, p99/max 146.922 ms. It remains unacceptably slow.
All five recorded compilation counters have zero increments in this window.
The 67 recorded setter calls, including the walked segment, have p50 4.356 ms,
p95 6.337 ms and max 16.165 ms. Pending process continuations are reflected in
frame/process monitors but are not separate setter-call records. These nested
scopes overlap; do not sum them or represent the mixed calls as a fair route
comparison. No general performance improvement or production installation is
claimed from this passing behavior diagnostic.

**live_contact_controls** passes all 35 existing/extended native assertions,
including live exclusion and restoration, hollow bore, flattened native stock,
thin-wall sweep and measured response. **live_contact_hand** passes all 21
actual-input hand, loaded-map, wall/reticle and release assertions. Both wrapper
receipts record completed execution with empty stderr. Wrapper receipts remain
**suite_run**, not **runtime_contract**. Existing full-board and clean-main
candidate-verification limitations remain. The reader audit still exits 1 on
the same 33 NEW uninstalled street/tent findings; its baseline was not widened.
All 17 protected paths still match the recorded merge-base. Current changed
source is archived with LF-normalized hashes; earlier diagnostic run receipts
do not constitute a source-bound runtime contract.

| Location / reproduction | Severity | Evidence | Repair | Verification |
|---|---|---|---|---|
| F02, grab deployed nozzle and turn | High | Captured contact planes cause the nonlinear ceiling; original names unresolved | Share live carried-body exceptions across cloth and fitting queries | 40 error-free standing/turning samples; strict settled aim below one degree |
| F02, walk away while holding | High | Fixed per-frame travel leaves a 1.2 m catch-up request; two original failures retained | Elapsed-time travel with bounded substeps and prepare budget | Seven walked waypoints; hand/aim, physical-clearance and release assertions pass |
| Same route, steady detailed world view | High / open | Standing p95 143.918 ms, no compilation-counter changes | Follow cost bounded and measured; broader cost not repaired | No general performance qualification claimed |

Next: full-payout and sustained walked carry, physical release, away-from-cabinet
inspection, supply valve / controllable spray, maintenance handoff and save /
rebuild before installing the candidate. Continue measured broader frame-cost
diagnosis and the remaining mirror/avatar, street and systematic V2 work.
