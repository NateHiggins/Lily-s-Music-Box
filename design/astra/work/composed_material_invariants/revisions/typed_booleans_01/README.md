This is the next baseline candidate after the actual e132 parser failure.
Only eight reported local declarations change from inferred `:=` to explicit
`: bool =`. Original e132 fixture and helper bytes are retained here, while
the parent preparation/invocation package remains unchanged.

Root reported the first run's actual serial-runner exit124 after180.534seconds,
nine non-inherited headers(eight parser errors plus script-load failure),
source_unchanged=true and exact restoration of5ec63. Its result SHA256 is
ece9c004a275052d0c476da93c0d199b9c1816082f0f2d55ea808a84a600ecff. No building,
material, image or performance result follows from that attempt.

After explicit engine/source handoff, the root's byte-checked try/finally may
install this revision's `proposed/game/tests/vulkan_composed_root_test.gd`:

- Live starting and final restore SHA256: `5ec63c36c6181b33c02bd2255039e9bf4e8db0c4465a45ac641d1481f422d6d3`.
- New installed fixture SHA256: `c2642de6f0c099a18e8d7c0f740f94a84f0d5bc90cc255973dee5ab6ad2ee6b5`.
- Restore bytes: parent package `originals/game/tests/vulkan_composed_root_test.gd`.
- The `originals` under this revision are e132, the immediate source parent;
  they are not the live5ec63 cleanup target.
- Material owner remains exact7c54c18154ccf8de8c3bce13a356329344dec19411adb2f1237425ae99eb90db.

The small revision-aware invocation only launches the unchanged existing
wrapper after the same reviewed environment refusal/default contract. It
copies and binds its outside-game invocation sources into the outer receipt.
It does not install or restore any source file.

```powershell
python design/astra/work/composed_material_invariants/revisions/typed_booleans_01/runtime_invocation.py --execute --receipt-dir C:/PleaseRemainOnTheLine-astra/design/astra/evidence/composed_material_ownership/typed_baseline_invocation_02
```

This invokes exactly:

```powershell
python design/astra/work/vulkan_composed/run_case.py v1 candidate material_ownership_7c54_v1_full_02 --scope full
```

Restore exact5ec63 in the root's finally after engine termination, preserving
the complete raw run and independent before/after source receipt. Then:

```powershell
python design/astra/work/composed_material_invariants/classify_result.py design/astra/evidence/vulkan_composed/runs/material_ownership_7c54_v1_full_02/result.json --owner-sha256 7c54c18154ccf8de8c3bce13a356329344dec19411adb2f1237425ae99eb90db --fixture-sha256 c2642de6f0c099a18e8d7c0f740f94a84f0d5bc90cc255973dee5ab6ad2ee6b5 --out design/astra/evidence/composed_material_ownership/typed_baseline_additive_02.json
```

The original expectations remain314 checks,eight observations,18PNG,36 measured
transitions,two safely restored state probes and actual root/material
retirement. They remain unobserved. An initial green and actual row/image
review are still required before the separate wrong-storey control. The old
e132 invocation helpers pin e132 intentionally and must not be used for this
revision. This candidate's Godot parser/runtime remains unverified.
