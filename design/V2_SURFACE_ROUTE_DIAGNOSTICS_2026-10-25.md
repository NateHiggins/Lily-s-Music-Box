# Surface-route diagnostics and maintained controls

Evidence class: **INERT**. Development checkpoint and issue log. Full surface
qualification and V2 completion remain unproven. A scoped test-written fire
contract is retained unchanged; it grants only its explicitly executed scope.

REPORT - V2-SURFACE-ROUTE-DIAGNOSTICS - 2026-10-25

Branch: **codex/v2-surface-route-repair-20261025**. Source HEAD/main/merge-base:
**3fcd7fc2**. All production scripts, scenes, assets and gameplay data are unchanged.
Protected17/17 PASS against main. Selector V2 with explicit V1 rollback.
Worktree clean at end: no; generated UID metadata remains untracked.
Ledger: no promotion requested; full board comparison is pending.
This checkpoint is preserved before the owner's PR42 companion integration.

| Location / reproduction | Severity and evidence | Repair | Verification |
|---|---|---|---|
| Entrance route driver | Old projected hinge motion stalls the production fixed horizontal gesture | Use the actual grabbed descriptor's declared axis, range and pixel travel; retain geometric fallback | **street_v1** opens the real entrance and reaches the opposite pavement; its return still fails against the slow-closed leaf |
| Street return | Controller walks into a leaf that closed during crossing | Reacquire and open it from outside through actual input before walking in | **street_v2** fails earlier at the passage loading barrier; corrected return remains unqualified |
| Passage reconstruction | Real access delay; **street_v2** fails at its physical loading barrier | Not repaired in this checkpoint; barrier preserved | Controlled **streaming_baseline_v2** completes the first round trip; second approach is late, eventually loads. Failed verdict retained |
| Fire survey child cast | Full inventory aborts when a player-contact body is cast to CollisionShape3D | Enumerate actual direct shape children only | **fire_only_v3**:2,171 checks, zero failures, empty stderr. Test-written schema2 fire contract PASS with1,638 checks and zero retained owned nodes |
| Restored-front movement predicate | Exact mask1 rejects the player's existing supplemental contact layers even at reached targets | Require exact1-or-native-layer mask, live physics and the original position tolerances; record observed and expected masks | Static cause confirmed; full front programme remains unverified |
| Wet-room survey |703 claimed skirting gaps, all19 wet rooms at70mm; retired wall metadata also undercounts tile | Pending replacement with actual tile/grout/edging coverage at installed heights; do not exempt wet rooms | Independent census retained; current finish intentionally replaces wooden skirting with3mm grout |
| Glass and beacon stock |62 tinted-glass draws lack diffuse maps; one physical beacon lacks PBR | Pending physical recipe repair, no exemption | Original failed surface contract and complete compressed inventory retained |

## Measurements

Controlled streaming:1280x720 Forward+, VSync off, unlimited FPS,8x MSAA,
TAA, scale1, seed1928; frozen10 November1928 at20:00, network weather off.
Actual observed settings and clock are written by the fixture. Initial world
construction is separate from the played route. Render/GPU/process/physics
monitors overlap and can lag; they must not be added or treated as complete
per-frame script attribution.

The2,290 playable intervals have median24.7685ms, p9542.4673ms,
p9957.66798ms, max893.663ms and nine over100ms. The maximum is the first
sampling interval; keep that initial boundary visible. The282.335ms PNG-adjacent
interval is separately retained and excluded from playable distributions.
Reconstruction lasts11.472969s and11.908858s. Peak fitting step50.489ms;
carboys50.482ms and dispensary44.648ms remain synchronous. Reported GPU max
15.253ms does not explain the largest wall intervals. Compilation counters
increase during several spikes, without proving complete driver attribution.

The paired short entrance-area carrier probes each pass18 checks with empty
stderr. Original:1,369 playable intervals, median33.812ms, p9539.231ms,
p9944.9718ms, max5,680.953ms. Companion:1,509 intervals, median30.553ms,
p9535.3806ms, p9940.6758ms, max5,584.776ms. This single ordered pair is not
a speedup claim: the driver cache is uncontrolled and construction differs.
Both have a major first-render stall. Companion motion callback max286us and
mechanism max229us; inclusive nested timings are not additive.8x/4x/8x control
provides no repeatable reason to reduce quality, so production settings stay.
No input-to-display latency, exhaustive world coverage or performance acceptance.

## Evidence, failures and remaining work

Packet: **art/reviews/v2_surface_route_diagnostics_20261025/**. Manifest hashes
raw wrapper receipts, exact gzip logs, original failed full-surface contract and
inventory, current scoped fire contract, source snapshots, timings and reviewed
captures. Five fire renders were viewed individually;13 route/carrier captures
were reviewed in the contact sheet. Visual defects and failed route captures
are not acceptance images.

Streaming v1 was interrupted after a cancellation race: the queued process
started before cancellation, the guard failed, and a subsequent shell statement
still stopped the owned broker. Source then changed mid-run. Only the verified
owned engine was subsequently stopped. Its raw logs, old source and annotation
remain; there is no wrapper receipt and it is never a usable baseline. The
controlled v2 completed with its genuine readiness failure. No other process
was stopped.

Fire contract scope: all eight installed stations, actual doors/valves/nozzle/
washer input, exact restored mechanisms and owned teardown. It excludes hose
refolding/deployment, certification, water flow, capacity and statutory proof.
The2,171 aggregate checks include helper controls beyond the1,638 contract
checks. This does not qualify the full surface inventory or the whole hose task.

Gates: diff check clean; reader zero NEW before the final fixture metadata
addition. Full current-main static baseline is being captured; candidate gates
and management verification have not been completed. No claim of merge readiness.
No inventory, work-order, NPC, relationship, case, save or quest authority changed.
Open: measured passage readiness/stalls; original first-render stall; wet-room
coverage renewal; bar hull comparison after later cafe-chair retirement; tinted
glass/beacon recipes; full surface qualification and broader started V2 work.
Owner decision needed: none.

BLOCKED - full surface qualification and candidate verification remain open;
this is a preserved development checkpoint, not a release or completion claim.
