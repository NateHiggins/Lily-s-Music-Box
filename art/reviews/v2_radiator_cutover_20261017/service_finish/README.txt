Evidence class: INERT. Local WIP radiator finish/contour diagnostics.
2026-10-17. Not integration or human appearance acceptance.

The previous 2B union capture had broad bright bands that read as varnished
wood. Its fittings used the door hardware's bright buffed-brass maps. A new
registered radiator_service_brass finish replaces those bindings only on the
radiator union, valve, vent and inserts. Existing door materials are unchanged.
Its periodic 512-pixel maps cover 40 mm, with independent quiet alloy colour,
roughness and 0.00068 mm RMS microrelief. Native and runtime normal strength is
1.0; metallic response is 0.92 and the authored roughness map is unattenuated.
No large dirt marks, baked lighting, lettering or photographed pixels are used.
The preliminary grainier material views are retained as a rejected appearance
iteration; the final height amplitude is smaller at its actual physical scale.

The material is registered in gen_layout.py, material_catalog.json, catalogue
mapping, the generated 83-key runtime contract and GODOT_STAGE. Procedural
staging now resolves the mapped procedural source directory rather than
looking for a nonexistent AI source directory. No AI SLOTS source is invented
for this mathematically authored material. Three shipped maps use the same V2
compression/mipmap policy; all 1,253 building texture sidecars pass that policy.

The catalogue persistence audit also found twelve already shipped tile, door,
faucet, washer and radiator finish keys absent from gen_layout's source dict.
Regenerating the catalogue would silently retire them. Their current definitions
are now preserved in that source; no runtime material is changed by this repair.
tools/tests/test_material_catalog_persistence.py compares the actual source
assignment with the full registered catalogue without running its world-data
writer. The normal gate board discovers this regression test automatically.
catalog_gate/board.json records its focused gate-board execution: one test,
PASS. This is not a full gate board or merge-base regression comparison.

Native modeling
The vent body and sealed float used coarse 24-sided ellipsoids. Native Blender
preparation now rebuilds both actual closed shells with 64-sided contours and
32 rings, preserving their chamber/inlet/needle datums and object frames.
The cap receives a 0.2 mm, three-segment edge break. This is real mesh detail,
not a smoothing proxy. Needle/seat and five orifice route checks are repeated
against the changed native meshes. One microscopic Boolean edge near the
cone/stem joint is collapsed; the strict physical UV/tangent checks stay intact.
Vent cap thread geometry and physically correct thread pitch remain OPEN.

production_manifest.json: mechanism export 134,066 triangles, twenty
primitives; vent export 25,422 triangles. Both pass strict final-float32 tangent
checks (minimum agreement over 0.99999995). Native vent fit passes 82 checks,
including closed shells, the nested cavity's inward normals, needle seat and
routed air. retained_buffers.json proves exact indices, vertex/UV/normal/tangent
and morph buffers for all nineteen union stocks and five orifice inserts,
allowing only the explicit door-to-service-brass material replacement. All
exported object frames remain unchanged. Only the two changed families are
installed; wall-support and shim exports are not replaced.

Native validation failures are retained: UV density exposed a microscopic
cone/stem sliver; broader vertex welding did not solve it; targeted edge
collapse did. Rebuilt mesh data initially lacked its original material slots;
those are now explicitly retained before catalogue rebinding. The first vent
render wrote its relative output path under C:/tmp; its actual PNGs were copied
into the review directory, and the render helper now resolves its output path
before loading a blend. No unrelated directory was deleted.

In-game diagnostics
service_brass_import: completed exit zero. Initial service_brass_hand printed
PASS with 470 surface checks, but its receipt/stderr correctly reports one
script error: the old insert-bank validator compared boolean version true to
integer 1 before checking its type. The previous orifice_stock packet had the
same error; its README now corrects the earlier erroneous error-free claim.
The original receipts remain unchanged. This initial run is NOT clean proof.

The validator now checks the version type before numeric comparison. Direct
stock restore also releases its latched radiator hand, rather than leaving the
radiator busy after the part's ownership was revoked. service_brass_hand_strict
completes exit zero with 470 surface checks, twenty inherited pose cases, no
failures, no script errors and empty stderr. It adds actual cursor acquisition,
direct restore while held, and validation of both part and radiator release.
Existing cap/needle, physical exchange, walking carry and JSON tests pass.

service_brass_world: completed exit zero; 1,133 checks, zero failures, no script
errors. Startup 95,508.9 ms. It verifies the installed finish and loaded mips,
radiator controls, rack wall bearings, retained physical fuse repair, rating
refusal and load proving in one composed world. This run preceded the validator
type-order/held-restore correction; its ordinary numeric-version composition
and unchanged art evidence is reused, while the changed guard/restore branches
are covered by the later strict bench. No full-world rerun for those branches
is claimed. The same seven-Texture-RID shutdown warning persists.

service_brass_hand_visual repeats the strict bench with two additional close
vent-exterior lamp-off/on captures: completed exit zero, 470 surface checks,
twenty pose cases, zero failures, zero script errors and empty stderr. Both
frames and its open-chamber view were individually reviewed. Eight final native
frames and nine composed radiator/rack frames plus the fuse completion image
were individually inspected. Native views cover neutral diffuse/grazing light,
assembled vent and its exposed chamber. The final room views reduce the obvious
directional bands. The smoother vent silhouette and darker fitting finish are
visible in the game, but do not establish photorealism or every-surface coverage.
Appearance remains subject to human acceptance.

Remaining work
Physical sliding shims/continuous pitch, the radiator repair-completion
endpoint through retained work-order/case/NPC authorities, disk reconstruction,
broad regression/candidate qualification, the texture shutdown warning, cloth
realism, visible cap threads and the rest of V2 remain open. The native player
minigame entry stays disabled while its replacement is unfinished. Wrapper
receipts and captures are not schema-2 runtime_contract evidence. No completion
ledger status is promoted. Historical packets keep their original source pins;
source_inputs.json binds this stage's final inputs only.
