# Bounded service-light rendering distance — 2026-10-23

Evidence class: **INERT**. Installed scoped diagnostics, not a runtime contract,
human acceptance or V2 completion.

REPORT - bounded service-light rendering - 2026-10-23

Branch **codex/v2-acoustic-topology**, parent **9b99140a**; canonical checkout
**C:/PleaseRemainOnTheLine**. The owner explicitly authorized culling extra
lights during this batch. Original shared spatial-manifest and untracked
street/tent/traffic/art changes remain preserved. Named staging only.

The sixteen source-owned service practicals now use a bounded rendering
distance in addition to the existing room/door graph. Their light and shadow
contributions fade from4 to8m. Explicit culling at the end avoids shadow-map
submissions that the earlier native-fade controls did not avoid. The original
fixture geometry, emissive lens, light energy/range/color and cube projection
remain. Distant spill and shadows fade sooner: this is the measured visual
tradeoff, not a physically unchanged lighting claim. No electrical, mechanical,
inventory, NPC, case or save authority changes.

The active production camera controls the budget, including inspection. The
single live planar-mirror camera also votes to retain illumination and shadows.
Recent room-cube capture origins retain illumination through their faces and
filtering; these probes already render without shadows, so they do not require
extra shadow maps. Processing follows mirror selection. The fixed sixteen
sources and at most three cached probes require no scene scan or raycast.
Disabling the distance policy restores the affected original light properties and the
existing graph visibility. This remains independently switchable for diagnosis.

| Location / reproduction | Severity | Evidence | Repair | Verification |
|---|---|---|---|---|
| Public F02 landing conservatively retains all sixteen service practicals | High frame cost | Prior service-shadow control: about42ms →22ms with shadows disabled, with bad occlusion | Native4–8m fade plus explicit distance culling | Interleaved original/installed fixed-view controls after five walked waypoints |
| Native shadow/light fading does not avoid composed-world shadow submissions | High ineffective optimization | Earlier8/12/16m fade controls and passing isolated API control | Explicitly cull fully faded sources and unnecessary shadow maps | Draw calls45588 →36949 in the first installed pair |
| A light is far from the player but near a live reflection | High appearance risk | Actual shared planar camera and shadowless room-cube owners | Separate shadow-camera and color-capture votes | Twelve state controls and actual reflected-avatar review |
| Distance changes could churn source flags at rest | Medium script/renderer cost | Stable-view source-state fixture | Write flags only when they change | Sixty repeated ticks produce no extra switches |

At1280x720, VSync disabled, the same fixed real camera records120 measured
frames per phase after twenty warmup frames. Screenshot readback is outside
those samples. The room graph remains active in both treatments; only distance
budgeting changes. All five phases have zero pipeline-counter increments.

| Phase | Wall p50 ms | p95 ms | p99 ms | Maximum ms | Render CPU p50 ms | Render GPU p50 ms |
|---|---:|---:|---:|---:|---:|---:|
| Original A |41.915|46.592|49.529|50.586|24.443|14.538|
| Installed A |35.106|39.506|41.462|42.944|19.961|12.552|
| Restored original B |41.657|47.071|48.620|49.109|24.663|14.429|
| Installed B |34.812|39.431|41.279|43.255|20.112|12.264|
| Restored original C |42.276|48.030|49.703|51.583|24.992|14.640|

The helper costs38 microseconds median,60 maximum in the installed phases;
disabled phases cost28 microseconds median. These are measured call costs in
this world, not all-script profiling. GPU/CPU times overlap and are not additive.
The preceding explicit-visibility candidate tested4/6/8m beginnings with4m
length; the4m candidate produced the clear gain and retained nearby occlusion
in reviewed images. Its initial original phase was slower than later originals,
so the later installed interleaved comparison is the primary timing evidence.

Packet **art/reviews/v2_shadow_visibility_20261023/** retains original
candidate/current inputs, every wrapper receipt, raw per-frame distributions,
counter deltas, source-state controls and original/installed images. The early
candidate fixture is reconstructed minus its later installed-mode additions
and checked against its original wrapper test hash; it is not relabeled as
having executed the final production policy.

The twelve state checks cover graph permission, original-hidden/unshadowed
sources, real camera movement independent of player feet, reflected views,
shadowless cube interests, expiry and exact property restoration. The retained
room/door-graph review explicitly disables the new distance feature to isolate
that older contract:105 checks and the installed sink controls pass. It does
not qualify distance culling at all sixteen source views. The actual mirror
review passes, including new live/sleeping camera assertions and three animated
owner-rig images. Those two review runs retain seven known Texture-RID shutdown
warnings each. Fixed-view and state controls have empty stderr.

The first walked/save run reached all ten waypoints and disk reconstruction,
then failed on a lever-angle JSON difference of1.65e-24 radians. The original
failure remains in **walk_save_v1**. Only the diagnostic comparator now permits
the same1e-12rad round-trip tolerance already used for the wheel; water and
maintenance facts remain exact. Production validation is unchanged. The isolated remote fixture passes, and
**walk_save_v2** completes all ten waypoints and33 checks, including actual
mouse extraction/carry/inspection/valve/lever operation and real disk/world
reconstruction, with empty stderr. Rebuilt pose error is1.067 micrometres; wheel
and lever errors are zero and water/maintenance facts match exactly.

The repeated route has775 noncapture samples: p50/p95/p99/max
38.804/57.046/79.464/729.202ms. The maximum is its first sample across the
startup-to-play boundary, with render counters not yet available. A later spray
sample reaches254.716ms. The prior installed-hose route was
42.692/61.351/82.547/295.426ms, but world randomness, startup and sample counts
differ; this is contextual observation, not a causal paired improvement.
Fixed-view alternating controls above remain the causal rendering comparison.
Hose follow p95 is0.340ms with no cloth/contact solver. Pipeline monitors change
during the route; monitor lag and a reset prevent assigning each long frame to
compilation, scripts, physics or streaming from these samples alone. The source
light change does not resolve these spikes. Both original and repeated raw
frames and the original save failure remain preserved.

Reviewed mirror images retain the previously documented head cropping, grain
and bright sconce limitations. Animated visibility is not appearance acceptance. Reviewed hose captures also
show an obtrusive foreground hose loop and poor nozzle framing at the cabinet.
Passing aim-axis and ownership assertions do not qualify that composition;
repair it with released-nozzle support in the next hose batch.

The new feature still needs broader corridor/window/reflection appearance
coverage and controlled transition sampling. The full-area surface/runtime
ledger, native book/nook closure, shower effects, maintenance input, released
nozzle support, full payout, device/street/shops/avatar work remain open. No
partial route or wrapper receipt promotes those requirements. All receipts here
are suite_run or INERT diagnostics, not schema-2 runtime_contract evidence.

Branch/parent/origin/main/merge-base: **codex/v2-acoustic-topology** /
**9b99140a** / **ad5b3899** / **21f0b1fc**. End tree remains dirty: two shared
bathroom-optics manifest records and unrelated untracked street/art/UID files.
Protected17/17 content is preserved, with the authorized default-selector
cutover; selectorV2 and explicitV1 rollback remain. This shared-tree checkpoint
has no clean merge-base candidate-verifier qualification.

The full board records101PASS/8FAIL/1INCOMPLETE;98 tools suites run1194 tests,
with five existing failures across four suites. Original full-board exit1
reports six spatial fingerprint changes after assertions shift existing test
lines. Only those six successfully executed mirror/room-graph bindings are
registered. A focused spatial/test rerun retains existing failures, with eight
failing and39 advisory records. The derived board replaces only those two
executed gate rows, retains both originals, and finds no new regression against
the previous shared-tree board. It is not a clean-main comparison.
Completeness exits2 with blockers7/8/110/42/134/136 unchanged; no requirement
status changes. Physical imports exit1 with four unrelated wrong inputs;
surface qualification exits1 with two stale packets; reader exits1 with33NEW
unrelated fields. Systemic/period/carriers/rulings and the other94 tools suites
pass. Existing failed suites are interaction implementors, prompt carriers,
spatial dependencies and completeness. Raw exits/defects remain in **gates/**
and **spatial_recheck/**, with explicit provenance in **current_gates_derived.json**.
No full board or runtime suite was repeated for reporting alone.

Changes outside lighting are diagnostic save-angle comparison, test references,
source archives and continuation/reporting. No native stock, material, door,
reticle or interaction authority changes are included. Original failures and
Texture-RID warnings remain retained, not rewritten into passes.

Decision needed from owner: none.

BLOCKED broader performance and full runtime/surface/human qualification remain incomplete
