# Bathroom finishing repair

Evidence class: **INERT**. Issue log and candidate diagnostics; no completeness
promotion, runtime qualification or human acceptance.

REPORT - V2-BATHROOM-FINISHING - 2026-10-24

Branch: **codex/v2-acoustic-topology**. Parent: **1a2029b4**.
Checkout: **C:/PleaseRemainOnTheLine**. Final installed diagnostic: **frame_clearance_world_v1**.

| Location / issue | Reproduction and severity | Evidence and repair | Verification |
|---|---|---|---|
| Existing door surrounds | Look up at a head/jamb corner; medium visual defect: square extrusion ends overlap or butt at 90 degrees. | Ten native dimension/style stocks retain the original moulding profiles and use matching 45-degree cap vertices. Two complete front instances replace six individual extrusions in the same draw batch, with identical rendered triangle totals. | Imported stock **mitre_stock_v2**: 43 checks, zero failures. Earlier installed **world_v2**: all109 surrounds,654 wall contacts and272 service fixings pass66,400 casing checks; that aggregate bathroom run still failed other checks. Final **world_v7** passes66,400 casing assertions with no engine/script errors; seven historical Texture-RID teardown warnings remain. Earlier aggregate failures and metadata-error run remain. |
| All19 wet rooms | Full-height tile and tiled opening returns; medium visual defect. | 1.2192m tile wainscot, plaster above, and2.286m protection around actual shower positions. Door paint remains its architectural owner. Original walls, openings and collision stay intact. | Both finish batches in all19 rooms pass the retained metric UV, unit normal/tangent and UV-derivative checks in **finish_stock_v3**. Final **world_v7** includes20 fully loaded PBR maps and the actual4B render; other rooms receive structural/material checks, not individual visual acceptance. |
| Wet-room joints | Missing narrow wall/floor and wall/wall bead; medium visual defect. | Three-millimetre quarter-round mortar joints follow actual cut wall faces and stop at openings. Existing wet-room wooden skirting is retired by the finishing layer. One tile and one grout batch per room; no processing or collision added. | Same38 imported/generated architectural batches; no UV/basis tolerance weakened. |
| All18 showers | Rail plates end before the wall; rings float or meet the wrong curve; high visual defect. | Native sockets, stems, seated escutcheons and fixings match five installed rear-wall datums. One common circular-elbow rail path positions the drawn rings; gathered rings bear on the straight side. Hooks and sewn eyelets connect the cloth. | Original failed wall-contact diagnostics preserved. **finish_stock_v10** passes144 backing rays and36 full mounting-pad checks; Final **world_v7** passes144 installed rays and real curtain opening/closing. |
| **F05_A_BATH**, **F06_A_BATH**, **F03_D_BATH**, **F04_D_BATH** | A support lands in a window or the receptor/rail enters a perpendicular partition; medium physical/visual defect. | Shift the complete live fixture locally80mm in the first pair and175mm in the second. Receptor, collision, controls and rail move together; original semantic/acoustic/save identities remain. Tile protection uses the same declared installation correction. | Measured feasible offset169–181mm in the second pair;175mm passes both complete plates. No obstruction is bypassed. |
| Shower rose | Swan-neck ends above an unsupported head; medium visual defect. | Vertical terminal tangent, threaded tail, stop shoulder, hexagonal union and raised receiving boss overlap at intentional mechanical seats. No water or valve authority changes. | Native close-up and final exported tangent derivatives pass; Godot close-up **world_v6/shower_head_union.png** reviewed. |
| Tile finish edge, owner follow-up | The thin flat top cap reads as an unfinished field-tile edge; medium visual defect. | Add a restrained glazed ceramic bullnose along exposed top runs and taller shower returns, with deliberate corners and terminations. Keep this separate from the already frozen performance comparison. | Architectural stock passes57 retained UV/basis batches; **frame_clearance_world_v1** renders the clean casing termination and retains actual curtain input. |

Form reference, not proof of1928 dating: the [NPS building survey](https://npshistory.com/publications/spar/hsr-bldg-5-6.pdf)
documents tile wainscot, plaster above and tiled shower walls, but identifies
bathroom finishes as later alterations. The selected heights are game design
dimensions; that report does not establish their original period date.
Existing registered tile, plaster, nickel, enamel, rubber, cloth and mortar
maps remain their custom PBR owners. No new material key or reference image
is baked into an asset.

## Measured construction tradeoff

The complete shower source drops from218,840 to98,840 triangles. The actual
4B drawn-pose stock drops from134,552 to49,424 triangles. Metre charts and
explicit tangents increase that pose's exported vertices from100,340 to140,020;
the source GLB grows from6,446,500 to14,262,600 bytes. These are source counts,
not GPU timings or a memory improvement claim. Compare the same playable
route before judging the net frame-time effect.

Over-tessellated hems and tiny jet cylinders are simplified. A two-sided cloth
skin keeps real sewn hems/selvedges; an inward solidify shell caused invalid
tangent frames in tightly gathered folds. Local normal repairs affect only
bad actual tangent frames. All seventeen final native material stocks pass
exported derivatives, minimum agreement0.99992366. No resting cloth simulation,
new lights or reflection viewports are added.

## Evidence, failures and remaining work

Packets: **art/reviews/v2_bathroom_finishing_20261024/** and the final combined
ownership/retirement packet. Every existing failed Godot stdout, stderr and
wrapper receipt remains. Native failed tangent logs remain; failed v6-v9
source/asset snapshots are archived where captured. Earlier v4-v5 native
working exports were overwritten in tmp and are not hash-bound evidence.
Relative-output diagnostics remain at their original paths with packet copies.

The first casing stock failed retained0.5% metric limits under default importer
compression (maximum stretch1.177%); only this asset now uses the repository's
existing precision-import policy. Thresholds remain unchanged. Later whole-world
failures caught missing completion-room depths, window/partition contacts, bad
architectural tangent bases and a diagnostic aiming at the closed-curtain
position after opening. They are diagnostics, not partial runtime acceptance.

The composed **world_v6** has zero assertion failures but552 metadata lookup
errors from the casing diagnostic; it is not a clean result. The check now
guards optional weak metadata before reading it. Native and rendered fixture
inputs remain unchanged. Final **world_v7** passes all assertions with no
engine/script errors, retaining seven historical Texture-RID teardown warnings.

The repeated performance route is recorded below; final board comparison and
named checkpoint publication remain tracked separately. All17 protected path hashes remain unchanged. The previous bathroom mirror route remains
roughly72ms p95 with first-view spikes. No V2 completion is claimed.

## Requested ceramic edging and frame-conflict repair

The owner requested a proper finishing edge during the frozen comparison run.
Manufacturer form references describe rounded bullnose and low-profile quarter
round trim for exposed tile edges: [Daltile trim](https://www.daltile.com/trim-product-category),
[Fireclay ceramic trim guide](https://assets.fireclaytile.com/resources/FireclayTile-Trim-Guide-Original-Ceramic.pdf).
These inform the ceramic profile, not a claim of exact historical dating. The
previous flat4.5mm cap was not the requested finished edging. The edging belongs to the existing procedural architectural finish layer,
not a new prop. A30mm glazed profile has a10mm rounded shoulder, matching
mitres across wall corners and cap/return transitions, and glazed end caps.
Union boundaries omit internal field/shower seams and tiled room corners. It
adds one static material batch per room, reusing registered porcelain PBR maps
on one world-local material; no new texture, collision, process or frame scan.
The final installed render and repeated route are recorded below.

## Frozen comparison before requested ceramic edging

Same1280x720 Forward+ route, uncapped/VSync off, RTX4080; no Blender or static
board during the timed route. Phase-transition samples are excluded and linear
quantiles are recorded in **frame_distributions.json**. Compared with the prior
checkpoint: dry/cold/hot p95 **21.993/24.647/23.175 →22.483/25.456/24.146ms**;
hot mirror **72.285→72.436ms**. Dry maximum **113.878→52.395ms**, with two
frames over50ms in both runs; no cold/hot-developing frames exceed50ms. These
are observations from one run per checkpoint, not an overall speed claim.

All steady phases have passage residency DORMANT. The current hot phase adds
one specialization pipeline; other listed compiler counters stay flat there.
Hot-mirror median main renderCPU/GPU **29.508/18.173ms**, mirror **14.126/6.287ms**;
physics **3.191ms**. These timings overlap and may lag; TIME_PROCESS includes
engine work and does not isolate scripts. Asset-loading/script attribution is
not a controlled isolation in this route. First-view/mirror costs remain open.

High-priority finding: the24 actual curtain callbacks have median147.238ms
and maximum159.714ms, versus281.784/374.362ms before. The mixed median across
all152 constrained events is0.034ms and hides that severe curtain cost. See
**gesture_costs_before_edging.json** for per-gesture groups. The existing **shower_curtain_motion.gd**
rebuilds ArrayMesh surfaces, normals, tangents and triangle selection collision
on each travel update. Targeted CPU/render/physics isolation and removal of
that per-motion rebuild are next, after the requested edging is reviewed. Do
not describe native triangle reduction or this partial callback improvement as
responsive curtain operation. No input-to-photon latency was measured.

**edging_stock_v2** timed out at180s after a genuine missing-argument compile
error in the new material handoff. The log's later nonexistent-function line
triggered the wrapper's stale-cache heuristic, but the preceding parse error
identifies the actual cause. The timeout reports no suite verdict. The corrected
call restores its edge-record argument; original log, stderr and receipt remain.
A waiting broker was subsequently stopped only after verifying its exact owned
batch command and that no canonical engine existed. No engine or other
contributor's process was stopped. Final static checks now precede the new
world run so they cannot overlap the measured route.


The owner caught a real conflict in **edging_world_v1**: the horizontal ceramic
strip crossed into the painted door casing because its boundary followed the
raw masonry opening. Medium visual severity; reproduce at the4B bathroom door
at wainscot height. The repair clips the complete30mm profile envelope against
existing authoritative door-casing boxes and imported window-joinery triangle
bounds. It leaves a flat glazed end with0.2mm construction clearance; it adds no
collision, simulation or per-frame work. **frame_clearance_stock_v1** passes
all57 finish batches, all17 imported shower stocks, mounting contacts and
zero actual ceramic vertices inside joinery across all19 wet rooms. Its stderr
is empty. **frame_clearance_world_v1/bathroom_wainscot.png** visibly terminates
the cap at the casing outer edge. **tile_cap_corner.png** shows the retained
clean shower-return joint; both were reviewed at actual rendered resolution.

The first composed edging diagnostic also exposed12 errors in its inherited
moisture-measure hook, despite zero assertion failures. It is not a clean pass.
Initialize the actual production moisture owner before profiling. Original
stdout/stderr and wrapper receipt remain. Its rendered ceramic lip also cast
an aliased point-light shadow; only this millimetre-scale lip stops casting,
while retaining its rounded geometry, light response and other room casters.
The corrected combined route runs its unchanged timing phases before static
inspection and photographs. No result is inferred from the stopped waiting
review broker; it had launched no engine.


## Final installed diagnostic and performance limits

**frame_clearance_world_v1.log.receipt.json**: completed279s, wrapper exit0,
zero assertion or script/engine errors; seven retained Texture-RID teardown
warnings. The test writes **finishes.json**, **frames.json** and actual images.
All109 door surrounds/654 wall contacts and17 service frames/272 fixings pass
66,400 retained checks. Actual curtain click-grab, mouse movement and second
click release pass. This remains an INERT diagnostic, not runtime_contract or
human acceptance. The final source snapshot is **source_frame_clearance_v1**.

Matched-route previous checkpoint → final p95 (ms): dry21.993→23.346,
cold24.647→25.437, hot23.175→24.006, hot mirror72.285→74.152,
off mirror72.009→95.420. Final p99 dry/cold/hot/hot-mirror/off-mirror:
31.748/26.550/26.283/80.884/111.341ms; maxima52.498/27.921/31.394/84.553/128.075ms.
Dry retains two frames over50ms; every mirror frame remains over50ms. Final
motion callback median/max curtain139.105/141.865ms (24 events), door0.0125/
0.844ms (20), valve medians0.034–0.036ms (27 each). See the full distributions
and **gesture_costs_final.json**. The final off-mirror tail regressed in this
single comparison; no overall speed improvement is claimed and causal isolation
is still needed. The finishing profile introduces only static geometry; its
contribution has not been isolated from the wider world/reflection cost.

Next authorized repair: remove the measured per-motion curtain mesh/tangent/
triangle-collision rebuild while preserving actual targeting, rail travel,
materials and save authority. Broader mirror/rendering costs remain open.


Final **gates_final_frame_clearance**:101 PASS,8 unchanged FAIL,1 INCOMPLETE;
NO REGRESSIONS and requirements_changed empty against the previous checkpoint
board. This is a dirty-checkout development comparison, not a clean merge-base
candidate verification. Reader retains33 unrelated NEW fields against its frozen
baseline; this change adds none. All17 protected path hashes match. Original
shared-manifest contents remain byte-equivalent under canonical JSON after
excluding the six owned additive records; the other two records remain unstaged.
The packet verifier checks41 original receipt log pairs. Named source/docs and
immutable diagnostic packets form the checkpoint; V2 coverage remains partial.
