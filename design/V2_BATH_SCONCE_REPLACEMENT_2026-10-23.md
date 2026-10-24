# Bathroom sconce replacement

Evidence class: **INERT**. Installed repair and rendered review report;
not runtime qualification, subjective acceptance or V2 completion.

## Research and chosen adaptation

The owner identified the bathroom sconce and requested research, relocation
and redesign. The old 170 mm sphere crowded the window/mirror corner and
washed out its own mount in the occupied bathroom capture.

[LACMA's circa-1900 Benson/Powell wall fitting](https://collections.lacma.org/object/115200)
records brass, glass and electrical wire, with small formed-glass shades.
[MAK's Benson wall arm, 1891–1897](https://sammlung.mak.at/en/collect/wall-arm-with-two-fittings_25218)
explains construction-revealing simple forms and visible electrical routing.
[Ingenium's household wall fixture](https://collection.ingenium.ca/en/id/1992.1781.001/)
places this general localized-light vocabulary in early twentieth-century
Canadian homes; its own manufacturing date is unknown. These are period-form
references, not evidence that these exact examples were bathroom fittings.

Our original adaptation is a 144 mm open opal bell, ceramic socket, three-screw
brass gallery, bent feed and oval wall rosette with two fasteners. Reference
pixels are not projected, baked or committed. It uses existing catalogue PBR.
Three active draw partitions replace three old partitions; no extra light or
viewport is added. This is not a measured rendering performance improvement.

## Issue log

| Location / reproduction | Severity | Evidence | Repair / verification |
|---|---|---|---|
| 3B bath, face basin/mirror | Appearance | Earlier **v2_bath_movement_20261023/diagnostic_v1/normal.png** | New bell centered above mirror; leaves window corner free |
| New socket/inner lamp | Construction | **native_v2/inspect.log** disconnected lamp | Connected turned inner lamp; final native checks pass |
| Oval plate and small screws | Surface | **native_v3-v4/inspect.log** metric UV distortion | Metric triangle charts for noncircular plate and low-sided screw heads; no tolerance relaxed |
| Relocated plate | Fit | **installed_context.log** exposes 10 mm wall gap | Correct offset against actual 140 mm partition; **installed_context_v2.log** passes 308 room contacts |
| Powered replacement | Appearance | **world_v1/** still washed out; inherited capture also enabled carried lamp | Lower only this fixture's pool scale and shade envelope; **world_v2/** captures both states without player lamp |

Review root: **art/reviews/v2_bath_sconce_20261023/**. Earlier failed native
and powered studies remain. **native_v5/inspect.log** passes 15 closed stocks,
one connected group, two bearings and three mapped partitions. The installed
family native inspection passes 453 stocks, 28 groups, 56 bearings and 136 parts.
Direct underside rendering verifies the open bell and seated inner bulb.

The authored presentation offset is **[1.17, .53, .38]** in the existing actor's
frame; native stock rotates into the basin wall. Plate center is local
**[15.15, 2.15, -9.87]** on that wall. The original anchor, acoustic identity,
OmniLight, bounce, material, switch and personality owners remain. Emitter and
bounce follow the new socket. The semantic anchor is retained rather than
claimed to have been relocated. Broader acoustic origins remain separate scope.

The first attempted emission change was overwritten by the live light envelope.
The final **envelope_gain** multiplies its existing circuit/flicker/surge curve;
default 1 preserves other fixtures. This native fixture sets .28, with .18 pool
energy_scale replacing 1.05. Existing maintenance-card tuning remains active.
No photographic lens flare is restored. The new fitting remains visibly bright
at its core; mirror checker/grain artifacts persist and are not repaired here.

## Verification and continuation

Final **world_v2.log.receipt.json** is a completed **suite_run**, with 6,588
checks and no assertion failures in its diagnostic JSON. Loaded charts, PBR,
mips, original owners, physical wall contacts, complete family counts, clearance
and circuit restoration pass. Powered/off images were inspected. This uses
programmatic circuit controls and cannot qualify direct player switching,
door/access routes, save/load or whole-world performance. Seven pre-existing
Texture RID teardown warnings persist. No runtime_contract is fabricated.

All 32 surface requirement tools tests pass. Final focused board is retained;
reader still has 33 NEW untracked street/tent fields, spatial has eight failing
and 25 reported findings, and physical imports rejects four untracked street/
traffic source/settings paths. These unrelated files and the spatial manifest
are preserved. An earlier comma-separated --only invocation selected no gates;
its empty board is not validation. Correct repeated --only flags produced the
actual board. Full clean candidate and broad surface/render qualification remain
open. No receipt is repinned as global proof.

Canonical shared branch **codex/v2-acoustic-topology**, preceding pushed HEAD
**7731aa87**; named paths only. Continue the existing closure queue, actual
bathroom collision attribution, hose production/save integration and the other
started requests. The player A-pose is a concept, not an installed avatar.
