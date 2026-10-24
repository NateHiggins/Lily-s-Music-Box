# Service lighting and remaining bathroom submission cost

Evidence class: **INERT**. Diagnostic and scoped repair record, not acceptance.

REPORT - service-light-visibility - 2026-10-23

Branch **codex/v2-acoustic-topology**, parent **64ce1fa3**, canonical checkout
**C:/PleaseRemainOnTheLine**. Shared spatial-manifest WIP and untracked
street/tent/traffic work remain outside this repair. No ledger promotion,
clean candidate verification or whole-V2 completion is claimed.
Origin/main **ad5b3899d532d2d0d7f0aecc7b344e5957040141**; merge-base
**21f0b1fc27ac8e25c8466fe1ed2ce64019ee7ede**. All engine logs and wrapper receipts
live in the packet below; static tool exit codes are retained in its gate board.

## Measured cause

The preceding contact reduction leaves severe rendering cost. The new packet
**art/reviews/v2_bath_render_cost_20261023/** separates fixed-view rendering
controls from actual movement. 1280x720 Forward+, VSync off, uncapped, 60 Hz
physics; carried device/lamp hidden, room-probe streaming held stable. Every
static phase has 120 rendered frames, with the first incomplete wall sample
excluded; treatment warm-up remains in the raw packet. Movement uses the same
240-tick A/D and paired-turn programme. Static cameras are checked unchanged.
Process/physics/render monitors overlap and lag; do not sum them. In particular,
the frozen mirror reports stale last-render timestamps, not ongoing work.

**control_v1/** completes in 197 seconds. Normal static wall p 50/p 95/p 99/max
46.790/55.804/57.979/58.710 ms, restored 47.470/57.051/58.167/59.027.
Main shadow submissions are about 44,265 per frame and mirror 10,396, versus
792 main visible draws and 214 mirror draws. A diagnostic disabling every shadow
reduces median to 6.372 ms but washes out the room, so it is rejected. Frozen
mirror median 37.958 and frozen light scripts 43.789 only partly reduce cost.
SSAO/SSIL and 4x MSAA controls provide no useful win. Production retains 8x MSAA
(enum 3), despite an older project comment saying 4x. No quality setting is changed.

The **fog_off** diagnostic is not an isolated persistent fog control: the
DayNightDirector writes its depth-fog enable back, and the lamp-owned volumetric
pass is already off with the lamp switched off. Do not infer fog is free or
disable production fog from that result. This source-owner conflict remains
explicit rather than interpreting an ineffective control as evidence.

**budgets_v1/** completes in 216 seconds. Regular fixture shadow budgets 32/16/8/4
give static medians 47.133/48.214/44.921/43.161 ms. The 32-to-16 control leaves
approximately 44,200 shadow draws: changing the ordinary rig misses most cost.
Two casters visibly change the room. Budget reductions and mirror/celestial
shadow removal are not installed.

The light inventory finds 663 light nodes and 53 visible positive-energy shadow
casters:32 controlled by the ordinary rig and 21 outside it. Sixteen source-owned
service-opening practicals are among the unmanaged casters. **service_v1/**
completes in 193 seconds: disabling only their shadows reduces fixed-view median
46.888 to 24.837 ms and main shadow submissions 44,145 to 14,645. Source lights
fully off give 24.847 ms; same-floor-only service lights 38.115 ms. These controls
do not authorize deleting those sources or their shadows globally.

**projection_v1/** completes in 189 seconds. A faster service-only shadow mode
reduces fixed-view median 45.969 to 37.748 ms; all omnidirectional lights using it
give 30.620 ms. Door-edge occlusion changes and the broad version distorts wall
shadows, so neither is installed. Godot documents the speed/quality distinction
in its [OmniLight3D reference](https://docs.godotengine.org/en/stable/classes/class_omnilight3d.html).

## Repair

The existing world room lookup and opening/door records drive a presentation
client for those 16 service lights. Closed opaque leaves separate components;
open passages and actual open leaves connect them. A source contributes while
one of its adjoining spaces is connected to the current room. Visible fixture
geometry and emissive lenses remain. Original light energy, range, color, cube
shadow mode and regular fixture budget remain. No collision query, target scan,
new light, new camera, texture, geometry or electrical fact is introduced.

Transparent materials, cutouts, unknown shaders and unknown leaf implementations
are treated as transmitting. Unknown camera rooms and connected open/core
volumes retain every original source conservatively. Reads use cached original
door owners; hand movement invalidates the component immediately, with bounded
polling for other owner changes. Household restoration remains authoritative;
the client mounts after it and serializes no parallel door or light state.

The first **connected_v1/** candidate completes in 172 seconds. Fixed-view
p 50/p 95/p 99/max 46.216/52.570/54.653/60.536 ->
24.807/32.886/34.441/37.262 ms; restored 48.517/56.424/59.069/60.460.
Main render CPU 22.392 ->8.623 ms, shadow draws 44,067 ->14,564. The fixed camera
does not move. Actual-input medians 55.393 ->28.810 ms, restored 64.085; p 95
100.686 ->54.025, restored 102.911. Moving endpoints differ, so those moving
wall/GPU deltas are not an identical-view isolated comparison. Raw distributions
and warm-up spikes remain. Disabled-policy debug context fields retain their
last value; they do not mean the original source lights were disabled.

## Issue log and verification boundary

| Location | Reproduction / severity | Evidence | Repair | Verification |
|---|---|---|---|---|
| Closed 3B bath | Static view and actual movement; high submission cost | Four causal controls identify unmanaged service-source shadows | Reuse authoritative room/leaf connectivity for service-light presentation | Fixed-camera candidate comparison; installed owner review recorded separately |
| General shadow budget | Lower 32 to 16; misleading presumed cause | Shadow submissions stay about 44k | Reject broad quality reduction | Original/restored settings retained |
| Faster omni projection | Service-only and broad alternative | Changed door-edge occlusion; distorted broad wall shadows | Reject both variants | Original and candidate images inspected |
| Fog control | Disable environment flags | Director restores depth fog; volumetric pass already inactive | Mark control limited; retain production weather/air owners | No fog performance/quality claim |

All engine invocations use shared-lane wrappers, with original raw logs and
**suite_run** receipts retained. These diagnostics are not test-written schema-2
runtime contracts. Frame-time improvement does not grant human appearance or
interaction acceptance. Remaining work includes open/public-volume performance,
cross-court glazing coverage, longer walked routes and the full started-work
closure queue. No V2-complete claim.

## Installed review and gate board

**installed_v1.log.receipt.json** records a completed 222-second run with
**SERVICE LIGHT VISIBILITY REVIEW: PASS**,105 checks. All 16 original openings
have paired unchanged-camera images; each retains its own connected source,
original 3.2 energy /4.8 m reach and cube shadows. Four annotated contact sheets
were inspected, together with the bathroom alternatives. Unknown/outside context
retains all 16 sources. Pure visibility polling leaves durable gameplay bytes
unchanged. Actual primary-grab / mouse-motion / second-click door opening
restores connected sources, and actual closing restores the isolated set.
Seventeen further installed sink checks pass. These are direct placements with
capsule-volume clearance, not walked approaches or ground-support qualification.
The seven pre-existing Texture RID shutdown warnings remain; no clean teardown
claim is made. The wrapper receipt and this INERT review are not runtime_contract.

The full **gates/board.json** has 101 PASS /8 FAIL /1 INCOMPLETE. All 98 tools
suites ran 1,194 tests, with the same five failures across four suites as the
historical complete tools snapshot. Systemic, period, carriers, rulings, mesh
UV imports, recipe projections and surface imports pass. Reader retains 33 NEW
untracked street/tent findings; physical import retention retains four untracked
street/traffic model/settings findings. Spatial retains eight failing identities,
with 45 reported findings versus 21 in the older scoped snapshot; the extra 24
diagnostic references are recorded, not blanket-rebaselined in shared WIP.
Surface/rendered qualification remains stale. Ledger blockers by scope are
7 /42 /110 /8 /134 /136, in board order. Ledger status changes versus a clean
merge-base were not measured; INERT report promotions: [].

**scoped_board_comparison.json** compares common static gates and the 98 tools
suites against separate historical dirty snapshots. It is informational, not
a clean merge-base baseline or candidate verifier. The first naive comparison
used a tools-only reference and misleadingly listed static gates as new; its
original output is preserved and explicitly rejected for that purpose.
All 17 protected paths are unchanged after LF normalization against the parent;
selector V2 and explicit V 1 rollback remain. Worktree is not clean: shared
spatial manifest and unrelated untracked art remain. No merge certificate.

The diagnostic entry script evolved between controls; final source snapshots
and original receipt hashes are retained separately. Earlier diagnostics are
not retrospectively rebound or promoted into current runtime qualification.

Decision needed from owner: none; continue verified existing-scope work.

BLOCKED full runtime/surface/human qualification remains incomplete
