# V2 authored import binding — 2026-10-20

Evidence class: **INERT**. Source-integrity checkpoint and pending qualification;
no runtime or human acceptance promotion.

REPORT - V2-SURFACE-IMPORT-BINDING - 2026-10-20

Branch / HEAD / origin/main / merge-base: **codex/v2-fire-fitting-checkpoint**;
preceding checkpoint **ee657207**; integration main **82887a14**. Incremental
work only; the canonical main checkout contains inherited uncommitted work.

Problem and change: surface freshness omitted authored import sidecars outside
the selected building, weather and native-mesh sets. The input collector now
includes import parameters for every versioned rendering asset under
**game/assets**, plus explicitly versioned sidecars. Derived, unversioned GLB
extracts stay excluded. Cache destinations and UIDs remain excluded from the
effective parameter hash. A regression changes a teletype normal-map import
parameter and requires qualification to expire.

The private checkout adopts the canonical tree's existing correct settings:
131 character/dream texture imports preserve mipmaps and disable automatic
3D-policy switching; nineteen of those preserve GPU compression. Nine teletype
normal imports preserve their explicit roughness settings. The 131 previously
unversioned sidecars are now authored files so fresh checkouts retain them.
No bitmap, geometry, controller or material key changes in this delta.

Protected 17/17: no protected path changes. Explicit V1 rollback and the V2
selector remain. Ledger before -> after: no promotion requested;
requirements_changed: []. No interaction or save authority changes.

Gates and evidence: canonical and private input snapshots match exactly at
6,066 entries, SHA-256
**9f983edabc11571ef399870c51df5124b4abf4cb543a80a549b0912227eaf2bf**.
Snapshots and the exact 140 metadata deltas accompany this checkpoint under
**art/reviews/v2_surface_import_binding_20261020**. The focused new native-map
freshness and derived-cache exclusion regressions passed before metadata
alignment. The complete 95-gate board has zero new regressions; all 29 surface-requirement
tests pass. Surface qualification remains stale under the corrected hash.
The final loaded qualification is a separate pending check, not claimed here.

The previous **surface6** run completed 40,023 checks with zero failures and
zero technical surface findings. It used the preceding binding. Its original
contract, wrapper, inventory, logs and reviewed frames remain unchanged;
they are not repinned to this corrected hash. A fresh import and combined
windowed surface run must produce the replacement contract. Seven historical
Texture RID leak warnings remain open. Photoreal appearance, continuous
gameplay, current-main integration and whole-V2 human acceptance remain open.

Changes outside the expected file boundary: none. The metadata additions
preserve existing canonical policy rather than accepting fresh-cache defaults.
Decision needed from owner: none.
