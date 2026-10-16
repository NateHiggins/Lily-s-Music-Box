# V2 lobby heating and waiting bay — 2026-10-16

Evidence class: **INERT**. Construction and diagnostic report. This document
is not runtime proof, a completion checkpoint, or human acceptance.

The lobby now has its retained nine-section radiator, sharing the original
H-A supply with 1A. Nineteen emitters are installed; the original 23-demand
heat budget remains intact. Four demands belong to restricted cells and remain
uninstalled. Their graph identities and sealed thresholds are retained.

The shared takeoff replaces 90 mm of an existing straight with a hollow,
socketed tee. Parent flow remains continuous. The child branch drains toward
the supply, uses three additional hangers, passes through its authored floor
aperture and collar, and joins the radiator through a hollow union tail.
All 413 previous hangers remain unchanged; the assembly now has 416 hangers,
19 floor sleeves and 18 short-body tails. No duplicate riser outlet was added.

The regeneration chain is **tools/plan_v2_heating_takeoff.py**, the pinned
**art/blender/heating_distribution/base18.blend**, the native fitting review,
assembly integration, existing seven-batch exporter and portable native
packager. The packager saves and reopens the installed source, checks exact
geometry/UV identity, and resolves three relative PBR image paths by hash.
The fixture binds source inputs and both native and exported assets.

Native review checks all 1,705 stocks; the local tee/socket prototype passes
50 probes, and the full assembly passes ten through-flow probes. Export
round trips preserve all seven batches with zero UV failures. Rendered native
views were reviewed before the composed diagnostic.

The first composed attempt could not compile its diagnostic; its timeout is
not a pass. The next execution exposed a real overlap between the west lobby
bench and the radiator. The bench now occupies the restored west waiting bay,
still west of the entrance. Its original model, material and collision remain.
No NPC routine, save authority or original radiator mechanism was replaced.

The first broader surface check additionally rejected the bench north arm
blocking the established west-bay walking leg. Its failed run was interrupted
by stopping only its verified owned Godot processes; its wrapper and failure
are retained under **diagnostics/blocked_bay/**. The seat now leaves 150 mm
at the street wall and clears the original diagonal approach. The focused
diagnostic now executes both original movement targets with the ordinary
player controller. Both pass without changing the route or player collision.

The final diagnostic receipt is **art/renders/orison_v2/heating_lobby_20261016/clearance/lobby_clearance.log.receipt.json**.
It completed with exit 0, zero diagnostic failures and zero script errors.
The player actually grabs the valve, turns it through mouse motion to each
stop, and releases it. Every bench mesh lies within the waiting bay; camera
rays reach all reviewed supply connections. Loaded UV/PBR mip chains and
short-body tail elevations pass. This test publishes no runtime contract.
Its captures were inspected. Earlier **composed/** views describe the
previous bench position; **clearance/** is the current focused result. The bench view is very dim, so artistic lighting
acceptance remains open. Seven texture RIDs still warn at engine shutdown.

Thirty-nine heating tool tests pass. Reader audit reports zero NEW unread
fields; texture import policy checks 1,244 referenced inputs with zero missing
or wrong settings, and mesh UV import policy reports zero failures. Five new
spatial records were individually reviewed and added; exactly two existing
lobby radiator records gain the newly explicit V2 target. All other manifest
records retain their order and classification.

The source acoustic ownership audit now has 357 unresolved identities rather
than 358 because the lobby radiator has an explicit anchor. This is source
ownership discovery, not an installed acoustic graph or listening acceptance.

## Management report

REPORT - V2-LOBBY-HEATING - 2026-10-16

Branch / parent / publication target: local main / **9d03616c** /
**codex/v2-direct-manipulation-checkpoint** only. No push to main is authorized.
The shared checkout retains inherited dirty imports, UIDs and review files;
only named owned paths are staged.

The final focused diagnostic and native review pass. Broader surface,
first-slice, installed save, apartment access, dumbwaiter and roof contracts
are being re-executed against the frozen source. Previous receipts do not
prove this changed batch. Clean-checkout verification and publication remain
pending until those results have been independently qualified.

Full V2 remains incomplete: restricted-cell representation, acoustic migration,
remaining geometry and artistic polish, whole-game performance and human
visual/navigation/listening acceptance are still required. No human acceptance
or general photorealism is inferred from automated surface compliance.

## Verification throughput

The completeness auditor now reuses runtime and surface digests only inside
one invocation, then fully rehashes both consumed domains before returning
a ledger. No global cache, mtime shortcut, receipt rebinding or status rule
change was added. Eight focused tests cover edits, additions, removals,
same-size edits with restored timestamps, separate invocations, cross-checkout
misuse, surface changes and rejection at the ledger return boundary.

A comparison against the parent implementation reports identical full JSON
payloads and exit status, with elapsed time falling from 32.016 to 7.281
seconds on this checkout. Both subprocesses use PYTHONHASHSEED=0 because
existing set-based packet traversal otherwise changes diagnostic note order.
The comparison payloads and runner are retained under **audit_performance/**.
The existing 108-test completeness suite currently passes 107 tests; the one
live-checkpoint assertion correctly fails while changed runtime receipts are
stale. It must pass after actual contract renewal, not be weakened.
