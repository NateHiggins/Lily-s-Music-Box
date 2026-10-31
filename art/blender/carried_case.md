# Carried case: forward-opening dispensary valise

Evidence class: **INERT**. Native Blender delivery, 2026-10-30. No Godot, commit or runtime/artistic acceptance.

The owner explicitly chose a true forward-opening shelf after reviewing the original single-lid contract. The first-pass helpers, grid, eleven form names/footprints and catalogue pipeline were retained and improved. The fold-down panel itself is the inventory shelf; the lined pharmacy-style body remains upright behind it. This is an original worker's repurposed dispensing valise, not a replica or new medical gameplay system.

## Required Godot integration change

**Do not use the previous negative104-degree suitcase animation.** JSON keys, schema version1, asset path, cell/grid and form sizes remain unchanged, but the owner-approved mechanism changes these semantics:

- **Tray** now means the fixed cabinet body. All its mesh coordinates are baked in the case frame.
- **Lid** now means the forward-opening shelf. Vertices are in the CLOSED pose relative to **hinge = Godot(0,0,-0.155)m**. Mesh object transforms remain identity in the GLB.
- Open the shelf **+104 degrees about X**. The body's14-degree presentation lean makes the deployed shelf horizontal. Its lining floor remains exactly **GodotY=0**, grid centre(0,0,0), interior0.50 x0.30m; cells remain0.05m and10 x6.
- Four additional moving assemblies must be bound: **Stay_Port_Upper**, **Stay_Port_Lower**, **Stay_Starboard_Upper**, **Stay_Starboard_Lower**. Each link is0.200m long along local Godot+Y, pin axesX. They are raw local meshes, not preposed stock. There is no exported animation; the existing inventory owner drives the mechanism.
- Keep forms attached to the shelf during opening, or hide them until settled. For a grid-world transformG, use **shelf_open.affine_inverse() * G** beneath the Lid node, where shelf_open is(TranslationH,RotationX+104deg). This preserves their existing world placement when fully open. Apply the same conversion when moving/turning goods; do not silently change the grid.
- Move the runtime contents label off the Lid and onto the fixed case root. Card writing-face centre is **(0,0.04862055,-0.25761035)m**, normal **(0,0.24192190,0.97029573)**. Its writing aperture remains **0.170 x0.084m**, centred72mm from the body hinge baseline. RotationX **-14deg** aligns a normal Label3D with the face; offset it0.3mm toward the reader. For left alignment start nearX=-0.080m and fit the text inside the aperture. No lettering is in the asset.

For the stays, all vectors below are Godot case-local. LetH=(0,0,-0.155), A=(0,0.208,-0.280), B_open=(0,0.004,0.060). At opening anglea:

```gdscript
var b = h + Basis(Vector3.RIGHT, deg_to_rad(a - 104.0)) * (b_open - h)
var d = b - fixed_a
var c = (fixed_a + b) * 0.5 + Vector3(0, -d.z, d.y).normalized() * sqrt(0.2 * 0.2 - d.length_squared() * 0.25)
```

Upper link runsA->C atX=-0.286/0.286 for Port/Starboard. Lower runsC->B atX=-0.283/0.283. Set each basis with **Quaternion(Vector3.UP,direction)**. The knee pin bridges the two layers. Clamp opening0..104deg; native105deg overtravel hits the actual stop lugs. Measured endpoint pose matrices are in the external **case_mechanism.json**.

The old consumer's0.003m FLOOR offset is separate from this geometry's floor0; review that offset. The old42deg camera at(0,0.62,0.46) crops the cabinet's top. The exact42deg diagnostic is retained; a64deg overview shows the complete case from the same position. Camera framing, real text fit, interaction, pause/teardown and final loaded materials remain with the Godot agent. No runtime file was changed here.

## Construction and surfaces

The stationary body has90mm nominal internal depth, leather-clad board, a gusseted linen pocket, two buckled straps, four empty instrument loops and the brass-framed blank card. The front panel has an8mm floor build-up (6mm board plus2mm lining), a low12mm edge return and the actual stitched inventory squares. It has exterior reinforcement bands, saddle stitching, riveted folded0.8mm corner caps, slotted closure receivers and a stitched repair. A fixed top handle carries through seated saddles into the hood. Two equal-link brass stays have bored bearings, captive pins and positive knee stops; reliefs in the body ends receive their shelf-side mounts during closure.

Envelope in the tilted presentation frame: approximately **576 x380 x183mm closed**, **576 x380 x496mm open** (width xheight xdepth, including handle/stays). The manufactured body itself is rectangular in its own leaned frame; the larger projected closed depth includes that lean. Grid and footprint dimensions remain independent of the outer case.

**24,404 triangles, 40 material partitions, 1,114 individually editable closed stocks,17 assemblies.** Eight existing keys only: leather_worn, brass_dull, brass, fabric_warm, linen, paper, bakelite_black, milk_glass. All use their registered albedo, roughness and OpenGL normal maps. The rust fabric uses a0.14m per-use tile through the existing parts[].tile field for a finer case lining; other keys retain their catalogue tile scale. Metric UV coordinates remain in metres. No new/recoloured atlas, photo pixels, letters, numbers or logos. The dark phenolic bottle follows documented pharmaceutical Bakelite examples; the lying valve has four separately visible contacts. The valve's milk-glass finish is an opaque palette surrogate, not a claim of clear-glass internals.

Eleven original forms remain: bottle1x2, tin1x1, box2x1, packet1x1, flat2x3, tool1x3, roll1x1, jar1x1, card1x1, valve1x2, parcel2x2. Their origins are footprint centres at the floor; none crosses the2mm safety margin or50mm height limit. Bottle/jar/valve/roll lie down. Cartons/envelopes have folds, the screwdriver has a shaped blade/ferrule/phenolic grip, and the parcel has wrapped ears and a real tied cord. Blank labels are geometry with the paper finish; runtime owns text.

## Rebuild, inspect and review

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' -b --python-exit-code 1 -P art/blender/scripts/build_carried_case.py
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' -b --python-exit-code 1 -P art/blender/scripts/inspect_carried_case.py
```

Run fromC:/ov/shops. The builder uses two CPU threads and20 samples. It writes only the authorized blend/GLB/JSON and external review outputs. **01_EDITABLE_MANUFACTURING_STOCK** retains individual stocks; **02_CONTRACT_EXPORT** contains the identity-transform batches; **90_REVIEW_ONLY_NO_EXPORT** contains posed copies, light and camera. Native opens in the reviewed open pose. Hide the review/export collections and enable the stock collection to edit construction.

Final native checks: closed positive-volume stocks; exact names/JSON keys;1,166 legal/turned closed-case goods placements with **27.20mm** minimum sampled clearance; all ten front-row centres visible from the player eye;105 shelf/stay poses with no unintended intersections; attachment error below **7.45e-08m**. An original85mm front-wall control blocks all ten row centres; oversize form and105deg stop controls reject invalid configurations. UV scale is **0.999819–1.000137metres/unit**; final exported tangent agreement is at least **0.999999958**. The GLB has40 mesh nodes, no embedded images/materials, cameras, lights or animation. Runtime must bind the finishes and pose the mechanism.

Reviewed outputs in **C:/ov/reports/claude30/shops/review/**: **case_player.png** (exact42deg consumer camera), **case_player_full.png** (64deg overview), **case_top.png**, **case_closed.png**, **case_forms.png**. The form sheet normalizes each item to about200 pixels and is not a relative-size comparison; order is the FORMS order above, four columns. Earlier rejected/superseded renders and winding/budget/receiver-sweep logs remain identified by filename. Native evidence: **case_build.log**, **case_inspection.json**, **case_mechanism.json**, **case_dimensions.json**.

No Godot was run and nothing was committed. No shader/catalogue/import/runtime owner was modified. Loaded mipmaps, real Label3D readability, drag/rotation hit-testing, goods animation attachment, clasp release behavior, player hands/carry pose, persistence and performance are unverified. Native geometry checks do not prove runtime or artistic acceptance.

## Period research informing form

These are references, not objects to copy or historical claims about the player's own case. No reference-image pixels enter the model/maps.

- **The Henry Ford, Veterinary Pharmaceutical Kit,1910-1920,81.59.27**: a leather medical kit with metal, glass, cork and rubber components. Supports a compact, repairable fitted-kit vocabulary. [Primary collection record](https://www.thehenryford.org/collections/explore/artifact/542539).
- **Science Museum Group, Lord Curzon's medicine chest,1910-1925,1981-1008**: leather, brass and glass;300 x350 x140mm overall. Supports the pharmaceutical chest character, lined compartments and protected medicine containers. Our much larger grid case is an adaptation. [Primary collection record](https://collection.sciencemuseumgroup.org.uk/objects/co196847/lord-curzons-medicine-chest-england-1910-1925).
- **Science Museum Group, Hamilton Rice expedition chest,1900-1919,A700005**: fitted storage and documented Bakelite medicine bottles suit Orison's material language. Its aluminium shell does NOT override the Bible: our case remains leather-clad board and brass. [Primary collection record](https://collection.sciencemuseumgroup.org.uk/objects/co201366/tabloid-medicine-chest-used-on-dr-hamilton-rices-amazonian-expedition-in-1919-england-1900-1919).
- **Horace Goldin, US873855A,1907**: describes a valise with recessed unfolding shelves, bracket rods and supporting tapes. Establishes that a shelf-converting case is a period design idea; it does not establish common medical use in Queens. Our single forward shelf and folding stays are an original adaptation. [Patent](https://patents.google.com/patent/US873855A).
- **Talbot Medical Museum, Eli Lilly sample case,c.1890-1930**: the museum describes pharmaceutical sample cases being reused on house calls. Supports a worker's repurposed dispensary case, rather than a newly issued luxury suitcase. [Primary collection record](https://museum.wkhs.com/collections/medicine-in-the-new-south/drug-salesman-sample-case).

