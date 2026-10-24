# V2 responsiveness and interaction repair

Evidence class: **INERT**. Issue log and measured diagnostics. No ledger
promotion, whole-building completion or human acceptance follows from this report.
The separately test-written first-slice contract carries its stated runtime scope.

Work starts from **21f0b1fc** in the canonical checkout on
**codex/v2-acoustic-topology**. Tracked sources were clean; existing untracked
review artifacts remain untouched. The shared lane was free. Every Godot launch
used the shared-lane wrappers, with original failures and receipts preserved.

| Location / severity | Reproduction and evidence | Repair and verification |
| --- | --- | --- |
| Lobby, entrance, passage reload / high | Two matching played lobby/street/return cycles. Before: 801 samples, 16 waypoints, zero failures; largest frame 1,093 ms, fitting chunk 1,024 ms. Threaded-result fetch and source instantiation were small; native collision construction was expensive. | Native asset prefetch, conservative triangle indexing, bounded immutable collision reuse and cooperative fitting. Final: 821 samples, 16 waypoints, zero failures; largest frame 276 ms, fitting chunk 213 ms; zero retired scene/mesh survivors. The 3 ms scheduling budget cannot preempt an individual fitting call. |
| Native collision and triangle fitting / high | Repeated native collision construction and invariant transforms/bounds on every reload. | Cache 1,269 immutable passive collision resources: 84.5 MiB face data plus engine overhead, under a 96 MiB face-data cap. No scene or imported mesh cache survives retirement. Source-geometry hashes, exact shape identity, mutation invalidation and wrong-shape refusal preserve protection. The cache releases with its world. Fifty-six safety checks pass. All 279 shipping-draw comparisons preserve exact serialized buffers and removal counts against the frozen original selector; isolated aggregate selection time is 313 -> 68 ms. |
| Targeting and hand feedback / medium | Basic square dot lacked blocked/limit/inspection feedback; hover duplicated a legacy-prompt ray and scanned other parts while grabbed. Controller look could precede the action but follow the displayed target. | Restrained keylined ring, warm latched-hand ring, blocked cross, travel-stop bars and inspection-capability arc. Feedback uses the authoritative part and accepted constraint readback; inspection follows the free cursor. One hover resolver; no hover scan while grabbed or locked. Resolve after controller look, actions and eye-height changes. Fifty-four windowed actual-input checks pass, including independent parts, stops, lock refusal and inspection restoration. |
| Static interior visibility / medium | Stationary controls find substantial cost outside the main viewport. Earlier V1 facade occluders caused missing bands and glazing. | Admit only complete solid interior wall boxes; inset volumes 6 mm on each side and exempt their source walls from culling. Exclude facades, apertures, cut skins and moving parts. All five same-frame paired images are pixel-identical. Upper-landing viewport CPU median 27.3 -> 20.4 ms; street 31.7 -> 26.2 ms. Main-view culling is installed; the lamp shadow viewport remains unchanged. |
| Eleven arcade shop leaves / high, OPEN | Original leaf collision bottoms and passage terrazzo both lie at 10 mm; the 1 mm query margin rejects zero clearance. The new proposed fit raises the lower bound 6 mm without changing the upper bearing, sampling every 2 degrees. All sampled poses through 92 degrees are clear; first sampled contact is at 94 degrees. | No production leaf was changed. Still author native clearance and fitted stops, verify every moving stock sweep and actual hand travel, then save/reconstruction. No floor exclusion or obstruction bypass. Original discovery is retained under **art/reviews/v2_upper_access_20261021/passage_door_discovery/**; the new diagnostic is **shop_clearance_survey/**. |
| Mina's upper bookshelf / observation | Original casting-off/restored comparison diagnoses the raised black silhouette as a cast shadow. | No mesh removal or shadow suppression. Retain **design/V2_UPPER_ACCESS_AND_LIBRARY_SHADOW_2026-10-21.md** and its original evidence. |

The packet is **art/reviews/v2_responsiveness_20261021/**. It retains raw frame
samples, phase distributions, route traces, captures, original logs, failed
experiments and wrapper receipts. Compressed logs reproduce original bytes;
**raw_log_manifest.json** records their hashes. Performance is measured in the
production V2 world with its live controller and authorities, Forward+ on the
RTX 4080, 1280 x 720, VSync off, uncapped frames, unchanged renderer quality and
the same initial November campaign setup. Startup is separate from gameplay.
The initial board overlapped part of the first baseline cycle; the repeated
second cycle is the cleaner comparison. No static gates ran during final
performance sampling.

| Complete repeated route, milliseconds | Before | Final |
| --- | ---: | ---: |
| p50 | 71.3 | 72.5 |
| p95 | 104.3 | 107.1 |
| p99 | 547.4 | 148.6 |
| Maximum | 1,093.2 | 275.8 |
| Frames over 100 ms / samples | 47 / 801 | 57 / 821 |

The longest stalls improve substantially; median and p95 do not. Scheduling
spreads remaining atomic work across more frames. Some return/idle measurements
regress, and sustained responsiveness remains poor. This is not a blanket FPS
improvement. The second lobby-turn cycle's p50/p99 changes from 76.5/123.3 to
72.3/90.4 ms. Its second street-turn p99 falls from 594.4 to 150.7 ms, while the
return leg p99 worsens from 131.3 to 228.7 ms. Whole-route values and all phase
rows remain in **performance_comparison.json** and the raw summaries.

Stationary frozen-world controls separate ticking from rendering: final median
wall time is 85.3 ms live, 57.5 ms with world ticking disabled, and 30.3 ms with
both world ticking and the lamp's separate shadow viewport disabled. Those
controls are diagnostics only; production retains the shadow viewport. Main
viewport CPU/GPU timers exclude other views and some engine work. TIME_PROCESS
is not a script profiler, and monitor samples can lag the triggering frame.
Threaded-result retrieval is not total disk loading time. No exact shader
compilation or input-to-photon latency claim follows. Measured constrained-motion
owner callbacks peak below 0.3 ms on the played route; release callbacks reach
17.3 ms. Lighting, atmosphere, visual stock and physical obstruction protection
remain; NPC, case, inventory and save authorities are preserved.

The separate first-slice contract passes 360 printed checks, with 359 serialized
before its final output check. It covers seven stated authorities, real service
travel, physical controls, ordered workshop delivery, disk save, CampaignShell
reconstruction and teardown. Its original schema-2 contract is
**first_slice/runtime_authority_receipt.json**. The existing independent verifier
passes current runtime/physical bindings and byte-matched compressed original
logs. The fresh packet is also published at the existing canonical first-slice
path; its prior original packet is preserved under **previous_first_slice_packet/**.
These are scoped runtime results; captures and wrapper receipts grant no
runtime qualification. Save in this run measured 50.7 ms. Seven existing Texture
RID shutdown warnings remain. The isolated Dream material test passes 50 checks
and retains its existing Juno texture-UID fallback; no UID was changed.

Coverage includes the played lobby/entrance/street route, the first-slice service
and workshop legs and patrol stations, isolated inspection/lock handling, and
five static paired views: lobby, street, upper landing, Mina's room and an upper
stair landing labelled roof by the fixture. That last image does not qualify roof
coverage.
Detailed furnishing approaches, full-world inspection performance, every shop,
other room/roof/basement programmes, comprehensive save scenarios, UV/PBR/mipmap
renewal, glass/lighting polish and human visual/listening acceptance remain.
Existing source-bound receipts retain only their original scope and may expire
when their inputs change. No whole-V2 completion or V1 retirement is claimed.

Original failed compilation, timeout, cache and survey runs remain. Two
parse-only wrapper-zero runs have dependency errors without autoload context;
they are not passing checks. An abandoned disk cache still reinitialized shapes
and was replaced by the bounded live collision cache; its source and failed
teardown diagnostic remain. Three isolated fitting failures lack predecessor
fittings; composed execution passes the original predicates. No failed result
was repinned or promoted. The native, UV and material assets were not rebuilt.

REPORT - V2-RESPONSIVENESS - 2026-10-21

Branch / starting HEAD / origin/main / merge-base: **codex/v2-acoustic-topology** /
**21f0b1fc** / **69235f4f** / **69235f4f**.
Worktree at checkpoint: all tracked changes are included in the named-path commit;
unrelated untracked artifacts remain. No other contributor work was staged.
Protected 17/17 and selector V2: PASS against the current merge-base, with no
working-tree edits to those paths. See **protected_verification.json**. A final
fetch finds **origin/main** at **21f0b1fc**; no integration is performed.
Ledger before -> after: **0 / 1 / 56 / 26 / 73 / 75** -> **0 / 1 / 110 / 35 / 127 / 129**;
this INERT report grants no requirement statuses.
Gates: starting board **109 PASS / 1 INCOMPLETE**, zero failing tools suites,
reader zero NEW unread fields. Final board: **107 PASS / 2 FAIL / 1 INCOMPLETE**.
The comparison is REGRESSED: broad surface qualification has two expired-proof
defects, and the completeness smoke has one stale played-cohort failure. Rendering
source changes expire 54 spatial promotions and nine runtime blocker slots; no
claim is made that this is mere report noise. Fresh first-slice proof renews only
its seven-authority scope. Reader remains at zero NEW; spatial has zero new failing
references and its four pre-existing incidental references. Original failed and
final boards are both retained. This is an observed canonical-checkout baseline,
not a clean merge-base candidate-verifier receipt.
Changes outside expected boundary: ten narrowly reviewed spatial-manifest rows
register the occluder name template and diagnostic fixture references. Existing
rows and audit rules remain unchanged. The canonical first-slice packet is renewed
from the actual test-written receipt, with the old bytes preserved. Diagnostic
fixtures and retained experiments support the performance and input repairs.
Open findings: residual slow rendering/ticking, atomic fitting stalls, shop-door
repair and the coverage listed above.
Decision needed from owner: **none at this stage**.

BLOCKED FROM MAIN INTEGRATION: source-current broad qualification and existing V2 blockers remain.
