# DREAM-SURFACE-S2 closure

## Six-shot gate

`review_01/` contains exactly six 1600x900 Forward+ captures. Pixel review was
performed after three art iterations. The accepted read is: irregular connected
plasmodial fans and veins; half-submerged open protein rings; a 256-instance
rooted ciliary field; six grayscale sensing silhouettes; absorption-led internal
backlight; and a colony that retains its radial/ciliary identity at gameplay
distance.

## Final evidence

`final_matrix/` is the existing S1F production-renderer closure harness rerun
after the review gate: 41 cellular/lifecycle frames, 30 modality frames, and 8
crystal-listener frames (79 total). No new evidence framework or simulation
authority was introduced. The accepted production fauna lifecycle and visible
submission suites also cover all five advanced-fauna topologies; their cached
production meshes and the fold-crab rig were preserved.

## Performance delta (S1F -> S2)

Measured at 1280x720, Forward+, RTX 4080, with the same S1E scene and process
loop:

- Draw calls: 4 -> 6 near (`+2`); the carpet remains one MultiMesh draw.
- Materials: 6 -> 6 (`+0`); the sheet and carpet reuse existing materials.
- Renderer CPU: 0.0843 -> 0.3427 ms/update (`+0.2584 ms`), under the accepted
  0.35 ms threshold.
- Renderer nodes: 7 -> 9 (`+2`), not proportional to visible cilia.
- VRAM delta: 92,212,976 -> 92,243,632 bytes (`+30,656 bytes`, 0.029 MiB).
- Near: 8 hero + 256 carpet cilia, 0.3416 ms/update.
- Mid: 5 hero + 96 carpet cilia, 0.1656 ms/update.
- Far: 2 hero + anisotropic membrane response, 0 carpet instances,
  0.0564 ms/update.
- Peak bounded presentation capacity: 32 hero cilia, 256 carpet cilia, 64
  membrane-protein slots, 24 ether motes, and 64 branch segments.
- GPU frame timing is not exposed by this command-line Godot monitor. Overdraw
  was therefore reviewed visually: the opaque sheet is single-layer, the carpet
  uses one opaque tapered low-poly mesh, and the carpet is removed at far LOD.

## Validation

- DREAM SURFACE S1: PASS (12/12)
- DREAM SURFACE S1E PERFORMANCE: PASS
- DREAM TENTACLE: PASS (28/28)
- DREAM FAUNA LIFECYCLE: PASS (34/34)
- DREAM FAUNA VISIBLE: PASS (24/24)
- S1F closure captures: PASS (79/79)

