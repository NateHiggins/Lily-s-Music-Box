# Strict save-byte validation cost — 2026-10-23

Evidence class: **INERT**. Component and actual-route diagnostics, not runtime
qualification, human acceptance or V2 completion.

REPORT - synchronous save-byte validation - 2026-10-23

Canonical checkout **C:/PleaseRemainOnTheLine**, branch
**codex/v2-acoustic-topology**, parent **9eabb02c**. Previous goal turn made
progress: guarded household validation reuse was committed and pushed. Shared
bathroom-optics manifest work (62 added lines) and unrelated untracked files
remain preserved. Godot lane was free; no other process was stopped.

| Location / reproduction | Severity | Evidence | Repair | Verification |
|---|---|---|---|---|
| Actual hose controls with automatic saving | Input stalls | Prior final route has 208.690ms maximum, including 134.370ms household work across consecutive synchronous saves | Diagnose remaining serialization, validation and file operations separately | Same ten-waypoint route, automatic writes on owned disposable path |
| Storage validates every byte in GDScript before JSON conversion | Candidate CPU cost | Original 180KB ASCII validation about5.7ms | Candidate native search skips ASCII spans; original strict validator checks complete non-ASCII runs | 71,894 independent Python strict UTF-8 comparisons; occupied-world component controls pending |
| Malformed UTF-8 must not become replacement characters in a save | High authority risk | Existing recovery tests protect original corrupt bytes | Retain strict validation and fail-closed fallback, including embedded NUL and dense Unicode | Exhaustive two-byte inputs, boundary, malformed, NUL and deterministic random cases |

The diagnostic candidate maps bytes to Latin-1 solely to locate non-ASCII spans.
It never treats that map as decoded save content. UTF-8 multibyte sequences cannot
cross an ASCII byte, so each complete contiguous non-ASCII run can use the
original strict validator. Embedded-NUL length mismatch and more than64 runs
fall back to the original whole-buffer validator. JSON conversion, schema
validation, verified temporary/backup/journal writes, readbacks, promotion,
rollback and recovery ownership remain unchanged in this candidate.

Godot documents the native conversion as one character per byte:
[PackedByteArray.get_string_from_ascii](https://docs.godotengine.org/en/4.3/classes/class_packedbytearray.html#class-packedbytearray-method-get-string-from-ascii).
The actual installed engine is4.7.1; behavior is exercised by the diagnostic rather
than inferred solely from documentation. Native regex search is a byte-span
locator, not a replacement UTF-8 or JSON parser.

**utf8_probe_v1** passes71,894 comparisons with empty stderr. Python strict UTF-8
provides the independent expected results, including every65,536 two-byte input.
Alternating original/candidate/original/candidate median costs for180KB ASCII
are5.769/.149/5.725/.130ms; sparse Unicode180,013bytes gives
5.683/.133/5.473/.138ms. Dense260KB Unicode falls back,13.985/14.141/14.404/14.279ms.
Embedded-NUL180KB also falls back,5.446/5.201/5.102/5.176ms. These are component
controls, not player-frame improvements. Production code remains unchanged at
this first diagnostic boundary.

The occupied-world probe uses the same actual hose route and normal automatic
save authority. After active timing ends, it captures the real campaign snapshot
and alternates real verified storage writes with the original versus candidate
validator in a test-only subclass. Stage timings nest and are not additive.
Serialization controls separately compare existing pretty output with compact
output. No serialization-format change is made in this diagnostic.
Original inputs and all receipts remain under
**art/reviews/v2_save_stages_20261023/**.

**world_probe_v1** captures272,367bytes. Interleaved original/candidate/original/
candidate real storage-write medians are44.109/27.469/41.498/27.056ms (six writes
each); strict-byte-check medians7.773/.594/7.726/.563ms, twelve checks per phase.
Candidate JSON-decode medians4.792/4.668ms include byte checks and schema validation.
Temporary and backup readbacks each cost roughly4–5ms in these controls and remain
intact. Compact serialization reduces bytes to163,282 but only saves about.47ms
in serialization itself, so that format is retained unchanged. These component
controls happen after active route timing, use identical snapshot bytes, and do
not change the production RealityState commit owner. Component value reload and
all four phase checks pass; full world reconstruction also passes (ten walked waypoints,53 checks, empty stderr).

The unchanged-production baseline route observes p50/p95/p99/max
38.837/53.538/112.048/196.994ms,733 noncapture intervals,13 above100ms. Its largest
charge-input interval contains133.198ms household work across synchronous commits.
Rendering submission and physics callback spikes also remain; this storage repair
cannot claim to eliminate them or measure dormant passage streaming.

The installed production version retains the original full-buffer validator as
its fallback. The native span search is limited to buffers at most1MiB; larger
buffers keep their previous acceptance and validation path. This bounds temporary
Latin-1 allocation and native search work without imposing a file-size limit.
The diagnostic now explicitly calls original full-buffer validation for its
control phases, and actual production validation for its candidate phases.
**source_probe.json** preserves the earlier prototype; **source_installed.json**
binds the installed version. No executed originals are relabeled or overwritten.

**utf8_installed_v1** passes77,970 comparisons, adding valid multibyte strings,
three/four-byte boundary mutations,63/64/65/128-run controls, and1MiB boundary
cases including malformed trailing bytes and embedded NUL. **recovery_installed_v1**
passes195/195 existing recovery checks, including exact corrupt-byte preservation,
future-version refusals, failed writes/promotion, backup recovery and explicit New.
Both have empty stderr. Early reader/spatial/systemic counts and named findings
match the preceding shared-tree board. The final installed actual route passes53/53 checks and all ten walked waypoints,
with empty stderr and successful disk/world reconstruction. Physical pose error
is at most1.067um, rotation errors zero, all other water/maintenance facts equal.
Automatic save and component storage artifacts both clean up their owned primary
and backup with error0; no player save is used. Full static comparison completes without regression.

The installed component repeat uses272,371 identical bytes within each phase.
Original/installed/original/installed verified-write medians are
42.355/27.985/41.310/28.288ms, six writes per phase. Corresponding byte checks
are7.660/.632/7.685/.630ms. The roughly13–14ms write reduction is reproduced
without skipping any file operation. The prototype and installed snapshots differ
by four bytes of normal world state; the alternating comparisons always use one
fixed snapshot within their own run.

Both routes use the same ten walked waypoints, actual click/motion/release,
turning, deployed carry, free-cursor inspection and separate charge/spray controls,
1280x720 Forward+ with VSync disabled. Automatic saves are enabled during play on
owned disposable paths. Baseline/installed post-render intervals:

| Measure | Baseline | Installed |
|---|---:|---:|
| Samples |733|742|
| p50 |38.837ms|39.133ms|
| p95 |53.538ms|53.759ms|
| p99 |112.048ms|98.583ms|
| Maximum |196.994ms|179.988ms|
| Above100ms |13|8|
| Household commit median, inclusive |66.819ms|51.932ms|

Median/p95 frame times are essentially unchanged. The route tail improves in this
pair, but frame counts, ambient actors and physics scheduling vary; do not infer
that the local CPU saving accounts for every tail difference. Interleaved writes
of fixed bytes provide stronger causal evidence. Actual normal commit controls
with household validation reuse give55.193/56.271ms before and39.981/39.449ms after;
original-order household controls remain separate,68.790/69.940ms before and
53.584/54.122ms after. Those controls occur outside the active route trace.
The largest installed charge-input interval still includes114.662ms household
work across consecutive commits. Physics callbacks peak53.814ms and render
submission73.989ms; neither is eliminated or interpreted as exclusive GPU time.
Passage residency stays DORMANT. Cell streaming remains unmeasured.

Branch / HEAD / origin/main / merge-base: **codex/v2-acoustic-topology** /
**9eabb02c** / **ad5b3899** / **21f0b1fc**, origin refreshed. Worktree clean at end:
no; shared bathroom-optics manifest records remain62 added lines and unrelated
untracked street/art/UID work is untouched. No worktree was created, other process
closed, or art/rendering input changed. The only production edit is strict-byte
validation in the existing storage owner; diagnostics and reports are supporting
paths outside that boundary.

Protected17/17: working-tree invariant content with the authorized selector-only
V2 default cutover and explicit V1 rollback. **protected.json** is an LF-normalized
working-tree check, not clean-candidate qualification. The full board has101 PASS,
8 FAIL,1 INCOMPLETE;98 tools suites run1194 tests with five existing failures in
four suites. Existing physical-source wrong4, surface stale2, spatial8 failing/39
advisory, systemic26 reviews and reader1141 unread/33 NEW findings are unchanged.
Ledger240 requirements and blocker counts7/8/110/42/134/136 are unchanged;
requirements_changed empty. The comparison uses the previous explicit combined
shared-tree board (original full outputs plus its focused formatting recheck).
No clean merge-base board is available for in-place candidate verification; no
candidate-verifier pass is claimed. Source archives bind every executed variant;
**validation_equivalence.json** confirms the fallback body exactly matches its
parent. All original wrappers, test-written diagnostics and stage distributions
are retained. Wrapper suite_run receipts and INERT diagnostics grant no schema-2
runtime_contract or human acceptance. Visual review of the installed borrowed
nozzle view shows the retained scene; no visual optimization is claimed here.

Decision needed from owner: none.

BLOCKED complete rendering/script/physics/loading attribution and broad V2 qualification remain open
