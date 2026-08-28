# LAMP-OPTICS-L1B review packet

This gated packet contains exactly six 1600×900 acceptance images. It does not integrate the optical instrument into production gameplay.

## Diagnosis and correction

The original local-fog shader sampled `OBJECT_POSITION`, which is the fog-volume origin, as though it were each froxel. That made density spatially incoherent. The shader now evaluates `WORLD_POSITION`, `UVW`, and the cone `SDF`. The review environment also uses a readable neutral exposure, a shadowed spotlight, bounded particles, and real occluders.

The ecology sheet uses the approved procedural anemone mesh, one non-emissive tissue shader, and one fixed production-room placement. Only the physical key-light position changes between front, side, and back views. The capture-only key has zero volumetric energy so it cannot inflate the beam.

## Performance disposition

- Optical controller: **0.00354 ms/update** — passes the 0.20 ms gate.
- Warm total CPU median: **39.929 ms/frame** — **fails** the sustainable-frame target and blocks promotion.
- GPU timing: unavailable from a stable per-viewport timestamp in this Godot build; the attempted route and refusal to fabricate a value are recorded in `receipt.json`.
- VRAM residency reported after warm-up: 5,397,219,248 bytes. The initial monitor sample was zero, so this is not presented as a trustworthy feature-only delta.
- The production-room capture also triggers Godot 4.7 renderer teardown errors (`indexing did not unpair geometries from light`) after the images are written. This is a review blocker even though the process exits successfully.

## Files

`diagnostic/side_view.png` and `diagnostic/diagnostics.json` are non-acceptance evidence. `receipt.json` contains the measured run receipt. This packet is for human visual review and is intentionally not approved for merge.
