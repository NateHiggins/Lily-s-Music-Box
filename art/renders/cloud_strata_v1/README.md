# Cloud-strata separation

Fixed production `04_roof_skyline`, forced night, clear base preset, seed
`19280731`. The public stratum overrides create 100% high-only and 100%
low-only conditions while deriving coherent total cover.

## Accepted argument

- Clear control: `../neighbour_physical_grid_v1/night/04_roof_skyline.png`.
- `high_only_final`: homogeneous cirrostratus veil. It retains astronomical
  structure and never creates a low optical ceiling.
- `low_only`: closed lower deck. It removes the stellar field and leaves the
  city under diffuse night.

Normalized RGB RMSE on the 1280x330 sky crop:

| Comparison | RMSE |
| --- | ---: |
| clear → high only | 0.0351786 |
| clear → low only | 0.0767761 |
| high only → low only | 0.0839999 |

The focused contract supplies mechanism floors: high-only resolves to zero low
strength/coverage and strength 1.0 in the veil; equal high/mid/low fractions
produce strictly descending direct transmission.

## Rejected high-cloud synthesis retained

- `high_only`: too close to clear to read.
- `high_only_accepted`: one sine became enormous diagonal projector bands.
- `high_only_accepted2`: warped nonparallel sines still exposed interference
  ribs.
- `high_only_noise`: trilinear value-noise cells became rectangular plates.
- `high_only_noise2`: rotated/domain-warped octaves produced angular shards.

Those failures establish the LOD ruling: do not invent high-cloud structure
without a real volumetric or measured source. A homogeneous 0.18 cirrostratus
veil is more truthful than conspicuous procedural art. Shaped, wind-advected
motion remains the lower/middle deck's job. Everything stays in one sky draw;
no texture, volume, node, light, persistence or gameplay state is added.
