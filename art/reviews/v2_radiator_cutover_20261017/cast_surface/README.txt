Evidence class: INERT. Scoped material diagnostics, not V2 acceptance.

Installed change
The 23 native radiator bodies and their two shoes now use radiator_cast_iron,
a separately registered custom oxide-covered sand-cast finish. Worked fittings,
brass, blackened handwheels and packing retain their own recipes. The oxide is
a continuous dielectric coating, not a mixed paint/bare-metal texture.

The deterministic source generator authors 512 px maps over a 64 mm tile,
with 0.0306 mm RMS casting relief, quiet mineral colour variation, independent
roughness, and OpenGL normals derived from physical height. Casting normal
strength is 1.0 in both native and runtime bindings. The global MatLib strength
remains 0.35; no other material's normal strength or lighting was changed.
Three compressed mipmapped runtime maps are shared by every radiator.

The distribution source plan pins the shared runtime material table. Its pin
was renewed for the added recipe only after reconstructing the exact preceding
table hash with that one record removed. The dependent native distribution
was rebuilt: 179 pipe, 771 hanger and 546 native checks pass, followed by strict
528,936-triangle tangent validation and seven-batch export/reimport. All 2,096
retained native stocks have identical frames, vertices, faces, UVs and corner
normals. The shipping distribution GLB is byte-identical, so its existing room
views were reused and no additional Godot import/capture was needed. The native
source is refreshed; old runtime/native receipts have not been re-pinned.

The Blender preparation changes two material assignments only. Native geometry
digests, the entire exported binary buffer and accessor records are identical
to the previous prepared asset. Mesh records match after material indices are
resolved to their names. Geometry, UVs, corner normals, tangent frames, morphs,
mechanical frames and gameplay authorities are retained. The initial two
preparation attempts wrongly assumed each casting had only one material slot;
the corrected recipe changes only iron_neutral and preserves the unused brass
slots. Failed preparation logs remain archived.

Verification
- Four Blender material comparison frames were individually viewed: identical
  geometry and lights, old worked finish versus new casting finish.
- cast_surface_import wrapper: completed, exit 0, no script errors.
- cast_surface_godot wrapper: completed, exit 0. The test reports 1,762 checks,
  zero failures, including finite UVs, actual loaded complete mip chains,
  casting normal binding and physical strength, plus native kinematic parity.
  All eight frames were individually viewed, including before/after pairs
  under diffuse light, grazing light and a controlled white spotlight.
- cast_surface_world wrapper: completed, exit 0. The composed diagnostic reports
  204 checks, zero failures: all 23 casting bindings and strengths, original
  floor/mount/count checks, real valve/retainer/withdrawal grab-motion-release,
  static inspection and household settings capture. Three room frames and two
  detail frames with the actual carried lamp off/on were individually viewed.
  This is not disk reconstruction or a test-written runtime_contract.
- Texture policy: 1,250 maps, no missing or wrong import settings. Precision
  policy: 25 assets, no errors. Reader baseline: zero new unread fields.
  The existing surface-requirements unit suite passes 21 tests.

Visual findings and remaining work
The new map produces relief-dependent highlights in grazing and carried-lamp
views rather than relying on painted speckling. Warm room lighting still makes
the grey casting read brown. The views do not establish that every material
or the whole room now meets the owner's photorealism target.

The header silhouettes and shoes still show coarse geometry/abrupt transitions
in close views. A Blender-only alternate smooth-fan normal pilot did not
materially cure those visible contours and was NOT installed. Its old/new
normal comparison views are retained. Rebuild actual cast curves/junctions
and shoe profiles in native source, preserving bearings, floor datums, rigid
feed and wall-support fit, before another combined import/capture. Do not
repeat a normal-strength change to disguise the silhouette defect. Machined
hardware edge treatment also needs close review. Human appearance acceptance
remains open.

All prior packing/vent/player-pitch, repair completion, custody, disk restore
and broad qualification work remains open. The world still warns about seven
Texture RIDs at shutdown; cause/baseline comparison are unresolved. This
material work does not certify teardown or resolve that warning.

source_inputs.json binds current diagnostic inputs using declared raw/LF
normalization. The parent artifact_hashes.json binds the archived image and
log bytes. Neither file promotes these diagnostics into runtime evidence.
