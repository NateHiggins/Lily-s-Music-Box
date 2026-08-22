# The Dream Field — the body that will not fit

Ruling: `design/DREAM_FIELD_DIRECTION.md`. *"The Dream Field is not fog
surrounding the antagonist. The Dream Field is the antagonist's infinite
body failing to fit into three dimensions."*

## DF-1 — the field itself (2026-08-22)

`DreamFieldState` is the one canonical resource everything will consume —
the hidden coordinate `dream_w`, the shared biological clocks
(`pulse_phase`, `breath_phase`, `attention`, `incarnation`,
`mineralization`, `vascular_pressure`, `phase_instability`,
`contact_activity`) and up to eight live lobes. `DreamFieldController`
owns it, and `dream_field_sdf.gdshaderinc` is the same field on the GPU:
capsules, branching tubes, toroids, gyroid folds, ellipsoidal flesh masses
with vascular filaments through them, smooth-min'd together and
domain-warped slowly.

**The one idea that makes it read**, and the one the contract tests: the
controller ADVANCES `dream_w` and never translates anything. A lobe's
apparent radius is

    r_visible = sqrt(max(0, r_total² - dream_w²))

so it materializes out of nothing, swells, splits, becomes a ring,
collapses to islands and disappears **without going anywhere**. A tendril
that appears on both sides of a wall is not passing through it; it is one
body whose cross-section meets our space twice. That costs a square root
and is worth more than any amount of noise-driven wobbling.

Lobes are placed ON the organism — the controller reads the living field's
own strongest nodes — so the anatomy sits where the creature actually is
rather than floating in a room. Their `w` offsets are spread, so at any
moment some are fully here, one is surfacing and most are elsewhere; a
lobe is only ever re-seeded while it is nowhere near our slice, so nothing
pops into or out of existence on screen. `lobe_surfaced` and
`lobe_withdrew` fire as the slice passes, which is what DF-4's incarnation
and DF-6's residue will hang from.

It is **coupled, not commanded** (§14): the encroachment feeds the
tentacle's own pulse, breath, attention, contact and phase instability into
the field each frame, so the two are portions of one organism rather than
one driving the other.

`DreamFieldTest` 12/12 — including the slice function's exact values
(1.000, 0.866, ~0, 0 at w = 0, 0.5, 0.999, 1.4 for a unit lobe), that the
slice really advances, that **no lobe present in our space translates by
even a millimetre**, that lobes surface and withdraw, that the field is
negative inside the body and positive outside, that influence falls to
nothing at distance, that the clocks are shared, and that the state packs
onto a material. `DREAM_FIELD=0` disables it.

Gates: parse, DreamTentacleTest 20/20, encroachment 13/13, incidents
18/18, WalkTest FAST.

**Next:** DF-2 (the air acquires anatomy — fog volumes with negative
density), DF-3 (the depth-aware lens), DF-4 (surfaces incarnate rather than
being tinted — which is what finally replaces the living block's stain look
that was washing out the rooms).
