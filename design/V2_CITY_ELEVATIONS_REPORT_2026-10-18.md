# REPORT - V2-CITY-ELEVATIONS - 2026-10-18

Evidence class: **INERT**. Publication report; no additional acceptance grant.

Branch / HEAD / origin/main / merge-base: **main** / verified code candidate
**aae34b06f736a0fbc37f96935b07203ba6d4bd7b** / **3d69a10a0de791e473b5a9eade0cde59fa70e8bc** /
**3d69a10a0de791e473b5a9eade0cde59fa70e8bc**. This publication child changes only
documentation and archives the unmodified verification result. It introduces
no rendering, runtime, helper or asset input changes.

Worktree clean at end: verification checkout yes. Canonical shared checkout no:
inherited import/UID/receipt, enamel/M08F and unrelated capture changes remain;
the separate unfinished service-circulation candidate is also excluded. Named
owned paths alone are staged. The complete local inventory is retained at
**tmp/v2-city-rework-20261018/remaining_shared_status.txt**.

Protected 17/17: yes. Selector: **v2**; explicit V1 rollback preserved.

Ledger before -> after (blockers):

| Gate | Before | After |
|---|---:|---:|
| FIRST_SLICE_TECHNICAL | 0 | 0 |
| GOLDEN_SHIFT_V2 | 1 | 1 |
| FULL_BUILDING_STRUCTURAL | 48 | 37 |
| FULL_BUILDING_RUNTIME | 25 | 25 |
| PRODUCTION_CUTOVER | 65 | 54 |
| V1_RETIREMENT | 67 | 56 |

Requirements changed: **circ.F01.public_landing**, and **circ.F02.public_landing**
through **circ.F06.public_landing**, plus **circ.F02.public_core** through
**circ.F06.public_core** through the existing purpose matcher. These are six
actual landing room claims, not new whole-core, shaft or lift authority claims.

Gates: clean verifier completed with exit 0, zero regressions, 14 improvements,
zero accepted regressions and zero design lint errors. Every individual gate,
tools test result, exit code and diagnostic is preserved in the complete before
and after boards in **art/reviews/v2_city_elevations_20261018/verified/verification.json**;
the readable result is **verification.txt** beside it. Main is not globally green.
The clean comparison used **--no-godot** because the original canonical engine
runs below already bind independently identical runtime and surface inputs.
Fresh-worktree engine import/autocrlf behaviour is outside this comparison.

Original Godot suites, all terminal PASS with wrapper exit 0 and original
test-written contracts, matching logs and wrapper receipts published in their
canonical packets under **art/renders/orison_v2/**. Independent validation and
prior-packet archives are under **art/reviews/v2_city_elevations_20261018/**:

| Run | Actual result |
|---|---|
| surface3 | 37,903 checks, 0 failures; zero unresolved UV/PBR/loaded mipmaps |
| service3 | 360 checks, 0 failures; physical service repair and disk reconstruction |
| home3 | 62 rooms, 9 legs, 909 checks, 0 failures; 10 tracked, 0 retained |
| upper3 | 69 rooms, 11 legs, 989 checks, 0 failures; 13 tracked, 0 retained |
| landing3 | 6 rooms, 1 continuous leg, 748 waypoints, 41 checks, 0 failures; 3 tracked, 0 retained |

Numbers: 25 rebuilt city elevations, 31 former terrace steps reduced to 14,
2,984 recessed windows, 227 native material partitions, 505,287 triangles.
Native checks cover 1,205 roof bearing samples and all 2,984 panes. Runtime
checks include 400 continuity rays, 1,205 roof bearing samples, 80 panes and
three unobstructed window camera sightlines. The composed surface world has
25,809 draws, 16,783 meshes, 6,126 material instances and 497 loaded textures.
Four native views and 14 composed captures were inspected. No new texture
images were needed; existing custom catalogue maps retain authored UV scale,
normals and loaded mip chains. Equal stock/tint material sharing removes 207
instances from the initial city version. Retained roof equipment and protected
layout authorities are unchanged.

Changes outside the city boundary: the preceding six-floor landing integration
is included and independently qualified. Its five changed gate files were
reviewed: actual platform-backed programme validation replaces enclosing-rect
membership, invalid support/shaft claims fail closed, negative legacy fixtures
remain, and only four inspected test references are appended to the spatial
manifest. Existing manifest semantics are unchanged; Unicode escaping is inert.
The native workflow now requires full bearing/pane checks before export. The
import fixer enforces the new asset's validated precision policy. No gate waiver
or proof hash repinning was used. The first failed city diagnostic is preserved.

Open findings: seven standing texture-RID shutdown warnings; bright lamp
hotspots, repetitive wood and simple wall art; distant facade variety, fog and
finite ground/horizon presentation; 37 structural and 25 runtime blockers;
authored eleven-beat playthrough, acoustic rederivation and human acceptance.
Whole V2 and V1 retirement are incomplete. The uncommitted service-circulation
prototype has an unsupported F01 service approach and grants no acceptance.

Decision needed from owner: none for this scoped city publication. Human
appearance acceptance and eventual explicit V1 retirement remain separate.

MERGE-CANDIDATE aae34b06f736a0fbc37f96935b07203ba6d4bd7b
