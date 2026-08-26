# Orison capture evidence protocol

Status: canonical protocol for new screenshot suites. Existing suites migrate
when touched; do not churn hundreds of historical shot scenes at once.

This protocol has two goals that must remain separate:

1. get complete, attractive, inspectable images inside the single 60-second
   Godot lane;
2. prove visual claims quantitatively without pretending that two photographs
   are the same merely because their game variables are equal.

## The one capture command

Use the wrapper. Never invoke Godot directly, never start a second instance,
never retry in a loop, and never point a new run at a non-empty directory.

```powershell
pwsh -NoProfile -File tools/run_godot_capture.ps1 `
  -Scene res://tests/ExampleShot.tscn `
  -ShotRoot C:/PleaseRemainOnTheLine/art/renders/example_task `
  -RunName production_01 `
  -ExpectedFrames 8 `
  -TimeoutSeconds 60 `
  -Resolution 1280x720
```

The wrapper always delegates to `tools/run_godot_serial.ps1`, always selects
the windowed renderer, sends engine output to a unique temporary log, disables
audio output, refuses to overwrite evidence and writes
`capture_receipt.json`. It has no retry loop.

An exit of 73 is a stop condition. It means the lane was already owned, Godot
was already active, or the runner reached its ceiling. Read the filtered line
and coordinate; do not turn contention into six automated attempts separated
by sleeps.

Preflight validates the scene, absolute output, no-overwrite condition and
current process census without launching Godot or creating the run directory:

```powershell
pwsh -NoProfile -File tools/run_godot_capture.ps1 `
  -Scene res://tests/ExampleShot.tscn `
  -ShotRoot C:/PleaseRemainOnTheLine/art/renders/example_task `
  -RunName production_01 -ExpectedFrames 8 -PreflightOnly
```

Preflight may report BUSY with exit 73. It does not own the mutex and is not a
reservation; run the real command only after coordinating the lane.

## Quantified time budget

The process ceiling is 60.0 seconds. A shot scene receives a **54.0-second
internal budget**, reserving six seconds for process launch/exit and receipt
handling. Design to this target:

| Phase | Target | Hard design warning |
| --- | ---: | ---: |
| Focused/isolated boot | ≤ 18 s | 24 s |
| Full `orison_root` boot | provisional 32.84 s (n=2) | investigate above 36 s |
| Resolve owners/player/camera | ≤ 4 s | 6 s |
| Visual warm-up | ≤ 6 s | 8 s |
| Camera/state changes | ≤ 6 s total | 10 s |
| Captures | 0.35 s budget each | 18 frames maximum per shard |
| Scene receipt and quit | ≤ 2 s | 4 s |
| Reserved process margin | 6 s | never spend |

An 18-frame focused suite at the original targets costs roughly 42 seconds and
retains twelve seconds of scene margin. A full-production suite does not have
that budget. K2-F measured `orison_root` ready at 32.519 seconds; K2-G measured
33.160 seconds. Their provisional mean is 32.840 seconds, but two samples still
do not establish p50/p90. K2-G had only 9.6 seconds of scene margin after eleven
captures and ordinary state preparation. For full-root work, target 8–12
frames, treat 15 as a stop-and-shard warning, and split independently meaningful
subjects before cutting visual settling. Record five suites, then set p50/p90
budgets.

Every scene using `ShotHarness` prints checkpoints as:

```text
[TAG TIMING] stage=production_ready elapsed=14.822 remaining=39.178
[TAG CAPTURE] 3/8 label=02_yes elapsed=19.406 path=...
[TAG] RESULT: PASS captures=8 expected=8 elapsed=23.104
```

This distinguishes slow boot, slow state preparation, render starvation and
teardown. A timeout with no capture line is not an image failure; it is a
budget/boot failure.

Every timing checkpoint also prints a reserve line. `outstanding` is the
declared frame count still owed, `reserve` prices those frames at 0.35 s each
plus two seconds to finish, and `slack` is the remainder. Negative slack means
the declared suite no longer fits even before optional settling; stop and shard
instead of deleting evidence or lowering the expected count.

## New scene skeleton

```gdscript
extends Node

const ShotHarnessScript := preload("res://tests/shot_harness.gd")
var shots = ShotHarnessScript.new()


func _ready() -> void:
	if not shots.setup(self, "EXAMPLE SHOT", 4):
		get_tree().quit(2)
		return
	var root := load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	if not await shots.settle(1.8, "production_ready"):
		get_tree().quit(2)
		return
	# Resolve and validate every required owner before moving the camera.
	shots.checkpoint("owners_resolved")
	Engine.time_scale = 0.0
	await shots.capture("00_control_a")
	await shots.capture("00_control_b")
	# Apply exactly one declared state change here.
	await shots.capture("01_claim")
	# Restore and photograph the abort/return condition.
	await shots.capture("02_restored")
	Engine.time_scale = 1.0
	get_tree().quit(0 if shots.finish() else 2)
```

Use real-time timers (`create_timer(t, true, false, true)`) for waits that must
still complete after `Engine.time_scale = 0`. Prefer explicit state pins over
tweens for frozen evidence. Two process frames plus `frame_post_draw` flush a
camera/material change; adding an arbitrary eleven-second sleep does not make
that claim stronger.

`capture_frozen_pair(stem)` writes one resolved image twice. Use it only when
the declared claim is state identity. Its receipt marks
`same_resolved_image`; it produces a forced zero and therefore is not evidence
of temporal renderer stability. To measure the real temporal floor, call
`capture()` twice without changing state and let both frames render.

## Camera and state contract

Before the first capture, declare:

- camera class: `playable`, `composition` or `isolated`;
- eye, target, FOV and resolution;
- player body, carried lamp, audio listener and streaming origin disposition;
- time/weather/random seeds and which clocks remain live;
- exact state owner and the single change between each comparison;
- expected frame count and filename list;
- crop rectangles for claims too small to price honestly whole-frame.

For a playable camera, move the body and camera together and prove supporting
floor. A detached camera with the player lamp left elsewhere is a synthetic
composition view and must say so.

Hide HUD owners by exact identity. Do not recursively hide every `CanvasLayer`:
K2-F's rejected `production_01` proved the carried service set is composited
through its own CanvasLayer, so a broad sweep made the frame prettier by
quietly removing the instrument from the player's hands. A playable-camera
mask should stop at the player and explicitly preserve carried equipment,
listener and streaming state.

The primary subject should normally cover at least 8% of frame area or have a
declared crop at least 160 × 120 pixels. A moving indicator should span at least
six pixels between compared poses. These are framing diagnostics, not aesthetic
laws; exceptions must explain what smaller evidence remains legible.

## Required frame grammar

Every visual claim needs:

1. **local A/A:** unchanged state, same camera, same crop and equal interval;
2. **A/B claim:** exactly one declared state difference;
3. **return or abort:** if reversibility is claimed;
4. **context:** one frame proving production placement and route hierarchy;
5. **refusal:** only when the refusal has a visible held pose.

Do not price a close-up claim against a wide-camera floor. Do not reuse a
daylight floor for rain, a lobby floor for a roof, or a frozen duplicate as a
temporal floor.

## Offline measurement

After a successful capture, write a small manifest beside the run:

```json
{
  "pairs": [
    {
      "name": "head_floor",
      "a": "00_control_a.png",
      "b": "00_control_b.png",
      "kind": "control",
      "crop": [420, 120, 400, 420]
    },
    {
      "name": "yes_nod",
      "a": "00_control_a.png",
      "b": "02_yes.png",
      "kind": "claim",
      "floor": "head_floor",
      "crop": [420, 120, 400, 420],
      "min_rmse": 0.01,
      "min_floor_ratio": 3.0
    }
  ]
}
```

Then run, with Godot closed or occupied by someone else—it is pure offline
image analysis:

```powershell
python tools/measure_shot_sheet.py `
  C:/PleaseRemainOnTheLine/art/renders/example_task/production_01 `
  --manifest C:/PleaseRemainOnTheLine/art/renders/example_task/production_01/metrics_manifest.json
```

The analyzer writes `shot_metrics.json` and `contact_sheet.png`. It records
dimensions, byte size, SHA-256, luma percentiles, black/clipped fractions and
linear-RGB RMSE. Declared thresholds fail closed. It does not invent universal
thresholds: a six-centimetre brass drop and a whole wall legitimately require
different crops and minima.

Useful starting thresholds, to be replaced by task evidence:

- changed whole composition: RMSE ≥ 0.005 and ≥ 3× its local floor;
- mechanism crop: RMSE ≥ 0.010 and ≥ 3× its local floor;
- refusal crop: should clear the ordinary state floor and differ from every
  other refusal intended to communicate a different cause;
- clipping warning: inspect when ≥ 0.5% of pixels are at luma 254–255;
- black-field warning: inspect when ≥ 65% of pixels are at luma 0–1.

These are warnings and initial gates, not permission to accept an ugly image.
Every contact-sheet frame still receives human inspection at full size.

When an A/A floor is exactly zero, a multiplicative ratio is mathematically
undefined, not “infinite proof.” Declare a positive absolute `min_rmse`; the
analyzer records `floor_ratio_note: undefined_zero_floor` and fails a zero-floor
ratio claim that has no absolute minimum.

## Failure diagnosis

| Symptom | Meaning | Next action |
| --- | --- | --- |
| Exit 73 before a process starts | Lane/editor already active | Coordinate and stop; no retry loop |
| Exit 73 near 60 s | Ceiling terminated the run | Read last timing/capture receipt; split or reduce boot/warm-up |
| Zero frames, no scene receipt | Scene never reached capture setup or parse failed | Filter parse/script errors; do not tune waits |
| Zero frames after production boot | Headless renderer, frozen timer or unresolved owner | Require wrapper/windowed; use real-time timer; fail owner resolution |
| Some frames, wrong count | Late stage stalled or save failed | Last capture line names boundary; check budget and disk error |
| Byte-identical intended changes | State did not own the visible pose or camera misses it | Fix ownership/framing; do not lower metric threshold |
| Noisy A/A | Live shader/weather/exposure/temporal state | Pin it or price the claim against that camera’s measured floor |
| All-dark or blown sheet | Exposure/light/camera problem | Inspect luma report and full frames before rerunning |

## Claude → integrator report block

Use this exact compact report so the integrator can distinguish a completed
sheet from “PNG files exist”:

```text
--- BEGIN CAPTURE HANDOFF ---
Task / commit / base:
Scene and exact wrapper command:
Run directory:
Capture receipt: status, exit, elapsed, frames expected/actual:
Timing: production_ready, first_capture, finish:
Camera class / eye / target / FOV / resolution:
Controls: each A/A pair and RMSE:
Claims: each A/B pair, crop, RMSE, floor ratio, threshold:
Luma warnings: black/clipped fractions and inspected disposition:
Human inspection: every frame inspected at full size (yes/no); rejected frames and why:
Production invariants tested:
Known limitations:
No-overwrite / one-instance confirmation:
--- END CAPTURE HANDOFF ---
```

## Adoption plan

1. Use the wrapper immediately for all new runs.
2. Use `ShotHarness` for new scenes and migrate a legacy scene only when it is
   already being changed.
3. Add metrics manifests to accepted sheets, not to discarded experiments.
4. Keep the raw engine log temporary; commit receipts, metrics, selected frames,
   contact sheet and a concise README.
5. After five suites, review actual boot/capture percentiles and replace the
   initial time budget with measured p50/p90 values.

Audit adoption without launching Godot:

```powershell
python tools/audit_shot_suites.py
python tools/audit_shot_suites.py --format json --output shot_suite_audit.json
```

The inventory is a triage aid, not a quality score. It flags observable source
hazards such as unchecked `save_png()`, output fallbacks, direct-Godot command
examples and excessive frame waits. A legacy suite is migrated when its subject
is next changed, starting with suites that combine several hazards or boot the
full production root. Generated audit reports are working artifacts unless a
milestone explicitly adopts one; do not add a permanently stale snapshot to
the repository.

## Applied audit: Claude K2-F `unit_direction_shot.gd`

Read-only audit on 2026-08-26; no file in Claude's worktree was changed.

Current explicit minimum:

- production settle: 1.8 s;
- first-camera settle: 1.6 s;
- frozen UI-toast wait: 8.0 s (comment still says six);
- eleven snapshots × 0.3 s: 3.3 s;
- total literal waits: **14.7 s**, excluding synchronous production-root build,
  frame-post-draw waits, PNG encoding and teardown.

Risks observed:

- missing plate/director/detector/register checks can turn one absent owner into
  a late script failure after the expensive boot;
- fallback to `user://k2f_shot` can make a run appear successful while writing
  somewhere other than the declared evidence directory;
- `save_png()` errors are discarded;
- expected frame count 11 is not asserted and there is no final `RESULT: PASS`;
- the eight-second wait removes HUD contamination by elapsed time instead of
  explicitly hiding the presentation owner;
- `03_corridor_control_a`, `03_corridor_control_b` and
  `04_the_way_the_glyph_points` have no intervening state change. The third is
  a valid context image but not an A/B claim and should be named/reported as
  context or removed if byte-identical;
- five camera stations share only two local control groups. Door, F04 and later
  context images are attractive placement evidence but cannot borrow the
  arrival/corridor temporal floors for quantitative claims.

Immediate command, once her scene itself is ready and the lane is coordinated:

```powershell
pwsh -NoProfile -File tools/run_godot_capture.ps1 `
  -Scene res://tests/UnitDirectionShot.tscn `
  -ProjectPath C:/PleaseRemainOnTheLine/.claude/worktrees/juno-kells-dream-profile-5c8621/game `
  -ShotRoot C:/PleaseRemainOnTheLine/.claude/worktrees/juno-kells-dream-profile-5c8621/art/renders/first_minute_k2f `
  -RunName production_01 -ExpectedFrames 11 -TimeoutSeconds 60 `
  -Resolution 1280x720
```

Recommended next edit in her lane: preload `ShotHarness`, require absolute
`SHOT_DIR`, resolve all four owners before interactions, hide the objective/HUD
owner explicitly, replace `_snap` with `shots.capture`, and finish through
`shots.finish()`. Removing only the blind eight-second fade wait reduces the
literal minimum from 14.7 to **6.7 seconds**; the capture receipt will then show
whether production boot, rendering or teardown is the remaining cost.

### K2-F migration result

Claude completed that migration in `c80d3b2` (parent `e73cb41`). The first
accepted protocol run, `production_02`, records:

- wrapper PASS, exit 0, 47.537 s process, 11/11 nonzero frames;
- scene setup 0.000, production ready 32.519, owners 32.522, lamp/camera 36.950,
  overlays hidden 36.972, first capture 37.4, finish 42.692;
- literal waits reduced from 14.7 to 3.4 seconds;
- arrival local controls 0–0.0000190 linear-RGB RMSE;
- corridor control 0.0007028, down from the HUD-contaminated 0.136;
- primary 320×150 plate claim 0.0287, 1,513× its local nonzero floor;
- no black/clipping warning and every frame inspected full-size;
- one entire run rejected because broad CanvasLayer hiding removed the carried
  service set, demonstrating why equipment preservation is a capture invariant.

This is one full-root timing sample, not a percentile. It validates the wrapper,
harness, receipt and measurement flow and replaces the provisional full-root
boot target with an evidence-collection requirement.
