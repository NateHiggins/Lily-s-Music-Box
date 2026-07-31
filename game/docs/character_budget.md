# Character budget

Measured on this build, not estimated. Short answer: **polygons are not your
constraint — textures are, and skinning will be.**

## The A/B

The same Meshy character, in the lobby, at the perf probe's lobby station
where she fills a good part of the frame:

| Version | Triangles | GLB | Lobby frame time |
|---|---|---|---|
| decimated | 43,518 | 7.2 MB | 11.32 ms (88.3 fps) |
| full | 217,592 | 12.2 MB | 11.41 ms (87.7 fps) |

**173,000 extra triangles cost about 0.1 ms**, which is inside run-to-run
variance. Both pass the 16.6 ms budget with room to spare.

That is not surprising once you look at what the frame is actually made of.
The lobby already draws ~6.9 M primitives in ~13,000 draw calls across
~11,000 objects. A character is one or two draw calls whatever its density,
so it lands in the cheapest bucket the renderer has.

## So what does cost

1. **Texture VRAM — the binding constraint.** Meshy hands back four 2048²
   maps per character. That is roughly 22 MB per character once compressed
   on device. Eighteen residents at that rate is ~400 MB of textures, which
   will not fit on the phone the APK targets. Budget textures first and
   polygons last.
2. **Skinning, once they are rigged.** Cost scales with VERTEX count, every
   frame, per visible character. A 217k static figure standing in a lobby is
   free; eighteen 217k *animated* ones are not. This mesh has no armature
   yet, so none of that is being paid — which means today's measurement is
   the optimistic one.
3. **Shadow casting.** A character that casts is re-rendered once per cube
   face of every light that reaches it. `lobby_placeholder.gd` switches it
   off; do the same for any background figure.
4. **Repo and APK weight.** 24 MB of source blend plus 7.2 MB of GLB for one
   character. Eighteen of those is ~560 MB, on a repo whose history is
   already ~1 GB.

## Recommendation

- **Go highest quality for the master.** Keep the full-density source in
  `art/`, always. It costs nothing at runtime and you cannot get detail back
  later.
- **Export a budget version into `game/`.** This is exactly how the building
  already works — `gen_layout.py` authors the truth, the game gets what it
  needs. `art/blender/scripts/export_meshy_character.py` takes a decimation
  ratio for precisely this.
- Heroes seen close (the six, and anyone on a call): **60–100k is fine**,
  2K albedo and normal.
- Background residents: **20–40k**, 1K maps.
- **Always drop the emissive map** unless something actually glows. Meshy
  emits one every time and on this character it maxes out at 0.012 — pure
  black, 25% of the texture payload for nothing.
- Metallic/roughness can drop to 1K almost always; it carries no detail the
  eye finds on cloth and skin.

## Regenerating

```bash
blender -b art/blender/meshy/<source>.blend \
  -P art/blender/scripts/export_meshy_character.py \
  -- game/assets/characters/<id>/<id>.gltf 0.20
```

The last argument is the decimation ratio; `1.0` exports at full density.
The script reports the bounding box, which matters: **Meshy puts the origin
at the mesh centre, not between the feet**, so anything placed at floor
height stands buried to the waist. `LobbyPlaceholder.FOOT_OFFSET` is that
measurement for this character, and it is per-character.

## Known gaps

- No armature. This is a static posed mesh, so it cannot walk, idle or be
  spoken to, and it is not one of the eighteen residents — it is a scale and
  lighting reference standing in the lobby.
- The importer logs `Invalid UTF-8 leading byte` on this GLB. Harmless —
  a copyright glyph in Meshy's asset metadata — but it is noise in every
  run and worth stripping at export if more of these arrive.
