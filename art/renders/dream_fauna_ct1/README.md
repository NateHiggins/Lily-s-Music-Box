# CT-1 — family skin atlases for the dream fauna, built from the plates

Owner direction 2026-08-21: "a variety of hyperdimensional critters we have
sketched need detailed textures, build them from the ones we made". No new
generation is available, so every family's skin is a **composition of the
six cases' substance plates** already ingested for the shared dream
(`game/assets/dream/incarnations/<case>/`).

## The trick: the fauna already have an atlas coordinate

The five part-kit families (`DreamFaunaParts`) carry no UVs by contract.
They do carry `CUSTOM0 = (body_t, angle/τ + ½)` — position along the body
and angle around it — which is a cylindrical atlas coordinate in all but
name. The atlases are composed in that space and sampled by it, so no
mesh, contract or channel changed.

## `art/tools/build_fauna_skins.py`

Per family, in atlas space (u along the body, v around it), 1024²:

| layer | from | as |
|---|---|---|
| base | plate A, tiled with a hashed quarter-turn and offset per tile | the skin |
| bands | plate B | soft bands along the body (segments, rings, pleats) |
| wires | the shader's own cloisonné lattice, **domain-warped** so it meanders, rasterised in atlas space and filled with plate C | mask R (gold) — so the shader's `gold_mask` and the atlas agree |
| jewels | plate D's luminance peaks gated by a jittered bead lattice | mask G (set stones) |
| wear | the crests of the composed height | mask B |
| normal | the composed height at two scales, whiteout-blended with the plates' own tangent normals | `normal.png` |

| family | base | bands | wires | jewels |
|---|---|---|---|---|
| Gilder's Button (crop) | Mina lens membrane | Mae lacquer craquelure | Mina gilt edge | Cal dial glass |
| Tessellate (grazer) | Mae marquetry grain | Peter ledger stock | Omar solder alloy | Juno bakelite |
| Wine Anemone (detritivore) | Mina ink fibre | Juno speaker cloth | Juno oxidised brass | Mae aged glass |
| Ribbonette (courtship) | Juno diaphragm | Mae foxed label stock | Mina gilt edge | Cal valve mica |
| The Loupe (predator) | Omar tool steel | Cal wax groove | Peter brass fastener | Cal dial glass |

`atlases/<family>.png` shows each atlas as albedo · normal · mask. Outputs
ship under `game/assets/dream/fauna_skins/<family>/` with a `SOURCE.md`.

## In the shader (`dream_fauna.gdshader`)

`skin_albedo / skin_normal / skin_mask`, gated by `skin_ready`, bound per
batch by `DreamFaunaDirector._make_batch` (`FAUNA_SKINS=0` leaves the
procedural skin exactly as it was; an absent atlas does the same). The
atlas **modulates the wine** — the wine keeps its level and hue, the plate
supplies structure around its own mean and a little of its colour; never a
recolour, the direction is wine with gold. Its wire mask joins the
procedural wire, its jewels join the authored jewels. The normal goes
through a **derivative cotangent frame** (the meshes have no tangents) and
is written to `NORMAL` only: the fauna contract (`DreamFaunaTest`, 28/28)
forbids emission and PBR writes, so a first draft's `ROUGHNESS` write came
out again.

## Frames

`studio/sheet_studio.jpg` — the five families in a studio (uniform exposure
field, lamp on the camera, one key light; `DreamFaunaSkinShot.tscn`) at the
oblique and molten irradiance bands, plain vs skin. The skins read as the
same wine creatures with more in them: membrane veining and a second
wire lattice on the buttons, fibre along the anemone's arms, weave on the
ribbonette at molten, marquetry on the tessellate's shell. The production
dream frames (`DreamFaunaShot`, `DreamFaunaStyleShot`) are near-black by
design and did not show the skins at their distance; the studio is the
proof, the dream is where they live.

## Not done

- CT-2: the FA3 sketched families get atlases as each part kit lands.
- The atlas is sampled once per pixel; no anti-tiling on the creature (the
  repeat is 1–3 along the body, so the plate's period is not the problem it
  is on a wall).
- The normal's relief is quiet under the dream's irradiance bands; the
  height tier for fauna (parallax on a 0.2 m creature) is not worth a fetch.
