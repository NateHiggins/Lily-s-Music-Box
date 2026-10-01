# Fitted radiator wall ties

Evidence class: **INERT**

The production endpoint survey found six floating wall-tie ends: both ties on
**2A** and **4B** stopped 40 mm before their walls, and both on **3A** stopped
10 mm short. This batch fits those ends and adds fixed slotted wall plates.
It preserves the eighteen installed radiators, original one-pipe floor feeds,
HeatBalance, valve/vent/repair surfaces and all existing maintenance state.
Raw architecture and full physical infrastructure remain open.

## Source, construction inference and ownership

**heating_source.json** projects the installed roster into **heating.json**;
the existing semantic anchors own placement and orientation. Actual built
**Wall** mesh/collider bounds supply each bearing datum. The **3A** bearing is
the neighboring **F03_D_MAIN** north wall: a room-name guess would miss it.
No logical heat-budget coordinate is substituted for a physical anchor.

**build_radiator_wall_tie.py** authors an **INFERRED** period attachment:
an 85 × 120 × 6 mm pressed flange, projecting slotted boss, real 46 × 52 mm
opening, two embedded M8 studs, washers and hex heads. One head uses the existing
enamel finish. Filed edges are 0.4 mm; openings and thickness are actual mesh
geometry. **radiator_wall_tie.blend** is 107,949 bytes and the exported
**radiator_wall_tie.glb** is 46,772 bytes. The three imported partitions use
existing **cast_iron**, **metal** and **enamel** MatLib keys, active metre UVs,
unit normals and exported orthogonal tangents. No new texture or lettering.

**orison_v2_radiator_mounts.gd** resolves the nearest actual wall behind each
retained tie before the radiator builds. Only the six measured floating ends
extend, embedding 4 mm beyond the wall face; the other thirty retain 190 mm
spans. Plates stay fixed on their walls while the cast shell pitches through
their slots. Three floor partitions add nine MultiMesh draws and six fittings.
They add no collider, signal, interaction, persistence record or heat authority.
Unconfigured legacy RadiatorProp shells retain their original 190 mm geometry.

## Inspection, routes and costs

**tmp/heating-attachments/before** and **after-fixed** retain 21 matched views:
eighteen eye-height radiator overviews and three closer views behind the fitted
ties. All eighteen paired overviews were inspected as three contact sheets;
all three before/after close views and the independent test captures were
inspected directly. Close observer placement is installation inspection,
not proof of player access. Production lighting and the gentler lamp stay intact;
the inspection observer disables its carried lamp and hides CanvasLayers.

Startup observations were **19.058 / 19.310 s**. The change adds a 46.8 KB asset
and nine fixed instanced draws. These startup samples establish no stable FPS,
speedup or rendering-budget acceptance. The original 2B mechanism cost remains
one section MultiMesh, eighteen mesh instances and thirteen materials.

The scratch inspection JSON assumes the original 190 mm endpoint even after
the correction. Its gap fields are useful pre-change discovery only. Actual
post-change contact proof comes from the independent retained-cap and imported-
triangle probes in **OrisonV2RadiatorWallTieTest**: **367 checks**, eighteen
floor feeds, all thirty-six ties, six fitted ties at three pitch poses, nine
batches, **zero failures**. The plate openings have positive/negative controls;
pitched rod perimeters remain clear and all six fixed backs meet existing walls.

**RadiatorPropRebuildTest** passes **20/20** mechanism, repair-state, reach and
cost checks. Its two earlier bound assertions used global X/Z despite the
connected building's 180-degree frame. They now measure identical limits in
the actual building frame; no dimensions or tolerances were widened.
**OrisonV2CompletionHeatingTest** uses ordinary movement, solid radiator contact
and real E rays on six households. One initial 4D reopen failed; a diagnostic
rerun passed all twelve turns. The final fixture also observes exactly one
physical turn per press. No input/service change is made from that unreproduced
failure. Its failed receipt remains alongside the successful rerun.

The first gate comparison also flagged the geometry fixture's decoder-shutdown
wait as a timer-driven radiator actor. The wait occurred after world retirement;
it now has its own explicit retirement-only scope. Geometry/pitch checks retain
the same order and assertions. No audit code or systemic baseline is changed.

An initial new-helper type-inference parse error is retained in **after.log**;
it was repaired explicitly before the successful **after-fixed.log**. The
runner's stale-cache label does not establish a cache cause for that source error.

## Gates, binding and remaining distribution

The complete clean baseline is **tmp/duct-supports/7b75755-clean-board.json**.
The full candidate comparison and bound suites belong to
**tmp/heating-attachments/verified/verification.json**. Discovery receipts above
are provisional until that clean candidate check completes. Wrapper receipts
and captures grant no completeness-ledger runtime proof.

Three individually reviewed unit references extend the spatial manifest from
**6,335** to **6,338** records. Reader audit reports NEW **0**; require zero gate
regressions, protected paths **17/17**, selector/V1 rollback and unchanged ledger
counts **[7,8,127,42,151,153]** before push. Resident originals/copies, saved
door locks, News Cigars initial unlock, boiler swing/pipework and owner captures
remain preserved.

The floor feeds are endpoints, not proof of fabricated concealed mains. Continue
vertical/branch routing, pitch, supports, sleeves and expansion/access space from
the accepted boiler source. Shop/bar heat and water/drain/conduit still require
their own source trace. This attachment batch does not close those networks.
