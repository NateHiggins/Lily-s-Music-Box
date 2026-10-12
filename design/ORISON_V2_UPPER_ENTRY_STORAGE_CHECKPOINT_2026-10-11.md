# V2 upper entry and storage spatial checkpoint — 2026-10-11

Evidence class: **CHECKPOINT**. Status: **IMPLEMENTED — SCOPED SPATIAL PROOF**.
This checkpoint claims only the eight rooms named below. It is not
whole-building navigation, human acceptance or RUNTIME_PROVEN authority evidence.

## What changed

The open B entry leaf and shallow hallstand pinched the walking path on both
upper floors. The two original hallstand anchors move from z=1.85 to z=2.65 m
along the same east wall. Their native Blender variants, UVs, PBR recipes,
collision generation, semantic identities and all non-visual owners remain.
A typed comparison permits exactly those two positions and twelve purpose-string
clarifications; every other layout value is identical to starting main.
The refreshed fixture bindings are provenance only. Older unrelated drift stays
visible rather than being silently repinned.

The six vestibule purposes now state private arrival, privacy, domestic room
distribution, coat hanging and a shallow shelf. The four A/B sleeping rooms explicitly state enclosed clothing storage;
the principal 5C bedroom states clothing storage;
6C's appraisal room states its actual records and clothing storage. These are
existing native case functions, now described explicitly in the spatial program.
No doorway, wall, household actor, collider or finish is removed to pass a test.

## Eight exercised spaces

| Space | Authored size | Physical proof |
|---|---|---|
| `F05_A_VESTIBULE` | 2.70 × 3.25 m | Ordinary E opens/closes the original entry; actual walking to living room and its side opening into the private distribution hall; coat stand visible. |
| `F05_B_VESTIBULE` | 2.80 × 2.50 m | Actual walk around the open entry to the living-room opening and through the separate bathroom door, then return; relocated shallow stand stays clear. |
| `F05_C_VESTIBULE` | 2.70 × 2.50 m | Actual passage to living room and private hall; access to the principal bedroom and wardrobe, followed by return and entry closure. |
| `F06_A_VESTIBULE` | 2.70 × 3.25 m | Original entry and actual living/private-hall distribution legs; return and closure. |
| `F06_B_VESTIBULE` | 2.80 × 2.50 m | Original entry, relocated stand clearance, living-room opening and separate bathroom passage; return and closure. |
| `F06_C_VESTIBULE` | 2.70 × 2.50 m | Original entry, living/private-hall distribution and separate appraisal-room storage approach; return and closure. |
| `F05_C_BED1` | 3.30 × 3.80 m | Walk through the original privacy door to the clothes wardrobe; player ray/prompt/E opens and closes its native leaves; actual return and privacy-door closure. |
| `F06_C_STUDIO` | 3.40 × 2.50 m | Actual walking approaches and player E open/close both original armoires: clothing in the first, appraisal records in the second. |

The Bible's awake, unlocked start is retained. All six entries start closed and
unlocked and finish in the same state. The sealed scenario is not substituted.
Each of the six independent legs has one explicit initial public-hall placement;
all subsequent moves use the unchanged production controller, collision and E
interaction. No teleport, noclip or collider disabling supplies a walked leg.

## Observed proof and limits

Final **route7.log.receipt.json**: completed windowed in **156 seconds**,
**219 functional checks, 72 walked waypoints, six completed homes, zero failures
and zero script errors**. The test records **108** eye-level rays from three
public-hall positions to three points in each bedroom/sleep alcove and bathroom,
with the entry open and internal privacy leaves closed. Prop colliders are
excluded from successive queries on the same ray until an actual wall or
internal door is found. A notice board, wardrobe or other prop cannot count as
architectural privacy. Geometry stays enabled in the world.

The same world checks the relocated native stands with the existing apartment
finish validator: **84 UV/PBR/actual loaded-mip checks**, zero failures. The
native GLB and Blender bytes match starting main exactly. Blender reviewed both
installed variants against actual source room/floor bounds before Godot; final
composed images show the clear entry, stand and bathroom/living openings.
All six entry overviews, the principal bedroom view and three opened-storage
images were inspected. The bedroom view shows the existing native bed, its
usable floor and clothing case, rather than inferring sleep from a room label.

The test-written **route7/upper_entry_storage_contract.json** binds the actual
root script, all five inherited/checking scripts, current runtime inputs,
observations, full movement trace and privacy-hit identities. All **11** tracked
world/player/entry/storage nodes retire. This route harness does not execute
save/reconstruction or premature-action-denial contracts; it therefore cannot
grant RUNTIME_PROVEN authority status. Its TextureRID shutdown warning is the
existing seven-texture warning, not a claim of zero GPU retention.

Packet: **art/renders/orison_v2/upper_entry_storage_20261011**. Earlier rejected
runs are retained as diagnostics, not acceptance. Full current surface and
first-slice authority renewals are recorded in the accompanying INERT report.
