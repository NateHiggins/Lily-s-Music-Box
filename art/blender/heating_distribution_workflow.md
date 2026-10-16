# Heating distribution candidate

Evidence class: **INERT**. Build instructions, not installed-world acceptance.

The assembly connects the 18 installed radiator floor stubs to four mains
and the boiler receiver. It retains the existing heating simulation and
radiator controls. Reviewed exports are now installed in production paths;
the scripts below still emit candidates for inspection before replacement.
The acoustic graph has not been replaced. Broad runtime acceptance remains open.

Use an explicit work directory so review artifacts survive independently of
the original temporary workspace. Run from the repository root. The examples
use `tmp/heating-review`; substitute another directory consistently.

```powershell
python tools/plan_v2_heating_distribution.py --out tmp/heating-review/heating_routes_exact.json
python tools/build_v2_heating_interfaces.py --routes tmp/heating-review/heating_routes_exact.json --out tmp/heating-review/heating_interfaces.json
python tools/build_v2_heating_branch_supports.py --routes tmp/heating-review/heating_routes_exact.json --out tmp/heating-review/heating_branch_supports.json
$heatingBlender = 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe'
& $heatingBlender --background --python-exit-code 1 --python art/blender/scripts/build_boiler_pipework.py -- --candidate-dir tmp/heating-review/boiler-feed --receiver-feed
& $heatingBlender --background --python-exit-code 1 --python art/blender/scripts/review_heating_distribution.py -- --work-dir tmp/heating-review
& $heatingBlender --background --python-exit-code 1 --python art/blender/scripts/inspect_heating_distribution.py -- --work-dir tmp/heating-review
python tools/check_v2_heating_envelopes.py --routes tmp/heating-review/heating_routes_exact.json --native-review tmp/heating-review/native/native_review.json --out tmp/heating-review/heating_coupling_envelopes.json
& $heatingBlender --background --python-exit-code 1 --python art/blender/scripts/export_heating_distribution.py -- --work-dir tmp/heating-review
```

Stop on a failed command or nonempty failure list. Review the rendered images
before export. The review builder accepts optional capture names after the
work directory, such as `steam_receiver riser_branch_ports`, to avoid repeating
unchanged views. The inspector opens the saved Blender file; the exporter
requires its successful hash-bound inspection and checks an actual glTF
round trip. Neither grants runtime acceptance.

The exported distribution uses normalized catalogue UVs. Its eventual Godot
material must use UV scale one, disable triplanar mapping and retain mipmapped
filtering. The existing boiler feed has a separate UV convention and asset.
The distribution requires `meshes/force_disable_compression=true`: the
standalone import experiment found collapsed UV triangles with compression.
Register this exception in the production import policy when installing it.

The assembly includes main bands, branch hangers, floor sleeves, blind caps
and section-count-specific radiator tailpieces. Coordinate visible floor,
shaft, ceiling and soffit interfaces in the composed world. Floor collision boxes alone do not establish
solid construction throughout their volume. Preserve walking collision and
the existing HeatBalance, radiator and boiler authorities. The proposed
floor and shaft cuts are installed layout edits requiring renewed verification.

Then bind source plans and native assets, install the assembly, review it in
the composed world, exercise affected access and mechanics, and obtain the
required test-authored runtime contracts and gate comparison. Human visual
and listening acceptance remain separate. Ventilation and acoustic ownership
tools in this batch also produce candidates; they do not install a new graph.
