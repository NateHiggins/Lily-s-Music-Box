# Common surface charts for fixed city roof hardware

Evidence class: **INERT**

Classification: **ADAPTATION**. This continues the published mast and aerial
fabrication at **c1d7ec32943d65aa8e2d78e489eea37da5279a63**. It corrects repeated
texture bands on their tubes, plates, brackets and terminals. Geometry,
collision, source attachments, original shell ownership and live behavior remain.

## Mapping and exact geometry comparison

The shared native authoring helper **scripts/fabrication_uvs.py** projects each
triangle onto common surface axes. Broad vertical faces keep their vertical
axis across adjacent triangles. Horizontal caps use a common horizontal axis.
Whole catalogue-tile offsets preserve texture phase while reducing UV magnitude.
This removes the visibly repeated small patch caused by giving every triangle
a fresh local origin and differently oriented longest edge.

The helper checks the actual float32 UV round trip, including the 1-V export
conversion, and its expected projected tangent. Microscopic joints that cannot
represent that chart receive a checked local edge chart. The mast export uses
ten such charts; the aerial export needs none. All triangles remain subject
to the existing unit-basis, derivative, handedness and metre-scale checks.
Standard runtime tangents derive from the completed exported primitive. The
authoring guide is removed during export; no portable mesh is edited afterwards.

Both native builders bind the shared helper, their own source and the catalogue
in the generated source fixture. **tmp/city-uv/geometry-comparison.json** compares
the old and new portable meshes. Every expanded indexed triangle position and
normal and every draw's node pose is identical. Original records, registered
offsets, fitted plate contacts, spans, inventories and counts also match exactly.
The mast export remains **223 draws / 54,397 triangles**; the aerial export
remains **271 draws / 143,058 triangles**. Shared-vertex deduplication changes
the vertex inventories from 163,191 to 162,835 and 429,174 to 428,818 respectively.
It adds no draw or physical surface.

Original metal, bronze, brass and ceramic maps, tile dimensions and normal
strength remain. The fifteen catalogue visual locks and shared MatLib projection
remain. No material table, lighting, actor, input, key or service change is made.
Oversized ceramic cracking and heavy bronze patina remain distinct texture
findings after the chart correction.

## Management report and validation

REPORT - CITY ROOF HARDWARE SURFACE CHARTS - 2026-10-03

Branch / HEAD / origin/main / merge-base: named-path canonical **main** candidate
over **c1d7ec32943d65aa8e2d78e489eea37da5279a63**. Exact identity, completed runs
and publication status belong to **tmp/city-uv/verified/verification.json** and
the bound publication report. The complete clean baseline is
**tmp/city-aerials/c1d7ec3-clean-board.json**. All 47 static gates compare without
new regression; reader NEW unread, protected 17/17, default V2/explicit V1 rollback
and unchanged ledger remain required. This INERT record promotes no requirement.

Reopened native files check every original closed positive stock and connected
fabricated tree/assembly, current source bindings, relative images, UV layers
and bounded export. Native aerial inspection repeats 425 exact original-owner
bearing samples, 105,412 stock-edge clearance rays and 340 convex-mass vertex
tests. Close source renders cover plates, anchors, brackets, collectors and
ceramic terminals. Installed mast and aerial suites repeat their strict mapping,
identical physical-face/world-pose checks, all 925 bearing samples and 183 clear
spans, with production comparisons. MaterialLibrary checks retained catalogue
maps. Controller routes and saved resident keys retain the immediately preceding
eleven-suite geometry verification because every physical triangle and all
runtime code remain identical. The exact geometry comparison records that limit;
unchanged earlier receipts keep their real source head.

Changes outside the native/export/fixture paths: hash attributes, the shared
authoring helper and documentation indices. No audit code, baseline, spatial
manifest, threshold, original shell asset or runtime script changes.

Open work remains: fourteen neighbouring tanks and 25 beacon housings; city
weather joints and independent service/drainage closure; ceramic/bronze and
broader family material review, including public stairs/sheet metal and timber
grain. The tmp-only tank study needs final cap-skirt fit and installed proof.
Heating cuts remain parked. Mina and her first twenty clips, the gentler waking
lamp and the owner's capture artifacts remain. Render counters are observations,
not FPS proof. No whole-city or structural-capacity claim follows from UV mapping.
Decision needed from owner: none within the authorized continuation.
