# SR7-C — the roof house-tank ball cock

**Status: production-rendered proof complete, with stated limits.**

Captured 2026-08-25 in Forward+ (NVIDIA RTX 4080, Vulkan 1.4.341) through the
real `res://scenes/building/orison_root.tscn`, on the real roof, against the
timber water tank production has always baked there. Shot through the player's
own camera, standing on the roof deck, in the production day/night owner's own
daylight state. No proof-only light, mesh, material, camera rig or production
owner exists.

Harness: `res://tests/MaintenanceBallcockShot.tscn` through the serialized
Godot runner with `-Windowed`.

## The truth this teaches

**A float does not know the water level. It makes a force.**

```
closing force  =  buoyancy  ×  leverage
```

A waterlogged float still rises. The arm still comes up. The tell-tale still
reads full. It simply cannot close anything, and the tank pays the difference
out through the overflow. Nothing about the float's *position* reveals the
fault — `float_ride()` is a constant in the prop for exactly that reason — so
apparent closure can only be told from a valve that actually holds by watching
the witness, with pressure behind it, over time. That is why the transferable
verb is **`timing`**, and with it the ruled six-verb vocabulary is complete.

## Sources

**Documented mechanism:**

- **T. Hill and J. Houghton, GB 190,216,359 (1902), "Improvements in Ball or
  Float Cocks."** "The valve C seats under the pressure of the water &c., and
  is connected to the float lever F by the spindle B, which is grooved to
  permit the passage of the liquid." And: "The lever F is provided with a
  weight E, which is adjustable to suit different pressures of water &c." The
  seating is screw-threaded so it can be renewed when worn. The adjustable
  weight is the period's own admission that closing force must be matched to
  supply pressure — the leverage half of the equation, documented.
  <https://patents.google.com/patent/GB190216359A/en>
- **F. Biedenmeister, US 951,172, filed 8 May 1909, granted 8 March 1910,
  "Ball-Cock."** A *balanced* cock — "one in which the water pressure is
  exerted oppositely on both ends of the spindle" — so that it "can be opened
  quickly and closed tightly by a small ball or float." Balancing exists
  precisely because an unbalanced cock demands more float than a small one can
  give. <https://patents.google.com/patent/US951172A/en>
- **Context:** New York required roof tanks above six storeys; water is pumped
  up and distributed by gravity, and a float valve admits more as the level
  recedes. This is well-attested secondary context, not a mechanism citation.

**Orison-specific inference, stated plainly:** the float chamber on the tank's
south face, its slotted guard, the tell-tale index, and the routing of the
overflow over the roof water butt are *this building's* arrangement. External
float chambers and gauge columns are ordinary period practice — the Orison's
own basement boiler already has one — but this particular column is authored,
and it exists so the float, rod, lever, weight, cock, seat, inlet and overflow
are legible from the roof deck instead of hidden inside a timber box. The
waterlogged float is a real and common failure; that *this* tank has one is
fiction.

## What production already had

`art/data/gen_layout.py` bakes the tank: `watertank`, 2.80 × 2.20 × 2.30 in
timber at building (-9.45, 4.95), standing on four cast-iron legs — five boxes.
Nothing in `game/` referenced it, and the generator's own note records that an
earlier `watertank` marker was deleted because "the kind was never registered,
no graph node used it". There was no inlet, float, valve, seat, overflow,
marker or owner, and **no water system anywhere in the Orison** to join.

The generator also already says the roof water butt stands "off the tank
overflow" — an overflow that did not exist as geometry. This apparatus makes
that sentence true: the discharge lands on the butt's lid.

## Definitive frames

All frames are 1280×720. SHA-256 truncated to 32 hexadecimal characters.

| Frame | SHA-256 | Claim |
| --- | --- | --- |
| `00_works_control_a.png` | `ffa8888fba25faf4bd587dc3ed948b3a` | As found at the works: riser open, cock not holding, overflow running. |
| `00_works_control_b.png` | `ffa8888fba25faf4bd587dc3ed948b3a` | Same state, same camera — **byte-identical**. |
| `01_column_control_a.png` | `97f77872b2d1087d2eae865ce88e22fb` | As found at the column: the float riding in its guard. |
| `01_column_control_b.png` | `97f77872b2d1087d2eae865ce88e22fb` | Same state, same camera — **byte-identical**. |
| `02_roof_context.png` | `185d6735724aee5f0d11320893fb9735` | The tank on the roof it has always stood on. |
| `03_telltale_reads_full.png` | `0d6b83525c03361750886edbecb269ee` | The tell-tale brought across: the float reads **full** while the overflow runs. |
| `04_riser_shut_witness_dry.png` | `cee79e2b7ec75d35478578a8a2d903b8` | Riser shut, witness dry — and proving nothing, because there is no pressure behind it. |
| `05_float_pouring.png` | `675d5b6ba55dce372fa3210cbb7b996f` | Held clear of a dead inlet, the float pours from its split seam. |
| `06_opened_too_soon_refused.png` | `4300af3a26948fa829afed2d320bca20` | **The mechanically false order:** riser opened before the weight is set. Sound float, no leverage, overflow running again, apparatus balking. |
| `07_weight_set.png` | `34c0e54a26a000d1640e45e1d55bfe57` | The weight run out along the arm; the lever rises under load. |
| `08_holding_dry.png` | `136521a1e55c3669ab1d135805f44447` | **Honest closure:** riser open, valve holding, witness dry. |
| `09_committed.png` | `6d20b85cda73e26f3b44e42df7ce834d` | The committed condition at the works. |
| `10_column_committed.png` | `fda680faadd6d9bc199ce60a5fe32c44` | The committed condition at the column. |
| `11_roof_wide_after.png` | `cd9dfd2cc9e3a328fbba02732d7aebeb` | The apparatus in the real roofscape, no longer overflowing. |

## A/A pricing

Normalized RMSE, ImageMagick. **Both A/A pairs are byte-identical: RMSE
exactly 0.000000**, confirmed by matching SHA-256. With `Engine.time_scale`
at zero, the prop's `_process` stopped, and the lamp gutter pinned, nothing in
these frames moves between two captures of the same state — including the rain
and the sky. The noise floor is therefore not a small number to beat; it is
zero, and any measurable difference is signal.

The declared witness ROI is `150x300+498+115` — the overflow discharge above
the water butt — because the whole frame also contains a riser stop that
rotates, and a whole-frame delta would let the handwheel pay for claims about
the water.

**Works camera** (floor 0.000000 whole and ROI):

| Pair | Whole frame | Witness ROI |
| --- | ---: | ---: |
| control A → control B | **0.000000** | **0.000000** |
| control → riser shut, witness dry | 0.091962 | **0.154316** |
| riser shut → opened too soon (overflow returns) | 0.012120 | **0.036917** |
| opened too soon → holding dry | 0.012914 | **0.036807** |
| riser shut → weight set | 0.010443 | **0.006892** |
| control → committed | 0.091830 | **0.153849** |

**Column camera** (floor 0.000000):

| Pair | Whole frame |
| --- | ---: |
| control A → control B | **0.000000** |
| control → tell-tale reads full | **0.001688** |
| control → float pouring | **0.006532** |
| control → committed | **0.009024** |

Weakest claim: the tell-tale index moving, **0.001688**. Strongest: the
overflow stopping, **0.154316**. Every claim is above a zero floor.

## What this sheet does NOT prove

Stated plainly, because the numbers above are strong and the pictures are not
uniformly so:

- **It is raining, at dusk-grey daylight, on a dark roof.** The apparatus is
  weathered cast iron in the tank's own shadow. The overflow running versus dry
  reads clearly, and so do the lever and weight; the **tell-tale index at
  0.001688 is measurable but small on screen**, and a viewer should not be told
  it is obvious. It is the weakest visual claim on the sheet.
- The sheet proves the *apparatus* changes state. It does not prove any
  building-wide water behaviour, because there is none to prove — see below.
- No frame shows a player physically performing a verb; the apparatus is worked
  through the same public preview and commit seam the shared panel uses.

## Executable proof

Every run went through `tools/run_godot_serial.ps1`.

- `MaintenanceBallcockTest.tscn`: **PASS 52/52**. The book validates, holds the
  25–40 second window at five verbs, and completes the six-verb vocabulary. The
  order is enforced; all three rejection reasons name themselves. And the
  physics: a sound float and a waterlogged one ride at the same mark; leverage
  alone will not close it; a sound float alone will not close it; together they
  do; closing force really is the product and not a lookup; a dry witness under
  a shut stop proves nothing.
- `MaintenanceBallcockLiveTest.tscn`: **PASS 26/26**. In the real Orison: the
  apparatus stands on the real tank's south face at a standing hand's height on
  the deck, the float rides within the tank's own height, the overflow
  discharges over the real water butt, the reach opens the authored activity by
  name, the whole chain lands, and **the boiler's water is untouched and
  published no state while the roof was serviced.**
- `MaintenanceActivityTest`, `MaintenanceActivityLiveTest`,
  `MaintenanceServiceRoundTest`, `MaintenanceJobTest`,
  `MaintenanceDumbwaiterLiveTest`, `MaintenanceInterlockLiveTest`,
  `InteractionInventory`, `ServiceWireResponseTest`: all **PASS**.
- `WalkTest` (FAST): 2 failures — `production spine loads the one authored job,
  the chirp hunt` and `boiler's long parts list stays merged (23 meshes)`. Both
  **pre-existing**: identical failures at identical lines on a clean `43b3aaf`
  with these changes stashed.
- `WalkTest` (`WALKTEST_FULL=1`): every roof check passes — walkable roof floor,
  four ventilators at 8/32 meshes, all motors on the roof, belt guards findable
  and refusing on a real ray, **all 3 roof fixtures still terminating at the
  real roof riser** (no light was added), and the monitor-door egress walk out
  onto the roof. 395 checks green, the same 2 pre-existing failures, cut later
  by the mandated 60-second ceiling.
- `PresentationAudit`: no overlap, support or id-convention finding against
  `ROOF_TANK_BALLCOCK`.

## Ownership

The prop owns its apparatus and nothing else. **There is no water system in the
Orison to join** — the only real water owner is `BoilerProp`, a steam plant's
feedwater, deliberately untouched and asserted unchanged in the live test. The
apparatus holds its own local condition, closes no job, advances no case,
creates no Dream fact and adds no save owner. Only `apply_maintenance_result`
may mark it serviced — and even that is refused if the valve cannot actually
hold.

Placement is one new `if floor_nodes.has("ROOF"):` branch in
`orison_detail_pass.gd`, the same hand-authored seam SR7-A and SR7-B used.
**`building_root.gd` is not touched**: unlike the elevator interlock, this
apparatus has no runtime owner to bind to.

## What this does not yet close

- One tank, one landing of service. Nothing else in the building knows the
  tank exists, and servicing it changes no tap, no pressure and no resident's
  bath. That is honest rather than incomplete — there is no water model to
  join — but it is the obvious next thing.
- The apparatus is not on the Service Round route and no job, case or resident
  refers to it.
- The seat is modelled as sound. GB 190,216,359's renewable screw-threaded
  seating is cited for the mechanism and for the leverage argument, but a worn
  seat is not a second fault here; one fault, well taught, was the brief.
