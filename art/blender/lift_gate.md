# Editable lift-gate source

Evidence class: **INERT**

The native authoring source is `lift_gate.blend`, retained from reviewed delivery28:
155 editable construction stocks and16 physical-metre export templates. Keep
`20_EXPORT_LIBRARY` separate from the posed review copies. The retired generator
made three normalized primitives; it must not replace this source.

Regenerate with Blender5.2 from the repository root:

```powershell
blender -b --python-exit-code 1 -P art/blender/scripts/build_lift_gate.py
```

Pass `-- --out <private path>` to verify without replacing the installed GLB.
This CPU-only export performs no render or Godot launch. The script rejects
linked/evaluated export dependencies and requires the authored corner attributes.
`lift_gate_export.py` preserves exact final normals/UVs, derives tangents from
the actual float32 buffers, deduplicates exact matching corners and runs the
repository tangent validator. Only the16 library meshes are exported; review
cameras, lights, preview textures and posed copies are excluded.

The initial canonical re-export is byte-identical to delivery28:
`20fc8450c2e72c503b3556d1f0ebe5b2ffa4622f7b849328b241d6107fa1189b`.
There are20,986 library triangles. This is a reproduction oracle, not a hash to
repin after legitimate edits: edit the native stocks/templates, export again,
then renew affected geometry, articulation and surface evidence.

Runtime `orison_v2_lift_gate.gd` places120 instances in16 batches. Native coordinates
convert to Godot once on export. Links, pins, rollers and rails remain unit-scale;
only the presentation root cancels the original gate owner's X squash. The owner
retains door fraction, travel, stops, interlocks, sounds and saves. The existing
cabin body receives exact lower-stock triangle contact from the native mesh;
there is no second collision or elevator authority.
Private brass samples metre UVs at the catalogue scale through existing finishes.

Qualification is separate from generation. PR293 merged as75c578d0d after
native630 articulation samples/four reviewed views, retained local passenger35
real-input rail crossings, and current composed cycle/disk/cost111/0. Both native
rebuild snapshots match exactly, including120 transforms and lower-stock faces.
Loaded surfaces pass754/0 with20 technically reviewed captures. The lower rail
remains62mm above the finished floor; contact belongs to the existing cabin body.

Matched-import old/new/old cost records actual3/16 visual families, including
material/UV differences: wall medians within the control drift, small GPU increase.
No whole-game budget pass, cold-start comparison, human play or artistic acceptance
is granted. Current V2 has no NPC lift consumer, registered landing apparatus or
public live-reversal operation; those scopes remain explicitly NOT_RUN. Existing
busy-request/service-door refusals and normal reverse-direction travel are proved.
Original failures and exact source-bound receipts remain under
**C:/ov/reports/lift_gate_intake_20261115/cycle_06/**; see HANDOFF for integration.
