# Dream irradiance IR-V1/IR-V2 — production proof

The production `DreamMazeRoot`, room builder, exposure field, service lamp,
lineage and fauna render this set. There is no helper world, camera, light,
material, hazard or gameplay owner. IR-V1 and IR-V2 extend the existing shared
owners only; they do not complete Juno's waking case loop.

## Frames

- `00_control_a.png` and `00_control_a_repeat.png` are equal-interval A/A with
  fauna hidden and the response pinned at the oblique centre.
- `01_wall_dark/oblique/molten.png` and
  `01_tessellate_dark/oblique/molten.png` prove the three authored languages on
  architecture and harmless life.
- `02_wall_blend_00..04.png` and `04_tessellate_blend_00..04.png` hold seed,
  pose and geometry fixed while traversing five evenly spaced response values.
- `05_long_shadow_steady.png` and `05_long_shadow_gutter.png` hold camera and
  run state fixed at delivered multipliers 1.00 and 0.58.
- `06_vantry_arc_gutter_floor.png` and `06_vantry_arc_lamp_off.png` prove the
  existing blue-arc hazard confirmation remains unmistakable at the 0.58
  floor and lets go on the real lamp boolean.
- `gutter_luma_trace.csv` contains 433 fixed-camera samples over 108 seconds;
  `gutter_luma_trace.svg` plots the delivered multiplier and normalized frame
  luma.

At 1280x720, the A/A normalized mean absolute RGB difference is **0.00157669**
(`0.5630/0.3954/0.2478` byte RGB). Downsampled mean-luma sweeps are strictly
ordered:

| Surface | response 0 | .25 | .50 | .75 | 1.0 |
|---|---:|---:|---:|---:|---:|
| Wall | .001227 | .002046 | .066438 | .171822 | .300576 |
| Tessellate | .005447 | .007116 | .086834 | .264636 | .387072 |

Dark anatomy remains nonzero, oblique tissue is legible without becoming a
state cut, and molten response stays below white. Visual inspection confirms
the wall and Tessellate retain their identity across the sweep. The gutter
pair preserves the lamp-on beam while making its reach, falloff and long shadow
visibly unreliable.

## Measured gutter and ownership

The six-cycle production trace measures multiplier **0.5800..0.9998**, mean
**0.7904**, maximum sampled slope **0.1474/s**, dominant frequency **0.0554
Hz**, and highest component above one percent of the peak **0.2217 Hz**. Frame
luma is **0.0877..0.2955** and correlates **0.9979** with delivered energy. The
trace never reaches zero and remains well beneath the `0.30/s` and `0.75 Hz`
safety ceilings.

`DreamIrradianceTest` passes **16/16**: deterministic seed/clock replay, floor,
ceiling, mean and slope; zero counterfeit lamp edges; proof pin; Juno boolean
edge and elapsed-release preservation; pursuit and hazard invariance; and
deterministic durable/reversible field accrual. `DreamExposureTest` passes
**35/35**, including RG8 packing, rise/fall limits, durable cooling invariance,
clear and replay.

Shared regressions pass: Profile **46/46**, RoomBuilder **175/175**, Pursuit
**39/39**, Hazard **42/42**, Boundary **39/39**, Atlas **26/26**, FractalRun
**24/24**, Lineage **21/21**, SurfaceTarget **105/105**, and Fauna **21/21** —
**538/538** total. No plan, collision, hazard, pursuit, save, fauna census or
transform owner changed.

The hazard pair exposed and closed one existing lifecycle defect: a fractal
pocket rearmed `HazardField` but did not rebuild the approved conduit/arc nodes,
so a trunk reached after entry could be mechanically live without its visible
confirmation. Those same nodes now follow rearm; no new hazard or presentation
type was added.

At 2560x1421 on the RTX 4080, the production dream remains **0/4** over the
16.6 ms budget:

| Station | Calls | Frame time |
|---|---:|---:|
| waking room, lamp off | 48 | 2.21 ms |
| waking room, lamp on | 77 | 2.27 ms |
| deep pocket, lamp off | 133 | 2.40 ms |
| deep pocket, lamp on | 172 | 2.44 ms |

The submission counts remain the existing ceiling because RG replaces R in
one texture object and all three shaders use their existing material instances.
WalkTest FAST passes at x8/480 Hz. The FULL attempt advanced through the
physical walks, elevator and four case simulations but did not complete inside
the mandatory 60-second Godot limit; it was terminated, and no fresh FULL pass
is claimed.

## Scope

IR-V0, IR-V1 and IR-V2 are closed. The gutter is dream-only presentation below
the existing switch, not a flicker event or hazard condition. FA-V4, later
fauna breadth, waking case loops and any new dream subject remain separate
owner decisions.
