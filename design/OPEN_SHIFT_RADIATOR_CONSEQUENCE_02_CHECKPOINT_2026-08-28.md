# Open Shift Radiator Correction · consequence_02 · 2026-08-28

Status: **TECHNICAL PASS · RADIATOR-SPECIFIC HUMAN ACCEPTANCE PASS**

The earlier Open Shift radiator images are retained as the required control,
but are superseded as acceptance evidence. They showed the prop at semantic
anchor height on a blockout sill, with the service set and flare obscuring the
mechanism. The Open Shift human gate cannot pass on that packet.

## Correction

`F02_B_RADIATOR_01` remains the sole `RadiatorProp` and WorkOrders mechanism
authority. Runtime composition now distinguishes the accepted chest-height
interaction anchor from the permanent installation plane: the assembly drops
0.75 m locally so its cast feet meet the F02 floor while the semantic identity
and player service stance remain unchanged.

The v2 blockout's `F02_B_RADIATOR_MASS` and `F02_B_RADIATOR_USE` reservation
boxes were the large display-plinth obstruction seen in the rejected packet.
Production v2 composition now hides those two superseded boxes and disables
the old mass collision when the real radiator mounts. The semantic anchor,
`F02_B_RADIATOR_STANCE`, and its clearance envelope are preserved.

The body is ten instances of one shared authored cast-section mesh. Each
casting has a narrow vertical waist and substantial top/bottom header
shoulders; two cast feet, wall stand-offs, localized floor rust and an
inter-section dust shelf explain its weight and maintenance history. The
shared mesh uses the project's period cast-iron texture set and per-instance
temperature/enamel modulation rather than a decorative node tree per ridge.

The installation includes a floor riser, angle-valve body, rising stem,
bonnet, packing nut, wrench-flat union, shared steam/condensate branch, air
vent, localized mineral residue, damp patch, union vapor and porter tag.
Brass is confined to service fittings. Oil, rust and dampness occur only at
handled or mechanically credible surfaces.

## State presentation

- Normal heating: supply-end-to-far-end temperature gradient.
- Hammer: small phase-delayed movement per section plus pipe response; the
  complete appliance does not wobble as one object.
- Wrong valve: the visible handwheel/stem stops at 42%; only near sections
  remain warm.
- Abandonment: the union physically backs off; local vapor, mineral residue
  and dampness appear.
- Porter shutoff: stem closes, castings cool, and a physical tag hangs at the
  valve.
- Repair: union seats, vapor/dampness clear, valve opens, and sections warm
  evenly.
- Cooling: valve remains shut and retained heat fades without a porter tag.

Seven carrier-free public surfaces expose immediate actions: listen, feel
temperature, inspect vent, inspect union/packing, turn the visible supply
valve, open the union, and commit the repair. The commit surface appears only
after WorkOrders reaches the existing `repairable` stage.

## Evidence and acceptance

The 15-frame radiator sheet lives at
`art/renders/open_shift_v1/2026-08-28/consequence_02/radiator_specific_sheet/`.
Its first frame is the retained previous-model control; frames 2–15 are fresh
renders with the player lamp/device overlay hidden and one restrained practical
light. No objective UI or developer annotation substitutes for the mechanism.

Automated checks cover floor contact, wall/window envelope, service reach,
detachment, state reconstruction, interaction gating, and bounded mesh/draw
cost. The focused result is **20/20 PASS** with one shared 10-instance casting
MultiMesh, 18 mechanically/material-distinct MeshInstances, and 13 materials.

Regression results:

- radiator rebuild objective suite: 20/20 PASS
- maintenance service round: PASS
- maintenance activity: PASS
- Open Shift situation/work/ignore/abandon/meddle: PASS
- Open Shift two-root save matrix: 17/17 PASS
- Orison v2 M08F runtime: 29 checks PASS; selector remains v1 and production
  layout remains byte-stable
- radiator evidence capture: 15/15 at 1600×900, 6.488 seconds

The known M08F headless shutdown disposition is unchanged: both M08F and the
new focused suite report the same four retained Ogg decoder objects/two
`appliance_pop.ogg` resources owned by the ServiceSet receipt playback path.
No radiator stream is named in the retained chain, and the successful
windowed evidence run exits without that warning. This correction does not
claim that pre-existing headless teardown debt is repaired.

## Owner verdict

The owner reviewed the committed radiator-specific packet at commit
`f57289648ba671c3e6a1f25f8fe7fc7989c72731` and supplied this verdict on
2026-08-28: **HUMAN ACCEPTED**.

The owner found that the radiator reads as a credible, aged cast-iron radiator
with understandable plumbing, valve access, sectional construction, and a
strong gameplay-distance silhouette. Three minor items remain open as
non-blocking art debt:

- leakage bubbles resemble white eggs more than water or steam;
- the valve assembly is slightly oversized;
- pipe joints and wall/floor penetrations could use subtler collars.

This verdict closes only the radiator-specific visual gate. Open Shift as a
whole remains pending. It does not authorize M09, M10, selector cutover, v1
retirement, or any production-default change.
