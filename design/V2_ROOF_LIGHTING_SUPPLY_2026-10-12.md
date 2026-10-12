# REPORT — V2-ROOF-LIGHTING-SUPPLY — 2026-10-12

Evidence class: **INERT**. Section 7 implementation report. No runtime,
spatial or human acceptance promotion follows from this report.

Branch / starting HEAD / origin/main: **main / 0bf5f0d9 / 0bf5f0d9**.
Clean verification baseline: **321d4027**. Original shared owner work remains
separate; only named paths are staged. V2 selection and explicit V1 rollback
are retained. Owner decision required: **none**.

## Changes and boundary

The two existing roof cage lamps now have modeled rigid supply fabric from
the original electrical riser: a hollow extension, bored four-way casting,
two branches, elbow boxes with separate covers, ceiling stays, weather collars
and a rolled steel bridge with wall brackets and six conduit hangers.
The original upper cap is removed at its exact datum; the lower cap remains.
Original electrical stations, circuit switches and light owners remain.

The supply is 53 Blender-authored native parts with metre UV charts and
exported tangents. Existing catalogue iron, galvanized steel and brass PBR
stock is reused. No generated glTF is hand-edited. The lowest external tube
is 2.6775 metres above the retained roof deck. Fixed meshes have matching
native collision; the route must still prove actual player clearance.

Two bounded service ports belong to the original roof bulkhead wall records.
The exterior masonry asset ends below the roof bulkheads; its geometry is
unchanged. The brackets contact the actual 140 mm wall faces at X=5.47 and
X=9.43. A typed comparison allows only the two new wall ports and refreshes
the two current passive-stock provenance bindings; native passive stock is
unchanged. Provenance refresh is not geometric or functional acceptance.

## Verification

The builder rejects nonclosed stock, nonpositive volume and collapsed UV
triangles. All 53 parts pass. The thin bridge angle is directly extruded:
its former Boolean union produced collapsed triangles and was replaced.
The first composed sweep found eight stock surfaces whose small UV charts
collapsed during Godot mesh compression. This asset now uses the existing
narrow UV precision import policy; texture compression and mipmaps remain.
No UV threshold or surface requirement was weakened. The exported GLB audit
passes independently. The 19 surface-policy tools tests pass.
Blender contact rays approach outward wall faces and check hit normals.
Both source wall bores are clear. Neutral catalogue renders show the bridge,
wall bearing and takeoff; installed Godot appearance remains a separate check.

Ventilation/source projection tests: three pass. Reader gate: zero NEW unread
fields. Spatial dependency audit: clean, with existing records preserved.
The mailbox review now observes the unchanged 95-degree/zero-degree production
tween endpoints within a two-second deadline. Its old 0.45-second timer could
expire before tween processing on a slow rendered frame. It neither sets the
hinge nor skips an angle/custody check.

The played roof route completes 59 waypoints with zero failures and zero script
errors (**route1.log.receipt.json**, about 224 seconds). It checks both actual
wall bores, the retired upper/retained lower cap, both independent lamp controls,
original tank service, stairs, doors and perimeter collision. Its installed
bridge render was inspected. This is route/visual evidence, not a schema-2
authority receipt. Its native form/controls are unchanged by the subsequent UV
precision import correction and nonvisual export-safe hash guard.

**surfaces3.log.receipt.json**: 123.65 seconds, 20,121 checks, zero failures and
zero script errors. Loaded census: 23,489 draws, 16,442 meshes, 5,780 materials,
434 textures. All loaded UV, PBR, mip and filter requirements pass against final
inputs. Nine visual records cover current representative captures and played
roof supply/lamps; the mailbox overview is partly occluded by a production NPC,
with its separate pocket detail available. This is not whole-world human review.

**first_slice1.log.receipt.json**: 73.63 seconds, 113 checks, zero failures and
zero script errors. The actual schema-2 contract refreshes the original seven
authority owners, disk save/reconstruction, denial and observed node/audio
retirement. No new roof authority receives a runtime promotion. The existing
seven TextureRID shutdown warnings remain; no process-wide GPU retention claim.

Independent final-input surface qualification: PASS, zero defects. Reader and
spatial gates remain clean; source projection and 19 surface tools tests pass.
Original 283 owner-file hashes remain unchanged. Clean candidate verification
passes for **690c9745** against the authentic complete clean **321d4027** board:
zero regressions, zero blocking reasons, all 17 protected paths unchanged,
selector V2 and no ledger requirement changes. **--no-godot** reuses the bound
canonical runtime runs; the full static gates/tools tests run in a fresh clean
checkout. Complete candidate/base boards and verifier output are archived in
the packet. No regression waiver or replacement baseline is used.

## Remaining scope

The wider V2 build remains incomplete. This batch closes only modeled supply
fabric for the previously installed roof lights. Whole-world navigation,
remaining room/program owners, broader runtime contracts, human review and
V1 retirement still require their own evidence. No whole-V2 completion claim.
The ledger remains **0/1/115/35/132/134** scope blockers and 240 requirements;
this inert report changes no requirement status.

Packet destination: **art/renders/orison_v2/roof_supply_20261012**.

MERGE-CANDIDATE 690c9745dcf6ace62c01bc59a1e80dde5149107a
