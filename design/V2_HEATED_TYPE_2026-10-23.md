# Reverse embossed type and bounded hot-impression presentation

Evidence class: **INERT**. Native preview and unqualified runtime integration.
No Godot was launched; the owner's permission requirement remains in force.

## Owner direction and fiction

The owner requested reversed-letter emboss decals and blurred rapid selection,
then proposed glowing heated type, a short singe and tiny smoke puffs. This
explicitly authorizes lettering in this font-authored physical type overlay;
it is not AI-generated prose or permission to bake signage into other textures.

The candidate now uses fictional heated metal type stamping treated service
paper, producing near-black browned marks. This supersedes its ink ribbon and
reels, which have been removed. It is not a historical reconstruction, an open
flame or an implementation of modern dot-array thermal printing. Modern direct
thermal printing uses heat-sensitive media which darkens chemically rather
than requiring combustion; see [Zebra's explanation](https://www.zebra.com/us/en/resource-library/faq/what-is-a-thermal-printer.html).
The proposed little singe/puff is a restrained fictional material response.
Existing paper history, message contents, WorkOrders and case authorities are
unchanged. No burning-paper destruction or world fire simulation is introduced.

## Applied assets and presentation

**art/tools/build_writer_type_decal.py** authors 48 unique reversed characters
from the existing Courier Prime Bold font. One 1024 x 768 linear RGBA plate stores
OpenGL relief normals and glyph coverage. The relief is calibrated to 60 micrometres
on 3.6 x 3.8mm type seats. This is a relief overlay on registered
**fire_hardware_steel**, not a new physical material key. Primary steel maps
sample physical UV; the font plate samples a second atlas UV. No shared
catalogue definition was changed. All sampled maps still require loaded mip
qualification after the approved import.

**writer_type_native.py** batches 48 planar relief faces into one surface on the
selector. Native sharp and blurred previews show actual reversed faces rather
than letters on an unrelated label. Following the owner's latest direction,
the exposed upper spindle and collector stack are removed. A fixed recessed
shaft terminates inside a flush blind bearing cap in the upper bridge.
The original collector review log is retained.
Upper and lower type banks have opposite 6-degree resting cambers. Separate
LowerSeat and UpperSeat morphs rock only the selected bank flat; the matching
relief faces follow the same deformation. The sleeve shifts axially around the
fixed shaft. The presentation controller coordinates row seating, the 1.55mm
impression stroke and the carrying flexure.
The native animation is separately rendered after the resting GLB is exported;
it is an appearance study, not a Godot printing receipt.

**hot_type_writer.gd** is an optional candidate presentation component. The
existing printer binds it only when a model has both **TypeSelector** and its
emboss surface. Current production still uses the old model, so this branch is
not active in ordinary play. It receives character events from that printer
instead of scanning targets or owning message timing. Whitespace produces no
hot stamp. Unsupported characters use the physical question-mark face while
the complete supplied message remains preserved.

The component provides two rapid visual turns settling on the selected seat,
three local atlas taps for spin blur, bounded selected-face emission, and a
three-particle smoke burst with a 0.10s cooldown. The puff is a soft radial
billboard, not a rectangular opaque card. It reuses a very short, quiet,
repitched excerpt of the already-curated relay hiss for the provisional singe;
there is no runtime waveform generator. Smoke lasts 0.20s; sound is stopped
after 0.045s; the controller sleeps after cooling/particles settle. Power off
and historical-copy review stop the effects. No extra world light, shadow map,
screen texture read, global postprocess, idle spin or continuous smoke solver.

## Verification and limits

Packet: **art/reviews/v2_handheld_20261023/hot_type/**. The final candidate
exports 29 partitions / 19302 triangles, within the existing 36 / 35000 source
budget. Source GLB UV audit has zero failing surfaces; tangent agreement is
at least 0.9999917. Python authoring sources compile and gdtoolkit parses both
GDScript files. These checks do not establish Godot semantic/shader compilation,
correct loaded mip filtering, audiovisual quality, actual character alignment,
or runtime performance. The new texture has not been imported through Godot.

The native GIF demonstrates type-cylinder spin/glow, not runtime smoke/audio.
The current optical opacity, temporal aliasing, first-use particle/shader cost
and singe loudness must be reviewed in the actual held view. Production MODEL
was deliberately not replaced with this still-unqualified cartridge. The
previously documented selector drive/feed/contact and case-joint work remains
open; adding effects does not qualify those mechanisms.

Next approved Godot batch: import, semantic/shader checks, loaded atlas/steel
maps and mips, actual printing/power-off/history behavior, smoke bounds/audio,
idle shutdown, and matched first/steady-print frame-time distributions. Keep
original failures and test-written receipts; no runtime-contract claim is made.

## Issue log

| Location | Reproduction / severity | Evidence | Repair | Verification |
|---|---|---|---|---|
| Writer bridge | Exposed top spindle distracts from head; visual | Native close-up | Recess shaft and close bearing flush; remove collector stack | Final native seated-row renders |
| Type banks | Flat outer banks cannot seat independently; mechanical presentation | Native row poses | Opposite 6-degree cambers and independent seating morphs | Four exported row-isolation checks pass in row_seating.json |
| UpperSeat export | Upper morph also moved lower bank; moderate authoring defect | Original row_diagnostic_failure.log retained | Initialize each key explicitly from resting coordinates | Checker rejects cross-bank movement; all four checks pass |

## Checkpoint scope

Branch: codex/v2-acoustic-topology; starting HEAD 0272413b. Named source, asset,
preview and documentation paths only. Unrelated spatial-manifest work remains
unstaged. No catalogue keys, ledger requirements or protected gameplay owners
were changed. No clean merge-base gate board or management certificate.

NEEDS-OWNER: approve the shared-lane Godot review batch before any launch.
