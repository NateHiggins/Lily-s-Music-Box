# Terminal access: deferred-arrival fixture revision

This is a new, outside-game package. No runtime result is claimed here. It preserves the production proposal and omissions from `v2_terminal_access_01` exactly and replaces only that package's focused fixture and its admission/controller metadata after review.

The first package's actual original run was 16/36, native 1; candidate was 21/36, native 1. Both rays in both runs originated at the curb, approximately `(-3.6, 1.51, 24.72)`. The original's exact predicted failure count therefore did **not** establish an operator-position negative proof. The candidate's fifteen input failures were fixture setup failures; its orientation and DeskZone composition observations remain measured facts. Those raw receipts, the sealed package and its historical assessor are unchanged. `historical_run_review.json` binds the selected raw sources and observations.

`FirstShiftDirector._ready()` queues `_begin_if_needed()`. With `intro_complete=true`, the callback places the player at the authored curb and then presents resume state. `is_node_ready()` and `ritual_phase()` do not signal this callback's completion. The new fixture disables only player physics, observes the actual curb position, standing eye, yaw, velocity, collision flags and owning director, and waits two more process frames with that pose retained. It preserves the seeded `complete` ritual. Only then does the fixture place the actor at the authored operator and aim the actual camera at SignalScope.

The original 36 checks remain in the same order and keep their existing assertions. Three checks are added: witnessed deferred arrival settlement, the first operator/eye ray origin, and the second operator/eye ray origin. The receipt now has schema `astra.v2-terminal-access.probe.v2`. Both rays include actor position, camera position and the disabled-physics flag. The Python assessor independently requires the authored actor `(-9.9,9.6,1.25)` and eye `(-9.9,11.01,1.25)`, finite coordinates, ordinary 2.1m range and aim toward the measured SignalScope. A forged PASS label cannot substitute for those coordinates.

The runtime controller keeps the same windowed Forward+ request, canonical serial runner, isolated JSON-splat PowerShell bridge, native exit handling, known warning debt, PID ancestry and source/artifact admission. The old core remains an imported utility with explicit overrides, not the CLI. Fifteen selected source copies now include FirstShiftDirector. No additional full asset archive is introduced.

Installation requires HEAD `af9c5b6fdc42079d4bd64549b709a49ababa9e50`, original production bytes `68c3a920…` and `294fa627…`, an empty engine lane, and the two exact previously installed fixtures `74a2bd4f…` / `58efa825…`. It backs up both previous fixtures and both original production files into the fresh evidence namespace before replacing the fixture. Unexpected, missing or additional fixture identities are rejected. Source transitions and omission restoration retain their existing exact-byte/empty-lane protections.

After root review and explicit lane authorization, the sole CLI is:

```powershell
python design/astra/work/v2_terminal_access_arrival_02/runtime/run.py install
python design/astra/work/v2_terminal_access_arrival_02/runtime/run.py 01_original
python design/astra/work/v2_terminal_access_arrival_02/runtime/run.py 02_candidate
python design/astra/work/v2_terminal_access_arrival_02/runtime/run.py 03_orientation_omission
python design/astra/work/v2_terminal_access_arrival_02/runtime/run.py 04_desk_omission
python design/astra/work/v2_terminal_access_arrival_02/runtime/run.py 05_footprint_omission
python design/astra/work/v2_terminal_access_arrival_02/runtime/run.py 06_restored_candidate
```

Inspect the actual original result before running the candidate. Stop for every unplanned result. Fresh runtime evidence is `design/astra/evidence/v2_terminal_access_arrival_02`; no command reuses the old namespace. Expected values are predictions, not results:

| Variant | Passed / total | Native / ordinary gate |
|---|---:|---:|
| Original | 19/39 | 1/1 |
| Candidate | 39/39 | 0/0 |
| Orientation omission | 38/39 | 1/1 |
| Desk omission | 20/39 | 1/1 |
| Footprint omission | 38/39 | 1/1 |
| Restored candidate | 39/39 | 0/0 |

`offline_validation_01` records an actual Python red/green: removing the new origin validator makes the wrong-curb control fail with exit 1; the unmodified 21-test suite exits 0. These are synthetic parser/controller tests, not Godot execution. They preserve all 15 earlier controls and add independent first/second wrong-origin, actor/camera, malformed geometry, arrival-settlement and exact previous-fixture replacement controls.

The observable one-shot arrival settlement is not general world readiness. Subsequent operator placement is controlled and physics-disabled, not a walked route, body-clearance or collision-bearing travel proof. Existing real input actions, Escape event dispatch, reciprocal seating/call/player ownership, audio playback, case continuity and actual retirement assertions are unchanged. Opening narrative delay remains compressed by the existing test hook. Completed cases, later field phases, performance and perceptual acceptance remain outside this fixture. Reservation visuals remain unchanged.
