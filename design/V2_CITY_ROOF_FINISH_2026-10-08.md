# Neighboring city roof finish

Evidence class: **INERT**

REPORT - City galvanized roof finish - 2026-10-08

Branch / starting HEAD / origin/main / merge-base: **main / fdc9d443 / same / same**.

Eleven existing galvanized city roof/trim groups now reuse the approved **roof**
recipe and **zinc_quiet** maps. This reduces broad mottling and specular relief
without changing their semantic metal designation. Bronze, brick, mineral,
soot and brass-mesh groups retain their exact original materials. No catalogue
key, texture, native geometry, collision or hardware placement is added.

The saved native and runtime export remain byte-identical to the starting commit.
Read-only Blender review checks the closed retained stocks/parapet rings and
renders two corners before and after under neutral light. Installed comparisons
use the original city-corner sightline checks. These are elevated diagnostic
views, not proof of player access to neighboring roofs.

## Review and verification

Packet: **art/renders/orison_v2/city_roof_finish_20261008**. The existing city
closure test retains all partition, triangle, mapping, collision and hardware
footprint checks. It now checks both the immutable original material and the
actual replacement: exact maps, mip chains, tint, physical UV scale, roughness,
normal response and pigment recipe. All 25 corner sightlines are checked even
when the capture selector saves only two pairs.

No asset import or new texture generation is needed. Native source/hash checks
and syntax preflight pass. Test results and the final candidate comparison are
recorded in the packet. The single windowed run passes **2,247 checks** over
84 partitions and 14,098 triangles, including **1,205 hardware footprint samples**
and all 25 corner sightlines. Eight comparison images are retained. Installed
metal reflects the original warm carried lamp; the native plates show neutral
illumination. Seven historical Texture-RID shutdown warnings remain, with no
script errors. Reader NEW=0. Inspection records and wrapper receipts are INERT;
no new runtime-contract or completeness-ledger acceptance is claimed.

Fresh static candidate **a172324c** passes 49 comparisons with zero regressions
or timeouts, a clean checkout, 17 protected paths and selector V2. The existing
incomplete ledger is unchanged. Baseline **b6d8c10e** reuses its actual verified
board; intervening **fdc9d443** contains only review metadata/documentation.
See [verification](../art/renders/orison_v2/city_roof_finish_20261008/verification.md)
and [committed byte comparison](../art/renders/orison_v2/city_roof_finish_20261008/committed_binding.json).
Godot was not repeated by the static verifier. Its temporary checkout was removed.

## Closeout

Worktree clean at end: no; pre-existing owner insitu files, two EOL-only edits,
supplied review inputs and unrelated UIDs remain outside this batch. Named owned
paths only. Protected paths and V2 selector remain unchanged by implementation.

Changes outside expected boundary: focused extensions to the existing city
closure validator and one read-only native review script. Open work: broader
city ground interfaces, roof detailing, weather/service capacity and full V2
acceptance. Decision needed from owner: none.

Last line: bounded city roof finish pass; broader V2 remains open.
