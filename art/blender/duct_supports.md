# Existing ventilation branch supports

Evidence class: **INERT**

The production inspection showed exposed 180 mm bathroom/staff duct branches
without hangers. This batch adds static period steel trapezes at supported
stations. It retains all 23 register locations, four physical duct stacks,
roof ventilators, automatic motors, service isolation and acoustic emitters.
It does not close the full architecture or shared-infrastructure phase.

## Source, inference and ownership

**completion_interiors.json** owns the four stack assignments and branch axes;
**orison_v2_blockout.json** owns the register anchors, floor datums and 3.00 m
clear height. Registers sit at floor + 2.60 m; their existing branch centres
are + 2.69 m. **orison_v2_ventilation.gd** retains all original sheet-metal
sections, seam bands, plenums and physical colliders.

The attachment detail is an **INFERRED** construction fitting required by the
existing exposed routes. **build_duct_hanger.py** authors an editable steel angle,
two 6 mm rods, 90 × 68 × 9 mm ceiling plates, washers, hex nuts and four anchor
heads. The angle's flange top is 90 mm below the branch centre; ceiling plate
tops are 310 mm above it. It is a visual attachment, with no extra collider,
maintenance interaction, service state or second simulation.

**orison_v2_duct_supports.gd** resolves the actual built wall/riser bearing boxes
and floor/ceiling bounds. It samples horizontal branches at up to 1.20 m spacing,
omits fully enclosed stations and places rods only where both plates meet
existing overhead fabric. It does not hang fittings in court/chase gaps to meet
a numeric census. The final roster is **A 5 / B 9 / C 36 / D 15**, **65** total.
Existing vertical risers and roof branches remain as authored; their concealed
fabric and penetrations require further inspection, not a claim of fabricated
hidden pipework. The fitting's lowest point remains over floor + 2.57 m.

## Blender export and production views

**art/blender/duct_hanger.blend** is **109,597 bytes**;
**game/assets/props/duct_hanger.glb** is **71,188 bytes**. Two shared imported
mesh partitions use existing **metal** and **cast_iron** MatLib keys. The four
stack owners add eight MultiMesh draws, without per-fitting nodes or new
collision bodies. The asset has explicit triangles, outward normals, active
metre-projected UVs and exported tangents. An early non-triangulated export
warned about tangents; that prototype was regenerated before acceptance.
The first candidate's scale assertion also required a 30 mm edge on the
24 mm nuts and ignored compressed-UV rounding. Independent inspection found
only **21.75 / 27.78 micrometre** edge excess in Godot, while the exported GLB
retained unit scale. The corrected assertion checks real edges above 10 mm,
50 micrometre rounding and 0.5% scale tolerance; it still rejects missing,
enlarged or uniformly shrunken active UV mapping. The failed receipt is retained.

Directly inspected production views include ground north and staff branches,
the second-floor south register, third-floor east and fourth-floor west.
**tmp/duct-supports/before** and **final-views** retain seven matched camera views;
the original south camera looked at an obstructing wall, so its image cannot
prove that register. **support-test/south_second_register.png** supplies the
correct additional player-height view. Roof A/D views preserve their original
dark production lighting and sealed curb/fabric; they do not reveal hidden
roof ducts. No inspection fill or lamp-energy change was introduced.

| Matched view | Before / after multipass draw counter | Before / after process sample, ms |
|---|---|---|
| Ground north | 25,858 / 27,470 | 157.18 / 179.19 |
| Obstructed south | 21,169 / 20,866 | 157.18 / 247.99 |
| Third-floor east | 6,245 / 2,443 | 311.62 / 341.28 |
| Fourth-floor west | 20,363 / 24,859 | 280.13 / 311.67 |
| Staff | 18,450 / 16,257 | 240.97 / 291.04 |
| Roof A | 21,763 / 19,908 | 294.46 / 335.32 |
| Roof D | 898 / 906 | 290.52 / 309.20 |

World startup samples were **20.61 / 18.83 s**. These single samples include
residency, shadow/mirror passes and capture overhead; their variance exceeds
the eight added draws. They establish representative observations, not stable
FPS or a speedup. No pipeline extension is adopted from these numbers.

## Checks, gates and open work

**OrisonV2DuctSupportTest** checks actual imported bearing/plate triangles,
independent rendered ceiling triangles, original duct collider contacts,
headroom, both material partitions and active mapping. Published source
**7b75755f6bb3e3b82686f3007badac11e3ccd882** passes **395 checks**, **65 stations**,
eight batches and zero failures. The complete clean candidate proof is
**tmp/duct-supports/verified-final/verification.json**: both imports bind,
CityComposition passes 1,253 checks/450 contacts, existing ventilation behavior
passes 23 checks and the continuous roof route passes 51 waypoints, all with zero
failures. Gate regressions and reader NEW are zero; protected paths are 17/17,
selector V2 and ledger counts unchanged. The candidate was pushed to main.
Wrapper receipts and these captures are INERT; they grant no ledger runtime proof.

The full clean baseline is **tmp/arcade-thresholds/4cbed73-clean-board.json**.
The batch adds one individually reviewed generated fitting-name reference to
the previous **6,334** spatial records and refreshes the INERT fabrication index.
Require zero gate regressions, reader NEW **0**, protected **17/17**, unchanged
selector rollback and unchanged completeness counts **[7,8,127,42,151,153]**.
The resident originals/copies and saved door locks, News Cigars initial unlock,
gentler waking lamp, boiler pipework/swing, V1 and owner capture files remain.

Next inspect concealed stack/slab penetrations, exposed heating distribution,
water/drain terminations, power/conduit and retained bar/shop services. Accepted
fixtures and roof machines remain in place. Broader decorative polish is open.
