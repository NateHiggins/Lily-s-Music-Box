# DREAM-CRITTER-VOXEL-V3 motion-acceptance receipt

Status: **human motion acceptance PASS; ready for controlled integration by
exact hash; not merged**.

Atlas implementation commit: `7a7281f` (`Add distinct voxel microorganism repertoire`)

Motion packet commit: `d441309` (`Add twelve-species motion acceptance packet`)

## Human motion acceptance — 2026-08-31

PASS. The packet closes the static-atlas ambiguity:

- Volvox reads as a rolling reproductive colony; Noctiluca reads as a
  vacuolate body with localized scintillation.
- Stentor contracts its whole cortex; Vorticella collapses through its stalk.
- Lacrymaria, Euplotes, Spirostomum and the heliozoan retain unmistakably
  different locomotor strategies.
- Phototroph and colony behavior remains anatomically specific rather than
  generic pulsing.

Non-blocking debt remains the shared dark membrane treatment. Noctiluca's
scintillation and some colony motion could also be more legible at gameplay
distance. These findings do not authorize a material, geometry or authority
expansion during integration.

Controlled integration must use the two scoped implementation hashes exactly:

```text
7a7281ff3f3ca77a6df5bac43cde3ba282bf3cf6
d441309ead2289eec7824c1b33231bcfa9553f93
```

The acceptance-record commit is documentation only and is not a substitute
for either scoped implementation hash. S2J and L1D status remain unchanged.

## Bounded proof

The packet advances the twelve existing presentation laws under the same
production `dream_critter.gdshader`, one shared `ShaderMaterial` and one real
world-owned `DreamExposureField` RG8 texture. The harness directly calls the
controller's existing `_apply_law()` at a deterministic 30 Hz and pushes the
result through the existing batched draw. It does not add or alter production
species, materials, geometry, ecology authority or voxel ownership.

Four temporal strips cover all twelve source-derived species:

- `motion_pair_spherical.png` — Volvox roll/daughter inversion versus
  Noctiluca touch-triggered scintillon wave and afterglow.
- `motion_pair_stalked.png` — Stentor whole-trumpet drawstring contraction
  versus Vorticella bell withdrawal on a coiling stalk.
- `motion_hunters_and_ciliates.png` — Lacrymaria, Euplotes, Spirostomum and
  heliozoan motion.
- `motion_phototrophs_and_colonies.png` — Euglena, Bacillaria, Salpingoeca and
  Mesodinium motion.

The two pair sheets are 2880×810. The two four-species sheets are 2880×1620.
All frames use the same enclosed microscopy room, camera treatment, physical
lights and spatially disagreeing R/G voxel field. No debug coloration appears.

## Pair findings

- Stentor and Vorticella now separate through mechanism rather than pose:
  Stentor compacts its entire oral trumpet and reopens in place; Vorticella
  keeps its bell identity while its stalk coils and reels the body downward.
- Volvox and Noctiluca now separate through both anatomy and time: Volvox's
  cellular lattice rolls while the daughter lip grows into inversion;
  Noctiluca remains a low-density vacuolar rind while a brief cyan scintillon
  wave propagates and decays.
- The accepted shared dark-membrane concern remains recorded as non-blocking
  debt. No material was added or changed during this proof.

## Machine receipt

`motion_receipt.json` records four law samples and three image deltas for each
species. Every species produced nonzero specimen-region temporal deltas. The
smallest measured delta was Noctiluca at `0.000158`; the largest minimum was
Vorticella at `0.026974`. Volvox moved from inversion state `0.0` to `1.0`,
Stentor from open through `0.759` contraction back to `0.0`, and Vorticella
from extended through `0.966` withdrawal back to `0.0`.

Resource assertions:

- species demonstrated: 12;
- new species: 0;
- triangles: 84,000, unchanged;
- materials: 1 shared, unchanged;
- voxel fields: 1 shared;
- voxel textures: 1 shared;
- ecology writes: 0.

## Verification

Forward+ capture:

```text
Godot 4.7.1 — Vulkan Forward+ — NVIDIA GeForce RTX 4080
[DREAM-MICROORGANISM-MOTION] species=12 sheets=4 material=1 texture=1
field=1 triangles=84000 ecology_writes=0
exit 0
```

Focused deterministic test:

```text
[DREAM-CRITTER-VOXEL] checks=2104 failures=0 species=16 triangles=84000
materials=1 shared_texture=1 per_critter_field=false cat_scale_m=0.683
exit 0
```

Production ecology regression:

```text
DREAM CRITTER TEST: PASS (43/43)
exit 0
```

The Orison regression emitted its existing resident-navigation route warnings;
they did not fail the test and were not altered by this presentation-only
packet.
