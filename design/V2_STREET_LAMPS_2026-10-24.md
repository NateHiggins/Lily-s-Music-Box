# V2 street lamps — bishop's-crook posts, Queens 1928

Evidence class: **INERT**. Research, design and placement. Not acceptance;
the review captures named below are appearance evidence only.

Owner request (2026-10-24): "research and model and place proper street
lights for our scene".

Implementation:

- recipe **art/blender/scripts/build_v2_street_lamps.py** (RUL-006)
- review **art/blender/scripts/review_v2_street_lamps.py**
- stock **game/assets/props/v2_street_lamps.glb**
- generated table **game/data/orison_v2/exterior/street_lamps.json**
- owner **game/scripts/building/orison_v2_street_lamps.gd**, mounted by the
  V2 runtime root under **STREET_ORISON_01**, after the period traffic
- capture **res://tests/OrisonV2StreetLampsShot.tscn** (windowed)

## 1. What the street had

**TEMPLATE_STREET_SEGMENT_V1** carried two placeholder lamps on the Orison
pavement. Each was a 12 cm square post box with a head box and a cap box: at
x 8.1 (`street_lamp_post`, the only one with collision) and at x 14.35
(`street_lamp_post_east`). Each had one OmniLight (`street_lamp_pool`,
`street_lamp_pool_east`, warm, shadowed) at about 3 m. The far, arcade-side
pavement and the west run had no lamp.

## 2. Period research

- **The bishop's crook** is New York's standard cast-iron lamppost from the
  1890s onward. Accounts date it from about 1892 to 1900; Henry Hope Reed
  credited a Bowker design of 1896. It has a cast base and lower shaft, a
  wrought upper shaft, and a crook arm with a scroll in its elbow, hanging the
  luminaire over the gutter. Early posts carried **acorn** pendant globes. The
  bell-shaped luminaires later associated with them came in the 1940s, so the
  acorn is right for 1928.
- **Gas had not gone.** The city still had 44,653 single-mantle gas lamps
  in 1913 against roughly 37,000 electric lamps. Conversion was gradual and
  produced many post styles. A Queens side street in 1928 is plausibly
  electric on the old cast posts.
- **No sodium.** Low-pressure sodium street lighting arrived in the 1930s, and
  New York's sodium retrofits are much later. A 1928 lamp is an incandescent
  globe, warm and soft. The light colour here is a warm incandescent
  (1.0, 0.70, 0.42), not sodium orange. V1's provenance table, which calls its
  lamp a "sodium cobra-head retrofit", is V1 lore and does not apply.
- **Signal boxes on posts.** Police telephone boxes were mounted on
  lampposts and utility poles, and Gamewell fire-alarm telegraph boxes survive
  in a few Queens neighbourhoods. A box strapped to a crook post is period.

## 3. The Rule of Signal

A lamp carries power, not signal (Bible §VIII.2). So the posts are the
city's ordinary black-painted iron, `iron_blackened`, with no new finish. The
globe is milk glass with a lit incandescent inside; there is no aluminium and
no stainless.

The exception is the **signal_box_crook** at the arcade crossing. The police
box is the period object, but its works are forty years early. It has a
Bakelite face, a brass speaking grille and two brass terminals. A Bakelite
handset hangs on a side cradle, a pale standby lamp burns on the hood, and
red cloth-braided pair climbs the post to the crook, signal riding the lamp
circuit. Nobody on the street remarks on it.

## 4. Stock and placement

| Lamp | Stock | Street frame (x, z) | Light |
|---|---|---|---|
| **lamp_orison_mid** | bishops_crook | 8.1, 3.975 | takes over **street_lamp_pool**, shadowed |
| **lamp_orison_crossing** | signal_box_crook | 13.3, 3.975 | takes over **street_lamp_pool_east**, shadowed |
| **lamp_orison_west** | bishops_crook | −9.6, 3.975 | new, shadowless |
| **lamp_arcade_west** | bishops_crook, turned 180° | −4.2, 14.82 | new, shadowless |

The posts stand 0.81 m inside the kerb, the crook reaching 0.84 m over the
gutter with the globe centred at 3.86 m. That height clears the tallest
traffic stock, the saloon bus at 2.9 m. The two replaced placeholders keep
their authored collision box and are hidden. The crossing lamp stands 1.05 m west of its placeholder, clear of the authored x 14 crossing route that the non-colliding placeholder straddled. Every post also gets a 0.22 m
cylinder collider for the base, and the arcade-side lamp stays clear of the
subway stair at x 0–4. Triangles: 2,938 for a plain post and 3,896 with the
box. The exporter's tangent check passes.

The two authored lights move into the globes, about 0.8 m higher and out
over the gutter. They keep their shadows and take range 10.5 and energy 2.6.
The two new pools are shadowless, because every shadow caster shrinks every
other shadow in the atlas. `exterior_geometry.json` is unchanged, because
the paving owner pins its hash.

## 5. Surfaces (RUL-012, RUL-008)

The finishes use existing catalogue keys only: `iron_blackened`,
`cast_iron`, `brass_dull`, `milk_glass` (lit), `car_paint` (police green),
`bakelite_black` and `fabric_warm`. UVs are the shared metre charts, and
runtime materials come from `OrisonV2StreetTraffic.stock_material`, the same
binding the traffic uses. There is no lettering; a box number would be
Label3D.

## 6. Verification and gaps

- Blender review: `art/reviews/v2_street_lamps_20261024/`.
- Godot, windowed: **OrisonV2StreetLampsShot** checks each post, its maps
  and mips, the retired placeholders and the light in each globe, then
  captures the street.
- The lamps follow the campaign clock (follow-up, 2026-10-24). A
  `LampClock` node reads `CampaignClock` every four seconds and dims globes
  and pools together, dusk to dawn with a 25-minute ramp. It shares
  `OrisonV2StreetTraffic.lamp_factor` and the traffic recipe's times, so
  street and vehicle lamps go dark together.
- Not done: the box has no interaction or sound, and the period hum on the
  crossing lamp is deferred. Any merged script or data change expires the V2
  runtime and surface receipts.

Sources: [Forgotten New York: Bishop Crooks](https://forgotten-ny.com/?p=2784),
[Forgotten New York: New York's landmarked lampposts](https://forgotten-ny.com/?p=101263),
[Historical Marker Database](https://www.hmdb.org/m.asp?m=183056),
[NYC Landmarks Preservation Commission report](https://s-media.nyc.gov/agencies/lpc/lp/1961.pdf),
[Forgotten New York: NYC's lost gaslamps](https://forgotten-ny.com/?p=113441),
[Forgotten New York: Police call boxes](https://forgotten-ny.com/?p=42067),
[Forgotten New York: Gamewell fire alarm, Woodside](https://forgotten-ny.com/?p=103305).
