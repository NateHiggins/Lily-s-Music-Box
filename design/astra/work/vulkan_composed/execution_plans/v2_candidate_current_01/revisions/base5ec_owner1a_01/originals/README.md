# V2 candidate composition plan

This is an offline execution plan. Run only after root finishes the optimized-owner V1 comparison and grants the exclusive engine/source lane. Reuse the existing base fixture, `run_case.py`, `gate.py` and unchanged 180-second serial runner; no variant driver or source mutation is required.

The selected scene is `res://scenes/building/orison_v2_runtime.tscn`, script SHA256 `68c3a920f7456185098fda4fe56ab14f650fb407d8b02f4e6c2c8b326b87a0bb`. `BuildingRootSelector.reset_for_tests("v2")` selects it inside an actual `CampaignShell`. The committed default remains V1. The fixture must be base `5ec63c36c6181b33c02bd2255039e9bf4e8db0c4465a45ac641d1481f422d6d3`, with scene `b95080899e02aa01d87b9a688ffee970f5d3e5ef14399d87cde6d91d40cc2663`. Do not substitute the d67 material observer merely because it was used by the preceding V1 run.

`plan.json` declares 20 small source bindings, all 14 ordered assertion labels, the two capture names and the normal material environment. Its apartment-owner hash is a preparation observation only: root must declare the final owner and HEAD at the later handoff. V2 does not instantiate `ApartmentEncroachment`, so this run cannot measure or substantiate its optimization. The full run snapshot still binds that source as part of the checkout. The existing wrapper also checks the V1 candidate helper/viewport guard in `building_root.gd` even when selecting V2; retain the cde44 candidate bytes and do not interpret that wrapper prerequisite as V2 executing those methods.

## Exact execution contract

Run `v2 candidate candidate_v2_foundations_01 --scope full`. The name was unused during preparation. V2 cannot use `root_retirement` scope. Require native exit 0, diagnostic gate 0, all 14 exact ordered checks passing, both PNGs written, final `checks=14 failures=0`, and the `after_retirement` phase. V2 startup must select the actual scene, expose the production player and `F04_B_MONITOR_01`, and resolve the actual `F04_B_BED` stance through its anchor adapter. Missing startup/stance evidence is a failed or incomplete run, never an adjusted expected count.

The fixture sets a frozen campaign clock explicitly to 1928-11-10 03:00, disables persistence, marks the introductory setup complete and uses a manual shell sleep clock. That is controlled fixture setup, not observation of autoload host-sampling behavior or title/Continue handling. The wrapper supplies a fresh APPDATA, weather seed 19281110, silent title, Vulkan Forward+, 1280x720 main viewport and Dummy audio. Its child clears inherited `PERF_`/`SURFACE_` and listed schedule/daynight controls; the fixture then requests night and schedule 0. Use the existing `prepare_environment` contract before invoking the wrapper so inherited nondefault material controls cause refusal, and record that environment separately from the immutable run directory.

The two required captures are `v2_actual_f04_semantic_stance.png` from the main viewport and `v2_actual_f04_phone.png` from the production `PhoneCamera` lens. The camera looks toward the real terminal from the semantic bedside stance after eight rendered frames. The phone is mounted by the fixture and shares the selected world; this does not exercise the handset UI. Both PNGs need direct visual inspection, including actual content, exposure and legibility. The gate checks successful capture/file presence, not meaningful pixels or visual quality.

Retirement deactivates the phone, queues its fixture host, queues the real shell, waits one process frame plus four rendered frames and 0.2 seconds, and checks both shell and selected-world WeakRefs. It does not call `shutdown_for_tests` or pre-clear rendering pairs. Inspect all post-retirement native/project/retention diagnostics. In V2, the adapter's normal `_exit_tree` restoration path runs; the fixture does not independently compare every restored acoustic record.

Expected V2 payload: zero transitions; `separate_world_case_executed=false`; `v2_street_passage_applicability="absent"`; one `v2_f04` population row. There are no V1 zone, Harukiya, arcade, planar-mirror or independent-world sequence claims, and no V1 305-check/18-image requirement. This is root composition/render/retirement evidence, not traversal, final art, release performance, default cutover or optimized-owner acceptance.

## Invocation after explicit handoff

First confirm the empty engine lane, fresh output name, exact base fixture/restored cde44 root, current declared owner/HEAD and the small pinned hashes in `plan.json`. Keep game/tools frozen for the run. Do not execute the wrapper's full snapshot hashing alongside another measured run. The following uses only the existing environment contract and wrapper; the extra directory preserves invocation/environment metadata outside the wrapper's immutable artifact census.

```powershell
Set-Location -LiteralPath 'C:\PleaseRemainOnTheLine-astra'
@'
from pathlib import Path
import datetime, hashlib, importlib.util, json, os, subprocess, sys
root = Path.cwd()
plan_path = root / 'design/astra/work/vulkan_composed/execution_plans/v2_candidate_current_01/plan.json'
plan = json.loads(plan_path.read_text(encoding='utf-8'))
for path, expected in plan['pinned_source_sha256'].items():
    if hashlib.sha256((root / path).read_bytes()).hexdigest() != expected:
        raise SystemExit('Declared small source changed: ' + path)
module_path = root / 'design/astra/work/composed_material_invariants/runtime_execution/environment_contract.py'
spec = importlib.util.spec_from_file_location('existing_material_environment', module_path)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
env, contract = module.prepare_environment(os.environ)
name = plan['run_name']
run = root / 'design/astra/evidence/vulkan_composed/runs' / name
if run.exists(): raise SystemExit('Fresh run directory required')
invocation = root / 'design/astra/evidence/vulkan_composed/v2_candidate_invocations' / name
invocation.mkdir(parents=True, exist_ok=False)
command = [sys.executable, '-B', 'design/astra/work/vulkan_composed/run_case.py', 'v2', 'candidate', name, '--scope', 'full']
owner = 'game/scripts/reality/apartment_encroachment.gd'
record = {'prepared_at_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
          'command': command, 'material_environment': contract,
          'head': subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(),
          'actual_owner_sha256': hashlib.sha256((root / owner).read_bytes()).hexdigest(),
          'projected_child_environment': {key: value for key, value in module.actual_wrapper_environment(env, run / 'APPDATA', run / 'frames', root='v2', scope='full').items()
              if key in set(module.NORMAL) | {'APPDATA','SHOT_DIR','ORISON_BUILDING_ROOT','VULKAN_COMPOSED_VARIANT','VULKAN_COMPOSED_SCOPE','CAMPAIGN_TIME_FREEZE','WEATHER_SEED','TITLE_SCREEN_SILENT'}}}
(invocation / 'plan.json.source').write_bytes(plan_path.read_bytes())
(invocation / 'environment_contract.py.source').write_bytes(module_path.read_bytes())
(invocation / 'invocation.json').write_text(json.dumps(record, indent=2) + '\n', encoding='utf-8')
process = subprocess.run(command, cwd=root, env=env, capture_output=True)
(invocation / 'wrapper.stdout.log').write_bytes(process.stdout)
(invocation / 'wrapper.stderr.log').write_bytes(process.stderr)
record['actual_wrapper_diagnostic_exit'] = process.returncode
(invocation / 'invocation.json').write_text(json.dumps(record, indent=2) + '\n', encoding='utf-8')
raise SystemExit(process.returncode)
'@ | & 'C:\Users\nate_\AppData\Local\Programs\Python\Python312\python.exe' -B -
```

The inline invocation has been syntax-checked offline only. No engine run or automatic retry is authorized by this document. A rejected preflight requires a reviewed new declaration; preserve any unexpected runtime result and do not replace the existing evidence directory.

## Read-only result review

Use existing `pair_bookkeeping_case.validate_artifacts(folder, result)` for the complete retained artifact census/hash checks and copied-source binding, then reproduce `gate.classify` from the retained native exit, streams, probe and source/engine flags. Do not call `load_run`: it additionally expects a variant transaction, while this direct candidate invocation performs no mutation and should have none. Verify before/after file maps and engine manifests are exactly equal, both engine binaries are present, wrappers match this plan, and the selected root/variant/scope match the request. Preserve command, PID, native exit and all streams.

The ordinary gate does not enforce exact ordered labels or explicit retirement labels independently, so compare the 14 rows to this plan and require both real retirement checks once. It records warnings without a scoped allowlist; inspect every raw warning/error and do not inherit V1 RGB8 counts or grant blanket acceptance. Only its precise known loader-manifest exception is pre-existing. Any missing footer, partial capture, project error, native pairing/soft-shadow signature, retention, crash or timeout remains a failure. Record direct review of both PNGs in a separate review without modifying frozen machine receipts.
