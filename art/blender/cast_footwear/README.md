# Selected resident footwear sources

Evidence class: **INERT**

These are the eighteen footwear parts worn by the current diner presentation.
Only ankle weights change in their runtime exports. Indexed position, normal,
UV and tangent corners, material inputs, all76 rig/rest/inverse-bind records and
protected Toe/other weights retain their admitted values. This does not qualify
alternate outfits, all character poses or artistic acceptance.

Each person has a small editable **control.blend** and **repaired.blend**, with
the selected footwear and its existing rig. Texture links point into the game's
shared PBR files. The **original/** glTF/bin pair is required source: it preserves
the original named-weight references and, for Omar and Iris, admitted tangent
guides. It is not a disposable duplicate of the repaired runtime asset. See
**source_manifest.json** for exact paths, hashes and per-person export flags.

The controls derive from retained Wardrobe9/31 native meshes plus current PBR.
Omar and Iris additionally recover the admitted UV corners onto that native
geometry; their export guide preserves tangents after exact oriented P/N/UV
correspondence. These are explicit source repairs, not a claim that the old
builder reproduces current exports without them. No emitted glTF is hand-edited.

## Rebuild one part

Use Blender5.2 and a fresh private output directory. CPU-only authoring/export
does not render. Actual Blender renders and all Godot verification use the
shared FIFO lane and hidden desktop according to AGENTS.md.

For example, with **REPO** set to the checkout's absolute path:

```text
blender --background --python-exit-code 1 --python REPO/art/blender/scripts/cast_footwear/author_footwear.py -- --control REPO/art/blender/cast_footwear/peter_wren/control.blend --output PRIVATE_REPAIRED.blend --part b_feet
blender --background --python-exit-code 1 --python REPO/art/blender/scripts/cast_footwear/export_footwear.py -- --repo REPO --original REPO/art/blender/cast_footwear/peter_wren/original/peter_wren__b_feet.gltf --control REPO/art/blender/cast_footwear/peter_wren/control.blend --repaired PRIVATE_REPAIRED.blend --output FRESH_PRIVATE_OUTPUT --person peter_wren --part b_feet --pbr-dir REPO/game/assets/characters/cast/peter_wren
```

Use the manifest's person/part. Add **--preserve-unchanged-native** for Sacha,
Omar and Iris; add **--tangent-guide** for Omar and Iris. The exporter refuses an
existing output directory. It writes separate control/repair outputs and exact
PBR staging copies; receiving installs only the reviewed glTF/bin pair.

The native authoring transfers same-side Leg weight into Foot below the ankle:
full transfer at restFootjoint minus5mm, smoothstep fade to zero transfer at
plus25mm. Toe and all other groups remain unchanged. The prewriter protects
their canonical float32 weights and reconstructs only Foot/Leg from the native
authored ratio. Unchanged native rows remain exact where the manifest requests it.

Merging two float32 components into one can slightly change a row's sum error.
Check each original Foot/Leg total against the sum of the new components'
half-ULP rounding budgets, and the new sum error against the old row error plus
that budget. Preserve any earlier raw maximum-cap failure; do not reinterpret
this numerical bound as a physical penetration tolerance.

Before receiving a changed export, verify all indexed corners, topology,
76-bone rig/binds, protected weights and shared PBR bytes. Then inspect actual
weighted shoes against the complete native footrest, counter and seat, including
the whole sole and boot shaft. A reachable anchor alone proves neither contact
nor clearance. Imported UNORM16 rows can sum to65534/65535: classify rigid soles
by every positive named influence, not a near-one weight-sum threshold. A level
support follows gravity rather than the rig's leaning pelvis-to-neck axis.

Standing/walking, gameplay service/save behavior and loaded surface checks have
their own evidence. Keep original failures and require new evidence for changed
consumed inputs; do not repin an old receipt after rebuilding.
