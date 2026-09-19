This gate-only revision fixes a demonstrated classifier error. It does not
change Godot, the live fixture, material production code, runtime captures or
the earlier classification.

Godot's actual finish material ID -9223370061119417423 is a nonzero signed64
integer. The old positive-only check rejected it and7,690 other case material
records. The new predicate requires `type(value) is int`, a value in
[-2^63,2^63-1], and nonzero. It excludes Python bool,zero,out-of-range values,
floats,strings and null. It changes only the existing case material identity
predicate; all other gates retain their original bytes and semantics.

- Original gate: `be9a2f9aba3a3377332d1678ca01c095f9fcda46a1db9b51d540eb58ced7f4db`.
- Revised gate: `8e347a82e36b5ad8f43019ba18b32cba6cd2adf556baf60026218d95ed523d11`.
- Classifier copied unchanged: `f2020a5873aa6225061d961fdd9fd987c37f1c6173316ba62071270f599384e6`.
- `originals` retains the prior gate,classifier,tests and exact original full02
  classification. The captured real negative finish row is in `fixtures`.

Fourteen pure controls pass. They include the real negative-ID witness
transplanted into controlled complete gate metadata, original false red versus
corrected green, exact signed64 boundaries, rejected zero/bool/out-of-range
inputs, all ten inherited material-gate controls, and the actual composed red
remaining red. This transplanted fixture isolates the parser rule; it is not a
new production runtime green.

The actual run was reclassified read-only with the copied unchanged classifier:

```powershell
python design/astra/work/composed_material_invariants/gate_revisions/signed_ids_01/proposed/classify_result.py design/astra/evidence/vulkan_composed/runs/material_ownership_7c54_v1_full_02/result.json --owner-sha256 7c54c18154ccf8de8c3bce13a356329344dec19411adb2f1237425ae99eb90db --fixture-sha256 c2642de6f0c099a18e8d7c0f740f94a84f0d5bc90cc255973dee5ab6ad2ee6b5 --out design/astra/evidence/composed_material_ownership/typed_baseline_additive_signed_ids_02.json
```

That output now exists and must not be overwritten. Its actual classifier
exit remains1, with base1/material1. Exactly7,691 false identity reasons are
removed; all101 other reasons are unchanged in the same order. The native
engine exit1 and eight material assertion failures remain intact.

The first pure preservation test guessed24 registry diagnostics. Exact data
shows23: the final observation has a correct F06 registry and four additional
stale Cal rows instead. That test expectation mistake and its logs are retained
under `preparation_failures/registry_count_01`; no production requirement or
gate was relaxed to correct it.

The actual composition findings and instrument limits are in
`runtime_analysis.json` and `runtime_analysis.md`. No engine was run during
this gate correction, and no live game file was changed.
