# LC-5 — ETHERMOSS AND THE CLOSED BREATH

Production Forward+ capture, 2026-08-24, from `DreamMazeRoot` through the
landed `DreamFaunaDirector`, five fauna batches, production player lamp and
`dream_fauna.gdshader`. There is no proof-only creature, gas volume, particle
system, light, collision object or sixth draw.

## What the frames establish

| frame | claim |
|---|---|
| `00_moss_control_a/b.png` | same camera, same production Gilder bed, breath contribution disabled and all fauna shader clocks pinned; equal 45-frame A/A floor |
| `01_moss_exhale_phase_a.png` | the same bed carries its conserved `ethermoss` in the high presentation byte and room `ether` in the low byte; gold hyphae and a cold surface film are enabled |
| `02_moss_exhale_phase_b.png` | only the pinned ether phase changes; the reflected band travels outward across the existing mat |
| `03_tessellate_inhales.png` | an existing uptake cohort reads the same room-ether byte inward |
| `04_anemone_returns_stain.png` | an existing Wine Anemone reads the conserved death-stain compartment as its return/secretion strength |
| `05_moss_deep_gutter.png` | the same mat under the unreliable lamp's 0.35 proof gutter |
| `06_moss_lamp_off.png` | only a faint bounded plasma trace remains; no light is owned by fauna |
| `07_occupied_room.png` | unpinned production animation in room context; 14 Buttons, 8 Tessellates, 8 Anemones, 2 Ribbonettes, 1 Loupe across the four live rooms |

The widened Button transforms are the composite ethermoss bed, not a sixth
family. Their complete fruiting anatomy is never scaled from zero. Spread and
count follow the conserved `ethermoss` compartment. Every living family reads
the same conserved room `ether` byte. Buttons exhale, ordinary fauna inhale,
and Wine Anemones return death-stain matter through one shared shader.

## Noise-floor ruling

ImageMagick normalized RMSE, full frame and the fixed moss ROI
`650x300+280+300`:

| comparison | full | ROI |
|---|---:|---:|
| control A → control B | 0.0329953 | 0.0479918 |
| control B → breath phase A | 0.0278122 | 0.0383557 |
| breath phase A → phase B | 0.0384339 | 0.0663055 |

A single enabled still does **not** clear the live room's A/A floor, so this
proof does not claim that it does. The travelling phase clears the local A/A
floor at **1.38×**. The motion pair, not the static toggle, is the evidence for
visible breath.

## Performance and ownership

The production shot completed 9 frames with zero findings on an RTX 4080.
The paired full-lamp control-B and phase-A samples both averaged **55 draws**;
reported process time was 129.253 ms versus 131.454 ms (**+1.70%**) inside the
capture harness. This is not a gameplay benchmark, but it proves no draw-call
delta on the paired route. The existing executable gates further hold five
batches, at most 96 instances, zero fauna lights/colliders, a conserved ledger,
and no plan, topology, hazard or `RealityState` mutation.

Tests after the source change:

- `DreamFaunaVisibleTest.tscn` — PASS 24/24
- `DreamFaunaLifecycleTest.tscn` — PASS 29/29
- `DreamFaunaTest.tscn` — PASS 29/29
- `DreamFaunaBreathShot.tscn` — 9 frames, zero findings

The seven-stage living sequence and stain persistence remain proved in the
adjacent `dream_fauna_lifecycle_lc4b` production sheet; LC-5 does not replace
or restage that proof.

## SHA-256

```text
00_moss_control_a.png 2df1171c9d0e1f3089ac6a03329121977e2552b8589c357d11bc0195c6a4de48
00_moss_control_b.png 3b22ffa0fce2918873fdd0c5773033b93f18936e1e47ead1f1f6f9dbf0210ca0
01_moss_exhale_phase_a.png a5cd2e310b924eef7cae822542bcc727cc6ad7bebd4f0b4451c00c6e3d292ad0
02_moss_exhale_phase_b.png 51da8123ec7dc65a2012330e43f255d196d00ca813e2ab8be66ff5680327499d
03_tessellate_inhales.png 3ce429f316832a051aa31c7500517b9314169168d15816ae2e577a88002d3e3a
04_anemone_returns_stain.png addc850a63c1351ab5ddb4b881a2ca23ff58fad7c96da38b59999bc17e921b22
05_moss_deep_gutter.png 40cc214357000bb8d754e92ceec0ff9ee0b9a3de792307992caac36ae0a6975d
06_moss_lamp_off.png 3288623adff99393341bd6ef12f64e48f7cd0d234419f55d4b4b6a738bf4a572
07_occupied_room.png d6a2009a3d52503dabb038b28271bba26572d5d0f12dac2e8a07d38363a850b5
```
