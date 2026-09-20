The initial actual-build trial is ready independently of later source controls.
The root task owns the engine lane and chooses the launch. This plan did not
run Godot or install a live file.

Use working directory `C:/PleaseRemainOnTheLine-astra`. Preserve all current
game/tools bytes for the complete run. Install only the prepared fixture:

- Target: `game/tests/vulkan_composed_root_test.gd`.
- Current/restore SHA256: `5ec63c36c6181b33c02bd2255039e9bf4e8db0c4465a45ac641d1481f422d6d3`.
- Prepared candidate SHA256: `e132724ae67f1dc4056f9fa1c9b018706399a7c3500889af41d0e6dedeeb8991`.
- Exact original and candidate are under this package's `originals/game/tests`
  and `proposed/game/tests`. Keep the material owner at `7c54c18154ccf8de8c3bce13a356329344dec19411adb2f1237425ae99eb90db`.

The source helper is optional; it performs a checked byte swap and saves the
original/replacement bytes plus independent receipt. In an outer try/finally:

```powershell
python design/astra/work/composed_material_invariants/runtime_execution/source_operation.py install_fixture --execute --receipt-dir C:/PleaseRemainOnTheLine-astra/design/astra/evidence/composed_material_ownership/initial_fixture_install_01
python design/astra/work/composed_material_invariants/runtime_execution/invoke_wrapper.py baseline --execute --receipt-dir C:/PleaseRemainOnTheLine-astra/design/astra/evidence/composed_material_ownership/initial_green_invocation_01
```

Check each actual exit. In finally, after the engine has terminated:

```powershell
python design/astra/work/composed_material_invariants/runtime_execution/source_operation.py restore_fixture --execute --receipt-dir C:/PleaseRemainOnTheLine-astra/design/astra/evidence/composed_material_ownership/initial_fixture_restore_01
```

The root can use its own byte-checked try/finally wrapper. The invocation helper
performs no source mutation; its exact engine wrapper call is:

```powershell
python design/astra/work/vulkan_composed/run_case.py v1 candidate material_ownership_7c54_v1_full_01 --scope full
```

It first rejects inherited nondefault ENCROACH/LIVING controls, then passes the
reviewed normal values: ENCROACH=1, ENCROACH_FORCE empty, ENCROACH_DEBUG_VIEW=0,
ENCROACH_DEBUG=0, LIVING=1, LIVING_ALL=0. The fixture's actual case/beachhead
pre-state guard remains intact. The existing wrapper creates fresh APPDATA and
SHOT_DIR, clears its normal presentation/performance overrides, and selects
Vulkan Forward+,1280x720,Dummy audio,verbose,180 seconds.

Five pure tests evaluated only the child-environment statements extracted from
the exact existing wrapper. They prove that the existing wrapper retains a
hostile mina:0.8 force while this launcher refuses it. Actual dry preflight
found all six inherited variables absent and produced the declared child
environment. No hidden profile reset, case write or governor pin is used.

After the raw run is complete, write the additive result outside it:

```powershell
python design/astra/work/composed_material_invariants/classify_result.py design/astra/evidence/vulkan_composed/runs/material_ownership_7c54_v1_full_01/result.json --owner-sha256 7c54c18154ccf8de8c3bce13a356329344dec19411adb2f1237425ae99eb90db --fixture-sha256 e132724ae67f1dc4056f9fa1c9b018706399a7c3500889af41d0e6dedeeb8991 --out design/astra/evidence/composed_material_ownership/initial_green_additive_01.json
```

Declared success is engine/base/additive exits0,314 checks,18 required PNGs,
36 measured transitions,eight material observations,two same-frame restored
state probes,and actual root/material retirement. Counts remain expectations
until observed. Inspect all case rows, the complete registry/cache/exclusion
records and every PNG. An initial failure stops the control sequence; preserve
all diagnostics and source evidence, restore exact bytes, then diagnose it.

Bind/copy the invocation and environment helper bytes in the outer receipt:
the unchanged runtime wrapper snapshots game/tools and its own sources, while
these helpers live outside game. Never add post-run files inside the immutable
raw run's artifact map. Use fresh names if a prior attempt exists.

The complete serialized sequence is `runtime_plan.json`. The old missing-marker
omission is withdrawn and must not run as an expected red. The separately
prepared F00 corruption is conditional on an actual green and row review.
