# Sewn domestic cushions and retained furniture fit

Evidence class: **INERT**. Geometry and rendered-review report; no whole-V2
completion or human appearance acceptance. Runtime evidence remains separate.

REPORT - V2-SEATING-POLISH - 2026-10-17

Branch / tested HEAD / origin/main / merge-base: main / **0a0311ca** /
**e0b0dd29** / **e0b0dd29**, before this checkpoint commit. Worktree clean at
end: no; inherited receipt/capture edits remain outside named staging.
Protected paths: 17/17 unchanged against merge-base and in the worktree;
selector v2 with explicit v1
rollback retained. Ledger before -> after: not recounted;
requirements_changed: []. Full V2 remains incomplete.

## Geometry and fit

The sofas and armchair use stuffed-panel lofts instead of beveled boxes for
their seat and back cushions. Rounded shoulders join sewn boxing, the upright
panels have fuller crowns and the horizontal panels keep level bearing under
the retained loose cushions. Piping follows the actual cap/boxing junction in
matching cloth rather than a pale cord applied across the old box's side.
Registered custom cloth PBR and its physical texture scale are retained.

Five shared variants serve 57 existing actors. Three upholstered variants
change; both wooden chair variants retain byte-identical position, UV, normal,
tangent and index accessors. Original furniture identities, placements,
seat-height envelopes, feet, bases, rolled arms and nonvisual owners remain.
The final export has eight material partitions and 78,664 unique triangles,
versus eleven partitions and 52,984 triangles before. Fewer partitions do not
establish a frame-performance gain; the extra geometry is a rendering cost.
This is a geometry pass, not newly generated texture imagery or new gameplay.

The first loft had a sharp shoulder; a second rounded it but a context check
found eight missing bearings beneath 2A's two loose cushions. The final seat
panel preserves their level supporting region. Checks are retained unchanged;
the props are not moved and no clearance/contact exemption is added.

Native checks pass: 70 closed stocks, five connected groups, twenty local foot
bearings and eight mapped partitions with finite, metre-scale UVs and valid
corner normals. The linked furniture context checks 132 native furniture
installations, 534 floor bearings, four nearby pairs and retained passive-stock
bearings. Its neighbours use source furniture geometry/bounds; it is not proof
of actual Godot physics or every room's lighting. Two sofa sizes and the
armchair are reviewed in Blender. The candidate GLB is byte-identical to the
canonical reviewed export, despite later provenance-only plan wording changes.

## Runtime and gates

The combined surface scene now validates all seating copies and captures the
five native variants inside its already-loaded production world. It also
checks the loose cushions' actual support and seating-owner teardown. The
qualifier fingerprints the added seating helper so later changes invalidate
old passes. The native blend, source plan and construction projection are also
fingerprinted. One canonical import precedes the full windowed qualification;
seating validation reuses that world instead of adding a separate final boot.

The first composed run fails six support checks (27,798 checks overall). A
focused module run reproduces four misses under 5C's overalls and one under
each 2A loose cushion. An imported-mesh bench isolates the engine's short-ray
misses: a longer ray hits the same expected surface within 5 microns. Its 16
bearings pass the unchanged 40-micron/owner/normal conditions, and all sixteen
10 mm floating controls fail those conditions. Only the seating query reach
changes; no gap tolerance or geometry/contact exemption is introduced.

The first focused diagnostic has a GDScript inferred-type error and is stopped
after that error is established, preserving its receipt and source. The type
annotation is corrected before the reproduced contact run. Neither failed
diagnostic grants runtime proof. Native checks, the failed composed run and
the isolated imported-mesh bench remain distinct evidence scopes.

The 25 focused surface tooling tests and six fabrication tests pass. Reader
baseline: zero new unread fields. Broader completion, spatial and first-slice
gameplay findings from the preceding full board remain open; this report does
not waive them or claim a clean candidate verification.

The repaired windowed production run passes 27,798 checks in 347 seconds,
including all 57 seating actors, supported stock and teardown. Source inputs
remain fixed throughout. Independent inventory audit and packet qualification
pass: 25,642 draws, 16,610 meshes, 6,084 materials and 474 loaded textures; zero
unresolved UV/PBR/mip/filter findings. The 4,929-input qualification packet is
published with the prior packet preserved separately. Source/receipt/log/review
hashes agree. The seven-Texture renderer-shutdown warning remains visible;
save reconstruction is explicitly NOT_EXECUTED by this surface test.

The three changed upholstered variants are reviewed in the composed game.
Their shapes and retained stock read continuously, but the warm carried-light
views flatten the fine fabric finish. Ordinary diffuse-light balance, richer
cloth detail and photoreal appearance are still open. The earlier broad board
is not rerun for this batch; affected surface/fabrication tools and the reader
gate are rerun. Candidate verifier and clean merge-base board comparison are
not performed, and no integration-green claim is made.

## Evidence and remaining work

Packet: **art/reviews/v2_seating_polish_20261017**. It preserves neutral
baseline, rejected and final candidate views, source/asset pins, unchanged-chair
buffer comparisons, the failed context check and final native checks. Binary
authorities remain in their canonical repository paths. Raw logs are gzip
compressed with original bytes; diagnostic captions are not runtime proof.
Archived inventories are compressed; the canonical current packet keeps its
qualifiable plaintext inventory. Unreviewed batch images remain local in tmp.
The stale, empty Git index lock was quarantined after verifying that no Git
process was alive. No other task's Godot process was stopped.

Open: room lighting/material balance, cloth aging and richer resident-specific
upholstery, remaining furniture/prop detail, first-slice repair/job proof,
native lift dispatch, broad spatial drift, weather/exterior appearance and V1
retirement. No owner decision is needed; human appearance acceptance is separate.
