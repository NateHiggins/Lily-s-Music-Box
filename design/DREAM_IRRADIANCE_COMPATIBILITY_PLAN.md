# Dream Irradiance Compatibility Plan

**Status:** owner doctrine and compatibility design approved 2026-08-20;
IR-V1/IR-V2 implemented and proved. Production evidence is recorded in
`art/renders/dream_irradiance_v1/README.md`.

## 1. Pointwise response

The implementation target is a single `irradiance` value in `[0, 1]` sampled
by architecture, lineage and fauna at world position. At the fixed 15 Hz field
tick:

- `direct = cone * distance * delivered_energy`, using the existing
  `lamp_origin`, `lamp_dir`, `lamp_reach`, `lamp_cos_outer` and `lamp_energy`;
- a transient response moves toward `direct` no faster than `0.42 / s` upward
  and `0.28 / s` downward. This is the safety envelope that prevents a waved
  lamp from turning shader response into a strobe;
- the shader applies incidence as `mix(0.68, 1.0, abs(N dot -L))`, so grazing
  surfaces naturally live lower in the curve without disappearing; and
- retained exposure contributes at most `0.24`, enough for sustained attention
  to advance a surface without making an unlit converted room fully molten.

The first tuning equation is:

`irradiance = clamp(rate_limited_direct * incidence + 0.24 * retained, 0, 1)`.

These are authored overlapping bands, not states or gameplay thresholds:

| Language | Weight |
| --- | --- |
| Neon anatomy | `1 - smoothstep(0.30, 0.58, irradiance)` plus a vein-root floor through `0.72` |
| Oblique tissue | `smoothstep(0.16, 0.38, irradiance) * (1 - smoothstep(0.68, 0.86, irradiance))` |
| Molten response | `smoothstep(0.62, 0.90, irradiance)` |

The overlaps are load-bearing: line roots become veins and veins become flow
channels. Geometry animation amplitude is multiplied by the same smoothed
molten weight; no vertex changes collision or exceeds the existing relief
envelope.

## 2. Existing storage and exact additions

`DreamExposureField` already owns the only pointwise persistent volume and
uploads it through the only existing sampler. Expand its R8 payload to RG8:

- `exposure_tex.r`: unchanged durable exposure, monotonic while a room is live;
- `exposure_tex.g`: transient, reversible, slope-limited direct irradiance.

This adds one byte per voxel (73,728 bytes) but no texture object, file,
sampler, material, draw or gameplay owner. `room_exposure()` and every pursuit
reader continue to read CPU durable R only. The shader derives incidence from
its existing world normal; no normal enters the volume.

All three maintained shader paths add the shared helper include
`dream_irradiance.gdshaderinc` and these uniforms:

- existing, unchanged: `lamp_origin`, `lamp_splash`, `lamp_dir`, `lamp_reach`,
  `lamp_cos_outer`, `lamp_energy`, `exposure_tex`, `exposure_extent`,
  `exposure_height`;
- added shared controls: `irradiance_retained_gain = 0.24`,
  `irradiance_incidence_floor = 0.68`, `irradiance_band_neon = vec2(0.30,
  0.58)`, `irradiance_band_oblique = vec4(0.16, 0.38, 0.68, 0.86)`, and
  `irradiance_band_molten = vec2(0.62, 0.90)`;
- added genome controls: `irradiance_hue`, `irradiance_vein_branch`,
  `irradiance_line_weight`, `irradiance_pattern_species`,
  `irradiance_viscosity`, and `irradiance_pulse_phase`.

`dream_klimt.gdshader` keeps its real Orison texture/filter, relief channels,
motif, `consumed`, phase transition and portal gates. Its room material derives
the six genome controls from the already-present room lineage record when the
five existing room-local materials are created. No sixth material appears.
Architectural joint distance supplies anatomy trunks; motif supplies pattern
species.

`dream_lineage_gold.gdshader` keeps `gene_phase`, phase thresholds, breach,
eye, portal, embrace and intrusion contracts. `gene_phase` supplies pulse;
the owning room lineage supplies the other five controls on the existing
material instance. The Tenant body and hazard-growth values remain separately
bounded; neither inherits harmless-life brightness.

`dream_fauna.gdshader` keeps the FA-V0/FA-V1 packing exactly:

- `INSTANCE_CUSTOM.r`: identity/pulse phase;
- `.g`: nutrient + emergence;
- `.b`: flags + activity;
- `.a`: hue jitter + pattern/scale jitter;
- vertex `COLOR`: region, curvature/cavity and joints A/B;
- vertex `CUSTOM0`: body-t, body-theta, joint C and accessory section.

No extra fauna stream is required. Hue comes from `.a` high byte; line weight
and pattern species share `.a` low byte plus `family_motif`; vein branching
uses vertex curvature and body coordinates; viscosity uses family gait plus
nutrient/emergence; pulse uses `.r`. The five bounded family material instances
remain exposed by the proved zero-mesh binding nodes. The root's unchanged
collector sets shared uniforms; submitted draws remain at the proved ceiling.

## 3. Genome-to-look map

The mapping is deterministic and shared across scales:

| Genome meaning | Architecture/lineage | Fauna |
| --- | --- | --- |
| Hue drift | room lineage phase + decay | packed hue jitter around room family |
| Vein branching | architecture joints + lineage fold | curvature, body-t/theta, family motif |
| Line weight | seeded room aspect, bounded by surface class | packed pattern jitter, bounded by scale class |
| Pattern species | existing Klimt motif | existing `family_motif` |
| Molten viscosity | room decay + tissue fold | nutrient/emergence + gait band |
| Pulse phase | `gene_phase` | identity phase |

Room values set the family centre; fauna data may vary only within a bounded
local radius, so offspring rhyme rather than become generic random objects.
Decay widens branching and dark-line density but never raises harmless life
above hazard or turns the room molten without delivered/retained irradiance.

## 4. Unreliable-lamp waveform and owner boundary

`PlayerController` absorbs the gutter below its existing `_lamp_on` switch and
warm-up/pop transient. Dream entry supplies the campaign seed and current
`DreamMazeRoot.run_elapsed_s`; waking play remains steady. The proposed
deterministic envelope is an 18-second seeded cycle: 10–12 seconds of smooth
sag, 4–6 seconds of smooth recovery, and a seed-selected deep dip every third
to fifth cycle. A deep dip takes at least 0.80 s down and 0.65 s up.

- delivered-energy multiplier: floor `0.58`, ceiling `1.00`, target mean
  `0.79 +/- 0.02` over 180 seconds;
- maximum analytic and sampled slope: `0.30 / s`;
- all authored components: `< 0.75 Hz`, with no steps or per-frame randomness;
- reach multiplier: `0.88 + 0.12 * normalized_energy`;
- angle stays `40 degrees`; `spot_angle_attenuation` moves smoothly from the
  existing `2.4` to at most `2.8` at the deepest sag.

The order is switch -> warm-up/pop -> gutter -> delivered `light_energy`,
`spot_range`, and falloff. `lamp_is_enabled()` remains `_lamp_on`; the gutter
has no reference to channel, profile, pursuer or hazard owners. `lamp_pose()`
publishes delivered energy/range so shaders and exposure see the same pool.
The existing SpotLight3D alone casts the longer shadows.

Juno keeps boolean edges and echo scheduling exactly where they are. Only the
existing open-channel sustain accumulator becomes energy-weighted:
`sustain += delta * delivered_energy_multiplier`. Treat `settle_after_s` as
delivered-light seconds and, after measured waveform proof, retune its profile
value to `old_elapsed_seconds * measured_mean` (the initial `8.333333 * 0.79 =
6.583333` target) so an average gutter preserves the ruled elapsed settling time.
This changes neither a rising edge nor the delayed echo clock. The exposure
field already receives delivered energy through `lamp_pose()`, so identical
seed/clock/input traces accrue identical durable exposure without another
gameplay feed.

One diagnostic-only freeze-at-phase method pins multiplier, reach and falloff
for tests and shot harnesses. It is not an environment-tunable production
mode. Every harness that currently zeros `_lamp_phase` must also pin the gutter
before A/A timing begins.

## 5. Proof and stop conditions

Extend the production-root fauna harness rather than creating a second visual
world. Keep equal-interval fauna-hidden A/A, then capture each family and one
architecture wall at dark, oblique and molten centres. Add five evenly spaced
blend frames on the same wall and five on one Tessellate while camera, seed,
pose and exposure are fixed. The sequence must be continuous and ordered, not
three hard looks.

Numerical gates:

- dark anatomy is nonzero while black fill stays at the established floor;
- harmless fauna and architecture life stay below hazard anatomy (`0.55`);
- molten peaks stay below sanctioned canopy stars and the existing bloom
  ceiling; no white is introduced;
- adjacent blend-frame luma has no discontinuity above twice the equal-interval
  A/A noise floor;
- plan, collision, hazard, pursuit, save, fauna census/transforms and draw
  counts are invariant.

Gutter proof adds a fixed-camera CSV and plot over at least six cycles,
asserting min/max/mean, no zero, maximum slope and spectral ceiling. A
steady-pin/gutter long-shadow beauty pair uses the same camera and run state.
At gutter floor the Vantry arc confirmation must remain visible.

Four boundary tests run a complete gutter schedule and assert: zero lamp
boolean/Juno rising edges beyond the player's real switch trace; zero pursuit
acquisition changes; zero hazard condition changes; identical energy/range
traces, energy-weighted Juno sustain and durable exposure for the same seed,
clock and input trace. Existing shared dream/profile suites and WalkTest
FAST/FULL remain mandatory.

Stop before implementation for owner review. During implementation stop on a
new draw/material/light/texture object, a changed gameplay edge, a failed
determinism vector, a rate or luma gate breach, hidden hazard confirmation, or
any R1–R6/topology/collision/save mutation.
