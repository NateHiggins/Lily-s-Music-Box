# Reused controller for the 2a440 floor-aware comparison

This is the existing `runtime_plan_01` controller rebound to the preserved
`ownership_2a440_01` package and a fresh evidence batch of that name.
`execute.py` changes only those two names; bridge, support, assessment, gate,
ordered contract and their tests are copied byte-for-byte. The manifest binds
the six new test sources, unchanged 171-check fixture and current direct
production dependencies. Preparation performs only the existing offline
controls, including a stub PowerShell invocation; it never launches Godot.

After an explicit engine/source handoff, from the canonical repository run:

```powershell
python -B design/astra/work/encroachment_sweep/equivalence_revisions/runtime_plan_2a440_01/execute.py plan
python -B design/astra/work/encroachment_sweep/equivalence_revisions/runtime_plan_2a440_01/execute.py install ownership_2a440_01
python -B design/astra/work/encroachment_sweep/equivalence_revisions/runtime_plan_2a440_01/execute.py candidate ownership_2a440_01
python -B design/astra/work/encroachment_sweep/equivalence_revisions/runtime_plan_2a440_01/execute.py priority ownership_2a440_01
python -B design/astra/work/encroachment_sweep/equivalence_revisions/runtime_plan_2a440_01/execute.py drop_late ownership_2a440_01
python -B design/astra/work/encroachment_sweep/equivalence_revisions/runtime_plan_2a440_01/execute.py restored ownership_2a440_01
```

Each source control must satisfy its existing declared functional red while
the engine and diagnostic exits remain red. Unknown diagnostics, incomplete
171-label output, baseline failures, source drift, missing retirement or
crashes are rejected. Pause on unexpected results; preserve every run folder.
No production owner is replaced for this focused test. Preinstall test bytes
can be restored with the existing `restore-preinstall` action once the engine
lane is idle; it refuses foreign source edits or corrupt backup bytes.

This controller does not establish actual build, viewport survival or render
performance. Those remain separately source-bound composed run obligations.
