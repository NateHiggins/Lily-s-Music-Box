# LC-3B / LC-4B — accelerated fauna stages and the first death stain

**Status: the mechanical half is proved; the VISUAL half is NOT.** These frames
record that the production pipeline ran and what it submitted. **None of them
establishes that a life stage or a stain is readable at gameplay distance**,
which is the bar LC-3B/LC-4B was set. Read the "What these frames do not
prove" section before citing any of them.

Captured 2026-08-24 in Forward+ (NVIDIA RTX 4080, Vulkan 1.4.341) through the
production `DreamMazeRoot`, the landed `DreamFaunaDirector`, the five landed
MultiMesh batches and `dream_fauna.gdshader`, lit by the player's own service
lamp. No proof-only creature exists; the harness only drives the room's own
lifecycle clock so a 45-to-150-second life fits inside the 60-second ceiling.

Harness: `game/tests/dream_fauna_lifecycle_shot.gd`.

```powershell
tools/run_godot_serial.ps1 -Scene res://tests/DreamFaunaLifecycleShot.tscn `
    -ProjectPath <checkout>/game -ShotDir <this directory> -Windowed
```

## Frames

All 1280x720. SHA-256 truncated to 32 hex characters.

| Frame | SHA-256 | What it actually establishes |
|---|---|---|
| `00_control_a.png` | `f8622394983c23f28a475b63300dadbb` | Frozen arrangement, exposure 1. |
| `00_control_b.png` | `7d6631a83eff063e1c4f8898af3ea9d1` | Same arrangement, exposure 2. Prices the residual noise. |
| `01_stages_multi.png` | `da1f544783854d7856383438760a693a` | Room clock held at 0.30. Submission carried **all eight stages at once**: mature 12, exchange 4, folded 3, juvenile 2, shed 2, senescent 2, bud 1, stain 1. |
| `02_exchange_contact.png` | `b86a40f7f91e850866ce8a25f972d5e9` | Clock at 0.70. exchange 3, senescent 4, shed 3, stain 2, mature 11, folded 2, bud 2, juvenile 1. |
| `03_senescent_shed.png` | `6d68584e30657fdb3db46e18fb25e657` | Clock at 0.88. senescent 4, stain 7, juvenile 3, exchange 3, bud 2, mature 10, shed 1, folded 1. |
| `04_first_stain.png` | `f03c604534b55283fd85baa2b48d28d3` | One generation completed. 5 marks submitted through **GildersButtons**; memory 14 impressions across 2 rooms, 0 evicted. |
| `05_stain_after_revisit.png` | `9ff7b0037a3da8a6b1aff6da3df1d1e3` | After a real round trip out of and back into the same room: **4 marks returned byte-identical**, 4 remembered while the room was not live. |
| `06_room_wide.png` | `e41a797375f79bc1744d4161f6b5af14` | Wider stand, gait restored. stain 6, juvenile 8, senescent 7, mature 7, exchange 2, shed 1, bud 1. |

The per-frame stage counts above are logged by the harness from the **actual
submitted `INSTANCE_CUSTOM` bytes**, decoded back through
`DreamFaunaDirector.stage_from_stream()`. That part is real evidence.

## A/A control and the residual noise floor

Control A and B are **not** byte-identical. Measured whole-frame normalized
RMSE (ImageMagick, the method the landed proofs use):

| Pair | RMSE |
|---|---:|
| control A → control B | **0.0320637** |

The floor was diagnosed rather than assumed. A 12x16 per-cell decomposition of
the A/A pair puts the variance in a compact band of cells reaching 0.093 while
most of the frame sits at 0.0001–0.005. Cropping that band and differencing it
shows the **Klimt architecture and molten-gold surface shimmering on live
`TIME`** — `dream_klimt.gdshader` and the molten pass, neither of which this
lane owns or may freeze.

One candidate was tested and eliminated: the fauna shader's own idle `gait` is
also `sin(TIME * ...)`, so the creatures move between exposures even with
their owner stopped. Pinning the existing `gait_amount` uniform to zero for the
measured frames moved the floor only 0.0281 → 0.0270, which is how we know the
gait was not the dominant term.

**Consequence:** every stage-to-stage pair measured 0.0263–0.0289 — at or
below the A/A floor. At whole-frame RMSE the stage changes are not separable
from architecture shimmer.

## What these frames do NOT prove

Stated plainly so nobody cites them for more than they carry.

1. **They do not show a legible life stage.** The staging never got the
   creatures properly into frame. Three successive attempts were made — aiming
   at the room centre, then at the submitted-instance centroid, then at a
   per-room centroid at 1.05 m — and the final frames still show architecture
   with the fauna either off-frame, behind a column, or a few dark pixels. The
   last attempt is in the harness as written.
2. **They do not show a legible stain.** Same cause.
3. **The A/A floor is too high to support a visual claim** at whole-frame
   scale, and no region-of-interest measurement was substituted, because an ROI
   is only meaningful once the subject is actually in the ROI.

A real defect was found and fixed along the way and is worth recording: the
first `_fauna_focus` averaged instance positions across **every live room at
once**, which aims the camera at a point between rooms with no creature near
it. It is now filtered to one room. That fix is correct and still did not make
the tissue legible, so the remaining problem is stand selection and lamp
framing, not the focus arithmetic.

## What IS proved, and where

The mechanical contract is proved by executable tests, not by these frames:

- `game/tests/dream_fauna_visible_test.gd` — **21/21**. All eight stages
  round-trip the packed flag byte `[0, 16, 80, 64, 128, 192, 32, 96]` and reach
  the production submission path; every stage keeps full nonzero anatomy
  (smallest axis 0.0300); no packed channel or transform is NaN/INF; a witnessed
  death submits through GildersButtons; each mark spends exactly one Gilder
  instance and adds no batch; repeated deaths coalesce; presentation survives a
  real revisit byte-identically; a new director has none; five batches, the 96
  ceiling, plan, hazards, RealityState and the closed ether ledger all unmoved.
- `DreamFaunaLifecycleTest` — **29/29**, unchanged.
- `DreamFaunaTest` — **29/29**, unchanged.

## Next step for whoever takes this on

The blocker is camera/lamp staging, not the implementation. The submission is
demonstrably correct; the photograph is not. A useful next attempt should pick
one **named instance** from `_records` (as `dream_fauna_trophic_shot.gd` does
for the Loupe), stand a fixed offset from that single instance with the lamp on
it, and verify the creature's projected screen position before capturing rather
than assuming it. Measuring an ROI around that known instance would then also
give an honest floor, independent of the architecture shimmer.
