# Orison Queens skybox

The exterior is divided by distance so one image is not asked to fake
parallax from two radically different camera heights.

## Sightline design

- **Street level:** the existing 3D block, alleys, fire escapes, utility
  structures and neighbouring façades own the near field. The dome contributes
  humid cloud cover and low city glow through gaps, but no texture-painted
  building pretends to stand across the street.
- **Sixth-floor roof:** the same 3D block supplies nearby parapets and roof
  silhouettes. The panorama begins with mid-distance Queens apartment and
  warehouse roofs, then recedes into borough haze.
- **Directional geography:** Manhattan and a bridge silhouette occupy one
  southwest-facing sector. The other directions remain lower Queens roofscape,
  avoiding the “downtown in every direction” skybox effect.

## Texture mapping

`orison_queens_night_half_dome_4k.png` is a 4096 × 2048 upper-hemisphere
cylindrical panorama:

- top edge: zenith;
- bottom edge: level horizon;
- full width: 360 degrees;
- skyline: lowest 16–20 percent;
- nearest represented architecture: mid-distance only.

The production pass feathers 192 pixels across the horizontal wrap. The upper
72 pixels fade toward their horizontal mean because every longitude converges
at the zenith; this prevents a visible high-noon pinwheel.

## Visual targets

- Western Queens around Astoria, Long Island City and Sunnyside rather than a
  generic downtown.
- Prewar brick blocks, warehouses, water towers, chimneys and restrained window
  light.
- Humid blue-black cloud cover carrying reflected sodium city glow.
- Sparse stars and a small cloud-veiled moon, not a fantasy-scale moon.
- Dark enough that the Orison's warm fixtures remain the visual subject.

## Runtime cost

The implementation remains one unlit half-dome mesh and one compressed 4K
texture. All street/roof height cues come from the existing geometry, so no
additional lights, physics bodies, animated layers or draw-call-heavy skyline
cards are introduced.
