# Tessellate cloudy-tissue integration

Canonical Astra worktree, base 710a12b. This closes the missing authored consumer
for cloudy interior transport in the preceding lamp-shadow packet. It does not
supersede failed S2J or approve the whole game's art or V2 release.

## Production change

The existing Tessellate wine-body triangles now use a 24-step single-scattering
material on Forward+. The original solid feet, head, eyes and gold triangles
remain opaque. Opaque depth terminates the interior ray, so the existing parts
that enter the body provide depth-separated silhouettes. No organelle geometry,
creature, ecological owner, or extra MultiMesh batch was invented.

The volume uses lamp-to-sample absorption, sample-to-eye absorption, a forward
phase function (g=0.35), and the same shared optical field as the other Dream
materials. Extinction is 6/m, with a restrained surface coat. Lamp-off skips the
24 optical fetches and retains tissue opacity. The affine optical ellipsoid
follows all eight existing Tessellate postures; the original vertex program
remains the sole writer of vertex positions.

The mesh is partitioned once during world construction. Both partitions retain
identical packed vertex/attribute data, and their index sets cover the original
268 triangles exactly once in the original winding. This avoids a second lossy
normal/tangent encode. The existing five MultiMesh batches and instance records
remain; six invisible material bindings replace five. Compatibility rendering
retains the original opaque material. The other four fauna families retain the
original shader math, verified against the previous commit after removing only
the conditional tissue additions and whitespace.

## Verification

- dream_final: 48 checks, zero failures; real Dream root binds all four shader
  families, and field/off/failure/retirement controls pass.
- glass_final: 25 checks, zero failures; streamed optical receiver lifetimes
  include the new tissue family.
- fauna_final: 29/29; original cached geometry signatures, ecology, instance
  channels, binding discovery and exact Tessellate partition pass.
- composed_final: 44 V2 composition, profiling and teardown checks pass.
- partition_03: exact 268-triangle and all vertex-array comparison passes.
- visual_final: actual populated Dream scene, cloudy/opaque/restored/repeated
  views, interleaved GPU comparison and lamp-off capture; no proof creature.

147 scoped checks pass, including the exact partition test. All final stderr files are empty. The electrical-state SHA256 remains
ffda7e1f985e72ceb18b62d2959a9cd13c743bfba653b31d2be74ab6e82e8604.
DreamExposureField is unchanged. Runs used the unchanged exclusive Godot runner.

Earlier failures are retained: dream_01 exposed invalid shader builtin scope
and a null source index array; partition_01/02 exposed normal/tangent
requantization; fauna_01 exposed mixed indentation. None count as passing.
The final sources correct those failures. Earlier visual runs explored opacity
and revealed timing drift; they are not final performance acceptance.

## Material performance

At 1280x720 on RTX 4080, 32 warmed ABBA blocks (12 settle frames, 12 measured
frames each) give eight material deltas: 0.286, 0.277, 0.266, 0.534, 0.237,
0.368, 0.387 and -0.080 ms. Their median is **0.281 ms**. The negative pair
shows remaining timing noise. Both two-surface variants report 213 draws and
1,677,495,776 video-memory bytes; these are whole-scene counters, not a claim
that splitting the old single surface adds no storage/draw work. Raw samples
are in visual_final/profile.json. No runtime readback is added by the material.

## Combined V2 performance

The same 32-block ABBA method in the actual V2 composition estimates a median
0.867 ms main-plus-depth-view delta. Separately measured room/near field
injection medians are 0.0295/0.1676 ms, giving **1.064 ms estimated combined
median overhead** in this view. This meets the preferred 2 ms median target.
Eight view deltas range from -1.079 to 2.396 ms; the negative pair and positive
outlier prohibit a worst-case guarantee. This is not full-game performance
acceptance. Construction median/p95/max: 16/23/32 us; submission: 4/5/38 us.
Raw GPU series and injection timings are retained under composed_final.

## Scope and remaining acceptance

The interior's ellipsoid is an optical approximation beneath the unchanged
faceted surface. Camera-inside and arbitrary overlapping transparent volumes
are not proven. The existing feet are visible at different depths; this does
not claim newly authored internal anatomy. Other native materials retain their
PBR, transmission and shadow paths from the preceding material packets.

GPU time is engine-reported, not CPU wall time. Main-view timing excludes the
separate lamp-depth viewport and field generation; their preceding packet has
separate measurements. Interleaved material comparisons measure this material
change only, not total optical-feature overhead or a whole-game frame budget.
No claim of exact image restoration is made: unrelated world shader TIME keeps
advancing during the capture. The V1 selector default remains unchanged.

The light now has integrated scene-carved room/near voxels, air/dust response,
material spectrum, thin transmission, native opaque/wet/metal/fiber response,
glass haze, and this actual cloudy-tissue consumer. Human visual acceptance,
worst-case/full-game performance acceptance and the broader V2 completion remain open.
