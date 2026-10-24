# Unchanged fire-service release and commit origins — 2026-10-23

Evidence class: **INERT**. Actual-input and attribution diagnostics, not runtime
qualification, human acceptance or V2 completion.

REPORT - unchanged fire-service release - 2026-10-23

Canonical checkout **C:/PleaseRemainOnTheLine**, branch
**codex/v2-acoustic-topology**, parent **e0ed4eae**. Previous goal turn made
progress: strict-byte validation optimization was committed and pushed. The shared
bathroom-optics manifest records and unrelated street/art work remain preserved.

| Location / reproduction | Severity | Evidence | Repair | Verification |
|---|---|---|---|---|
| F02 hose cabinet, grab then Space without moving the tag | Input stall | Release emits a household-save request; only the running watchman clock changed in the resulting snapshot | Compare this cabinet's own persistent state with its grab bookmark before emitting change | Eleven focused actual-input checks, followed by same world route |
| Consecutive saves in one process frame | Attribution risk | Full stacks show two separate fixture actions, not one click being handled twice | Preserve the stress sequence and original captures; no commit coalescing or scheduling change | Call origins and process/physics frame IDs |
| Large physics-callback spike at completed filling | Attribution gap | Hose completion callback legitimately publishes final water state through household owner | Retain completion saves; identify inclusive save cost in callback | Stack plus nested timing records |
| High aggregate rendering submission counts | Attribution gap | Prior route has32783 draw calls and146457849 primitives median across all passes/viewports | Collect root visible/shadow pass counters before selecting further light tradeoffs | Root CPU/GPU timing and new counter samples; no light change here |

The original release always emits manipulation_changed, even when the grip only
changes input mode. The household owner snapshots651 subjects. Its watchman clock
legitimately advances under the campaign clock; that is meaningful persisted
mechanism state, not removable animation. Fridge/boiler states also advance under
their existing owners. An unchanged cabinet release consequently writes a whole
campaign solely because another owner advanced.

The cabinet now bookmarks its own existing mechanism_snapshot when a grip is
claimed. Release still performs all cleanup, loose-union seating and door-close
scheduling. It emits change only when that cabinet's persistent snapshot differs.
A missing bookmark conservatively retains the old notification behavior. No new
save owner, schema, scheduling, durability policy or global dirty-state cache is
introduced. Real door/valve/nozzle/gasket/placement changes still publish through
the original household owner. Automatic washer settling, completed hose fill/drain,
automatic door closing and maintenance completion retain their direct signals.
Every real save still captures the running clock and other live owners normally.

The optional household profiler records changed IDs and call stacks only when
profiling is enabled; production leaves it disabled. Stack/ID comparison overhead
is measured separately and included in the enclosing commit duration. This is
diagnostic attribution, not an uninstrumented performance proof.

**world_before_v1** completes ten walked waypoints and49 checks, automatic saving
on an owned disposable path, disk/world reconstruction and cleanup with empty
stderr. Fifteen changed commits are recorded. Two unchanged-grip releases save
only the watchman clock. The large paired same-frame commits come from separate
fixture actions: releasing an inspected lever, then releasing the carried nozzle.
An initial conversational interpretation of one double-handled click was wrong;
full stacks preserve the actual two-action sequence. It remains a stress route,
not evidence of duplicate production event dispatch.

The small fixture retains its failures. **unchanged_v1** omits the native riser
reservation, so mounting refuses before interaction. **unchanged_v2/v3** incorrectly
expect exactly one signal while the restored loose washer is still settling;
the retained stack proves a legitimate gasket support notification. **unchanged_v4**
waits for actual stable support before isolating hand assertions, without disabling
physics or collision. All11 checks pass, empty stderr. Actual unchanged click/
release and Space cleanup emit no save request and do not roll back live clock
movement. Actual door motion emits one change and publishes both door and live
clock through the existing owner. A subsequent normal pre-save capture still
publishes later clock advancement.

The fixture's required riser reference is selectively registered after this pass.
Only that28-line record is staged; the two shared bathroom records remain62
unstaged added lines. Original early advisory counts and failed runs are retained.

The final world route additionally measures root visible and shadow pass objects,
primitives and draw calls. Primitives can be points, lines or triangles; totals
must not be called visible triangles. Counter values lag rendering and CPU/GPU
times are not additive to callback wall intervals. API definitions follow
[Godot RenderingServer](https://docs.godotengine.org/en/stable/classes/class_renderingserver.html#class-renderingserver-method-viewport-get-render-info).
An untimed end-of-route light inventory supports the next investigation; it is
not a causal per-light benchmark or a second per-frame target scan.

**world_after_v1** passes the same ten waypoints and49 checks, including real
disk/world reconstruction, empty stderr and owned save cleanup error0. Changed
household commits drop15→13; the two watchman-only releases disappear. All13
cabinet-changing commits remain, including the completed fill signal. Snapshot
calls drop33→28. No normal save transaction is skipped or coalesced.

Frame distributions for725 noncapture intervals in each route:

| Measure | Before | After |
|---|---:|---:|
| p50 |39.544ms|39.632ms|
| p95 |55.784ms|54.532ms|
| p99 |103.001ms|101.933ms|
| Maximum |169.770ms|167.854ms|
| Above100ms |9|8|

Median frame time and the worst stress spike are essentially unchanged. Two
roughly53ms save calls are causally eliminated from unchanged inspection
transitions; these figures do not establish a broad FPS gain. The final observer
adds visible/shadow counters at3us median/17us maximum. Changed-ID/stack profiling
costs594us median/650us maximum before and607us/674us after; it is included in
commit timing and disabled during ordinary production play.

The hose completion commit is52.885ms inside a54.556ms physics-callback bracket
before, and53.520ms inside55.147ms after. The latter leaves1.627ms outside that
commit in the observed callback window. Thus this large callback spike is mostly
synchronous saving, not demonstrated physics-server collision cost. Other movement
spikes still need independent attribution; catch-up physics windows may include
multiple ticks and must not be treated as one expensive solver step.

Root rendering CPU median is22.184→22.155ms, GPU13.465→13.316ms, with lagged
viewport measurements. Visible-pass median is467 objects,1,226,887 primitives,
306 draw calls; shadow-pass median35,264 objects,144,128,374 primitives,33,315
calls. The route-end inventory finds663 lights,159 visible and40 visible with
shadows enabled;35 shadow sources lie at least8m from that final camera. These
are counts and a single-view inventory, not proof that culling a particular light
is visually safe or a causal speed gain. The next measured rendering comparison
should isolate far shadow submissions while retaining nearby/mirror lighting and
color. No rendering setting changes in this checkpoint. Passage residency stays
DORMANT; actual cell streaming remains unmeasured.

Branch / HEAD / origin/main / merge-base: **codex/v2-acoustic-topology** /
**e0ed4eae** / **ad5b3899** / **21f0b1fc**, origin refreshed. Protected17/17: working
content matches the frozen authorities with the authorized selector-only V2 default
cutover and explicit V1 rollback. **protected.json** records an LF-normalized
working-tree check; no clean-candidate qualification is claimed.

Full static comparison against the preceding shared-tree board reports no
regressions:101 PASS,8 FAIL,1 INCOMPLETE,98 tools suites/1194 tests with five
existing failures across four suites. Existing physical-source wrong4, surface
stale2, spatial8 failing/39 advisory, systemic26 review and reader1141 unread/33
NEW findings are unchanged. Ledger240 requirements and blocker counts
7/8/110/42/134/136 are unchanged, requirements_changed empty. The original extra
fixture advisory is retained in early boards; only its executed reference is
registered in the final full board. No broad baseline regeneration occurred.

Worktree clean at end: no. The one28-line manifest record is staged separately;
two shared bathroom records remain62 unstaged lines, and unrelated untracked
street/art/UID files are untouched. Production edits are limited to cabinet
notification and optional household diagnostics; test/capture/report paths support
them. No art, material, light setting, inventory/NPC/case owner or save transaction
changes. No clean merge-base board exists for in-place candidate verification;
no candidate-verifier pass is claimed. **source_checks.json** matches all six
executed top-level test hashes, including failures; dependencies are archived
separately. Wrapper suite_run receipts and test-written INERT diagnostics grant no
schema-2 runtime_contract, space promotion or human acceptance.

Decision needed from owner: none.

BLOCKED broader stutter, cell-transition attribution and full V2 qualification remain open
