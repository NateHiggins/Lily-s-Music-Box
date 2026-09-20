# Apartment storage, tables and boards

Source integrated; runtime pending. No Godot launched.

Ten pieces across all four detailed apartments:

| Category | Placement |
| --- | --- |
| Four wall cupboards | One above each kitchen sink/work area in 2A, 2B, 3B and 4B |
| Two coffee tables | 2A and 4B main rooms, clear of existing sofa/working stances |
| Two pinboards | Above 2A's bedroom writing desk and 2B's fabric worktable |
| One toolboard | Above Omar's 3B workbench |
| One parts crate | 3B main-room corner clear of the radiator approach and room routes |

This brings the furniture dataset to 57 pieces, plus the existing 19 small
surface props and 20 functional household fittings. The new batch contains
1,116 triangles in 23 material surfaces, ten semantic anchors and ten static
collision boxes. Counts describe source geometry, not measured frame cost.

The cupboards preserve only the authored kitchen assembly's upper carcass,
doors and handles. The extractor excludes the lower sink-cutout assembly and
normalizes the upper cabinet to a 0.70 m local height. It mounts at 1.65 m above
the floor, backed by an uninterrupted wall and clear of the existing taps.
4B uses a new household variant of the same 2A cabinet design. Component metadata
and the current apartment inventory identify this partial transfer explicitly.
The three original kitchen aggregate records remain listed as incomplete:
their upper cabinets are mounted, but their lower cabinetry needs a separate
decision around the already integrated sinks, stands and appliances.

Coffee tables and boards use the existing authored assemblies. Coffee-table
geometry is raised by its small negative visible base offset so its fins meet
the floor; other local dimensions and material identities are preserved. Their
glass uses the existing lamp optical glass shader and haze receiver. Collision
remains a conservative solid furniture box, so the visual open space beneath
the tables does not imply matching leg clearance or glass transmission through
the voxel collision field.

Timber and plywood now participate in the shared runtime material contract.
The generator resolves their existing canonical albedo, roughness and normal
textures and physical scales through the catalog. No textures were generated,
no existing material settings changed, and no visual locks were added. There
are 51 runtime material keys, up from 49. The cupboards retain painted trim;
the boards/crate retain their timber and plywood identities rather than
receiving generic wood colours.

Source verification:

- Ten reproducible geometry records with finite triangles, known materials,
  valid bounds and preserved previous furniture records.
- Seven wall-mounted pieces have solid backing at their full width and height,
  with clearance from authored apertures. Their mounting gaps are at most 25 mm.
- Three-dimensional bounds clear other furniture, conservative fitting/radiator
  bounds, switches, separately owned case tables and visible surface props.
- All existing declared standing points clear the additions. 6,876 sampled
  points cover prepared 2A/2B player routes, Mina's home graph and case/3B/4B
  circulation spines. All 17 domestic/service door specifications clear the
  additions through 201 samples of each 100-degree leaf sweep.
- Existing seating, lighting, apartment-door, wall and surface-prop source
  checks pass. Lighting's receipt now includes the newly present obstacles.
- Prior 47 furniture records, prior layout records/anchors, all 49 existing
  material definitions, fixtures, surface props, circuits, case placement and
  Mina's route data are preserved. Re-running both generators changes no bytes.
- The three changed GDScript files parse with the independent syntax parser.
  This does not establish Godot type checking or execution.

Prepared apartment composition checks cover the new category roster, cupboard
height and absence of a phantom lower cabinet collider, canonical wood texture
triplets and the coffee glass shader. Existing repeated-world/active-tween
teardown coverage includes all ten furniture bodies. These engine checks have
not run. The generic material-library test also covers the two new definitions
when Godot is available again.

Reproduce source checks with
`design/astra/work/v2_storage_tables_boards_batch_01/validate.py`. It invokes the
category generator and material-contract generator without launching an engine.
The category generator accepts `--apply` and rejects conflicting existing IDs.
The component-aware inventory remains at
`design/astra/work/v2_apartment_seating_batch_01/apartment_inventory.json`.

These are fixed cupboards, boards and a crate; their displayed doors, tools and
contents do not add opening, removal or inventory mechanics. Actual passage,
targeting, materials, optical response, lifecycle and performance remain pending.
V1 remains default; V2 is incomplete and S2J remains open. Remaining apartment
source assemblies include three kitchen aggregates, three television cabinets,
the reel deck and the bench radio. Runtime media/interaction owners must be
integrated along with those devices. The other twenty source unit IDs still
need detailed V2 room programs, and the remaining building levels, services,
persistence and runtime/visual acceptance are not complete.
