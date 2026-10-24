# Handheld cartridge rebuild after rejected mechanical detailing

Evidence class: **INERT**. Native construction study and diagnostics only.
The owner rejected the preceding joints pass as intersecting primitive stock.
Neither the rejected pass nor this replacement is installed or accepted gameplay.

## Research and change of approach

The [Underwood manufacturer manual, copyright 1920](https://site.xavier.edu/polt/typewriters/Underwood3-4-5-1920.pdf)
identifies the platen, paper clamps, feed rollers, carriage way rods and ribbon
guides. Its ribbon replacement diagrams explain the connection between reels
and printing point. The [NPS museum photograph of a 1923 Underwood](https://www.nps.gov/long/blogs/underwood-no-5-typewriter.htm)
was inspected visually in the browser: it shows a carrying frame and supported
shafts rather than bearings placed independently in space.

[US1548168A, published 1925](https://patents.google.com/patent/US1548168A/en)
separates character selection from impression: a selected type on a rotating
disc is pressed against the recording medium by a hammer. The
[Smithsonian Hammond record](https://americanhistory.si.edu/collections/object/nmah_850021?form=FUNPYRYGFFP)
describes the earlier type-shuttle/hammer family. These inform the fictional
compact selector concept; this is NOT a reconstruction of either mechanism.
The [1926 continuous-paper support patent](https://patents.google.com/patent/US1585581A/en)
also supports reasoning about a retained roll feeding around the platen.
No reference photograph, drawing or scan is committed or used as a texture.

The first attempt added bushes, brackets and a return spring to the old
arrangement without settling its printing architecture. The owner correctly
rejected it. Its recipe and logs remain under **rejected_joins/**; its rendered
views remain under **mechanical_joins/**. Do not call these repairs accepted.

## Applied native construction

The new **radiophone_printer_cartridge.py** owns a cartridge laid out from the
print datum: platen centre Y=-30mm, Z=44mm, radius8mm. Supply paper is below it
at Y=-58mm, Z=16mm, radius12mm. An external tangent joins the two rollers;
the web wraps around the platen and exits vertically onto the reading bed.
The side-section render shows this complete route without the case hiding it.
The previous top-roll/downward-feed arrangement has been removed.

Two contoured, radiused carrying frames have actual machined bores for the
reel spindle, platen and two way rods. Bushes insert into these bores. The
platen shaft passes through the frame cheeks and out to retained finger wheels.
Cartridge feet meet the chassis returns. These are source-authored joined
assemblies, not cylinders laid over a solid plate to imitate a bearing.

The carriage bridge has two rod bores. Its impression cradle is a hollow,
machined frame holding the selector spindle, with paired spring leaves for
the short impression stroke. A native **Impression** shape key describes leaf
deflection without a resting solver. Separate **TypeSelector** rotation and
axial bank shift are staged in the native selection view. The three-bank,
sixteen-position type-cylinder is a fictional compact layout, not a historical
manufacturing claim. Its type seats are still blank in the exported asset.

Ribbon reels now rotate about vertical axes, keeping ribbon width vertical
through to the printing line. The lamp mount is a single profiled yoke with
drilled trunnion holes and pins, supporting a hollow lamp shell and separate
lens bezel. The earlier unrelated spring/drum detail was removed.

## Issue log

| Location | Reproduction / severity | Evidence | Repair | Verification |
|---|---|---|---|---|
| Old printer | Follow paper from upper roll to output; direction and print path unresolved, high | Rejected renders and recipe | Lower supply roll, tangent, platen wrap and upright bed | Native side section reviewed |
| Bearings | Look through supposed shaft seats; no coherent common frame, high | Rejected source | Contoured carrying frames with boolean-machined bores | Native front/section views and source UV checks |
| Impression head | Examine moving block; no defined character selection, high | Owner rejection | Hollow cradle, separate indexed selector and bank shift | Native selection/impression staging only |
| Early cartridge build | Exact booleans leave coplanar slivers, medium | Original v2 failure log | Remove repeated through-bore cuts; dissolve redundant native coplanar boundaries | Unmodified metric-chart/export checks pass |
| Export | Direct GLB write encounters a Windows file lock, medium | Original publish failure | Repository staged export and replacement helper | Final native build succeeds |

## Verification and limits

Review packet: **art/reviews/v2_handheld_20261023/cartridge_rebuild/**.
It includes front, service, rear, printer, lamp, selection, impression and side
section renders. Final export:33 mesh partitions,21078 triangles, inside the
existing36-partition/35000-triangle source budget. UV audit has zero failing
surfaces; tangent agreement is at least0.9999917. These are native measurements,
not proof of draw cost or improved frame time. Reader baseline still reports
the same33 NEW uninstalled street/tent findings; no new baseline was frozen.

The native construction is more explicit, but operation remains unqualified.
The final selector drive, type faces, feed/index linkage, contact at impression,
driven flexure, full-travel clearance, service-door leaf attachments and runtime
material/optical bindings still need work. Staged poses are not an exercised
printing cycle. Do not install this asset by simply changing MODEL and claim
that a moving mesh is a working printer. Existing controls, WorkOrders, paper
history, lamp and all gameplay authorities remain unchanged.

No Godot process was launched. The owner's approval requirement still applies.
After the construction is credible, the next approved batch must bind actual
state, verify actual input, imported surfaces/mips, readable screen framing and
matched occupied-world frame-time distributions. Broad V2 goals remain open.

## Report

Branch:codex/v2-acoustic-topology, starting HEAD0879d20f. Named native source,
candidate asset, review and documentation paths only; unrelated spatial
dependency-manifest work remains unstaged. No ledger promotion, runtime
contract, clean merge-base gate board or management candidate certificate.

NEEDS-OWNER: mechanical appearance remains subject to owner review; no new
Godot permission has been given.
