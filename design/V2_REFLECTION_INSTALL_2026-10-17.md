# Bounded room reflections and ceiling shadow repair

Evidence class: **INERT**. Installation report; no whole-world appearance or
human acceptance. Test-written surface contracts remain separate evidence.

REPORT - V2-REFLECTION-INSTALL - 2026-10-17

Branch / tested HEAD / origin/main / merge-base: main / **fdac253b** /
**e0b0dd29** / **e0b0dd29**, before this checkpoint commit.
Worktree clean at end: no; inherited receipt/capture, M08F test and enamel
metadata edits remain outside named staging. Protected paths: 17/17 unchanged
against the merge-base at tested HEAD; no protected path staged. Selector: v2,
with explicit v1 rollback retained. Ledger before -> after: not recounted;
requirements_changed: []. Full V2 remains incomplete.

## Installed behavior

The production V2 root now owns one room-reflection manager. It follows the
active viewport camera, derives room bounds from the actual layout, caches at
most three room probes and excludes the carried lamp from reflected captures.
Real circuit signals invalidate cached illumination; periodic refresh uses
each probe's own alternating transform displacement. Interleaved refreshes
previously could repeat a transform and leave UPDATE_ONCE stale.

Sky remains available through openings. Atlas capacity is sixteen rather than
the engine's default sixty-four, retaining the original 256-pixel face size.
The extra capacity accommodates existing diner/dream probes; this is not a
measured percentage memory-saving claim. Compatibility/headless rendering keeps
its prior lighting. No new direct lights or physical-material overrides ship.

The three-room ceiling comparison isolates concentric bands as self-shadow
artifacts: they survive a plain neutral test material and disappear with the
room fixture's corrected shadow culling. Native fixed fixtures now share the
already rendered native-front policy. Energy, range and shadow biases retain
their owners. Plain diagnostic materials never ship as surface replacements.

## Checks and limits

Before the ceiling repair, the source-bound installation comparison passes 56 checks across the watch
board, 2B radiator and boiler. Actual loaded normal frames are valid on 98
StandardMaterial3D surfaces / 879,999 draw vertices, including reuse. Local
reflections improve fittings and illumination in the lit rooms; the carried
lamp dominates the board. This does not close coarse plaster, timber/glare,
the blank boiler gauge or all remaining modeling defects.

The earlier candidate lifecycle run passes 223 checks over two world
generations and 36 visits to six rooms; the no-candidate control passes 197.
Both finish with 36 nodes / 14,395 resources in each teardown. These used the
earlier manually installed candidate and old atlas capacity, not the final
production installation. Their actual sources remain separately pinned.
Steady frame intervals near 20 ms are not GPU timings; capture acquisitions
reach roughly 53–86 ms. Capture hitches and wider-room origin/appearance
qualification remain open. Six tested clear origins do not qualify all rooms.

Both candidate and no-candidate control report seven retained Texture RIDs.
The matching Godot 4.7.1 reflection-atlas issue supports an engine explanation,
but does not prove all application allocations leak-free. No warning is hidden
and no engine binary is replaced. The earlier rejected World3D workaround
remains historical evidence in the previous report.

The first full installation surface run fails normally: 69 native radiator
steam effects are misclassified as physical stock, and a sink-review helper
uses a freed node from a stale traversal snapshot. Its original FAIL contract
and raw logs are retained. Steam classification now requires the exact native
owner, its LocalizedUnionVapor subtree, translucent StandardMaterial3D and
existing steam role; physical radiator stock still requires full PBR. UV and
sampled-texture mip/filter checks still apply to effects. The sink review
snapshots only actual kitchen taps before yielding and reports invalid targets.

Future surface qualification also requires the matching windowed suite receipt
and byte-identical compressed stdout/stderr, rejecting renderer or script errors
even if a helper leaves a misleading PASS contract. Focused tooling tests pass
25 checks; reader audit has zero new unread fields; all 1,253 referenced surface
images pass static import policy. Static import checks alone prove no loaded
mip chain or appearance.

The final windowed surface run passes 27,037 checks in 345 seconds, with zero
script errors or failed checks. Its test-written schema-2 contract binds the
unchanged 4,925 rendering inputs. Independent inventory audit and full packet
qualification both pass: 25,651 draws, 16,613 meshes, 6,087 materials and 474
loaded textures; zero unresolved UV/PBR/mip/filter findings. The canonical
surface packet is updated, preserving its prior qualification files separately
and retaining its previous images. The seven-Texture warning remains visible.
Save reconstruction is explicitly NOT_EXECUTED in this surface contract.

The installed ceiling review passes 2,008 diagnostic/restoration checks. All
three ordinary baseline renders now have the corrected shadow culling and no
previous concentric bands. A large angular shadow in 3B predates this fix and
remains a separate lighting finding; bright fixture glare also remains open.
Representative material renders are reviewed only for technical response,
including the still-coarse plaster and shaded roof tank. Four seasonal sky
controls are not four-season appearance acceptance of every physical surface.

The full static/tooling board runs 71 gates and 935 tool tests. Surface,
import, reader, systemic, period, carrier and rulings gates pass. 59 of 61
tool suites pass; two individual tests fail: the live spatial manifest check
and current first-slice gameplay proof. The spatial gate reports 28 new failing,
39 new reported and one stale preserved record against its standing manifest;
the completeness ledger remains incomplete. A read-only staged-source overlay
against **fdac253b** adds only eleven test dependencies, removes none and
changes no classification or production dependency. This is not a clean
merge-base gate board, nor permission to rebaseline. First-slice repair/job
runtime proof and broad spatial drift remain unfinished. Candidate verifier
was not run; this checkpoint makes no integration-green claim.

## Evidence and remaining work

Packet: **art/reviews/v2_radiator_cutover_20261017/room_reflection_install**.
It retains separate candidate/control/installed runs, original failed surface
evidence, ceiling controls and LF-hashed source snapshots. Wrapper receipts are
**suite_run**; only the surface test itself writes a schema-2 runtime contract.
The previous **room_reflections** packet remains an unmounted historical stage.
Inventories are gzip-compressed in the archive. Eight representative material
images per surface run are retained; unreviewed batch images stay local in tmp.
The full current qualifying plaintext inventory remains in the canonical packet.

Changes outside expected boundary: none; mechanical, NPC, inventory, case and
save authorities retain their owners. Outstanding: capture hitches, atlas
warning, wider daylight/weather/room appearance, played radiator repair and
custody closeout, native lift dispatch, further geometry/material/interaction
detail and V1 retirement. No owner decision needed; human acceptance is separate.
