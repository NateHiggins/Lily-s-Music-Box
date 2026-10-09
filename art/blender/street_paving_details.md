# Native street paving details

Evidence class: **INERT**

**scripts/build_street_paving_details.py** reads the 20 exact street records
selected by **art/data/v2_import_resume_20261008/resume.json**. It retains the
original source and emits **street_paving_details.blend**, its GLB, runtime
material/part table and construction fixture. **ClosedConstruction** preserves
186 editable positive stocks; **Exports** holds 20 metric-chart groups.

**scripts/inspect_front_pavement.py** verifies the original slab and all 24
consumed masonry masks. **STREET_WRITE_REVIEW=1** writes an explicit comparison
fixture while preserving the old pins. It never saves or rebuilds the slab.

**scripts/inspect_street_paving_details.py** reopens the new native, checks
actual supports and renders the source proxy/native pairs with retained context.
**STREET_RENDER=0** runs fit checks only; **STREET_REVIEW_OUT** sets the output
directory. The final review includes the formerly unsupported coping endpoint.

The runtime mount hides exactly 20 original environment meshes, installs their
native visuals and retains every original collision/guide/light owner. Paving
panels preserve the old top datum; small recessed panel joints retain the
continuous source floor collision. Coping fits the original physical curb.
All finishes use existing concrete maps, local duplicates and metre UVs.

Shared Godot modules are **front_pavement** and **street_paving_details**.
**ORISON_STREET_CAPTURE_IDS** narrows named captures only; all native/material,
contact, crossing and retirement checks still run. Use the lane and LogPath.
See **design/V2_STREET_PAVING_2026-10-08.md** for exact proof and limitations.
