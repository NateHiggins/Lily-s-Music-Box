# DT-5 — BOBBING FOR APPLES

The procedural limb no longer extrudes linearly as soon as `EMERGING` begins.
For the first 56% of the existing 3.4-second emergence interval, its still
hidden sensory club palpates three places behind intact membrane tissue. Each
press rises and completely recedes before the next. The third place yields;
visible length and membrane release then advance on separate smooth curves, so
the tissue clings and lets go progressively instead of popping open.

The membrane remains a displaced surface, never a portal or topology owner.
No collision, target selection, field owner, save fact or case behavior moved.

## Production proof

[`contact_sheet.png`](contact_sheet.png) records twelve named landmarks in one
Forward+ production `OrisonRoot`, in the real 2A room, from one fixed camera
under the player's own lamp:

- `P1`–`P3`: three spatially distinct full presses and their three retreats;
  no limb geometry is through during these frames.
- `R1`–`R4`: independently measured release values 0.19, 0.45, 0.68 and 0.94;
  the club appears first, then the weighted limb follows while the membrane
  continues to cling at the root.
- `Z_control_a/b`: a frozen identical-state A/A pair after the sequence. Its
  normalized full-frame RMSE is **0.00000913426**, the live-render floor for
  the capture.

The source frames are retained beside the contact sheet. The harness captures
behavior landmarks rather than arbitrary timestamps and logged all three
presses, all three retreats and all four release thresholds in the single run.

## Contract

`DreamTentacleTest.tscn` passes **24/24**. Its independent 60 Hz behavior sweep
proves three distinct sites, a retreat below 0.12 pressure between presses,
zero visible growth throughout the search interval, intermediate release and
monotonic completion. The complete production controller remains below its
existing CPU limit at **0.656 ms/frame** in the same run.

This closes DT-5's behind-membrane search and progressive-release work. The
full canonical BULGE → EMERGENCE → SEEK → CARESS → FLINCH → WITHDRAW rendered
sequence remains open; this is not a waking case-loop claim.
