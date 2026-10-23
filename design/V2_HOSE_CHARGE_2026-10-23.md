# Flat hose, separate charging and spray — 2026-10-23

Evidence class: **INERT**. Uninstalled candidate diagnostic, not acceptance.

The owner's live-water direction extends V2 operation. It does not rewrite the
retained V1 dry-inspection apparatus or make charging an inspection certificate.
The existing cabinet/lever/joint facts remain authoritative.

Native ring bones now flatten radially when empty, retaining a longitudinal
scale of one and short round transitions at the brass couplings. Charging
rounds the same skin. The source mesh, native UVs and custom linen PBR remain;
no glTF was edited. A 2.5-second fill / 4-second drain response is gameplay
tuning, not a hydraulic-standard claim. Stable empty or charged cloth runs no
fluid/cloth CPU callbacks.

The deployed candidate permits two supply-wheel turns and retains its setting
after release. The original 25 mrad play remains a closed-seat deadband.
Stored/dry cabinets keep their restricted play and return. Existing gasket,
inlet coupling and nozzle connection facts gate charging. The closed nozzle
holds a charge without spray; the separate nozzle lever emits water. Closing
the supply with the lever open drains the hose and returns it to flat.

Spray uses384 rounded GPU droplets aligned to velocity and the registered
clear-water UV/PBR maps with loaded mipmaps. The emitter follows the original
nozzle presentation, keeping the rigid body's shape-only child contract intact.
No extra target scan or environment sweep is added. Nozzle inspection can
borrow the current eye instead of returning a distant held nozzle to the case.

## Issue log and verification

Packet: **art/reviews/v2_hose_carry_20261023/**. Every run uses the repository's
shared serial wrapper, windowed, with original logs and suite-run receipts.

| Location / reproduction | Severity | Evidence | Repair | Verification |
|---|---|---|---|---|
| Empty deployed hose | Appearance / idle cost | Round stock mismatched empty linen | Radial flattening with static idle state | **water_v9** verifies flat/round scales and section renders; flat/round captures visually reviewed |
| Supply wheel after release | High interaction | **water_v2** pressure falls to approximately .936 as the old dry spindle returns | Disable return only for live deployed hose | Final actual input charges fully with nozzle shut, no spray and no stable CPU tick |
| Closed controls | Flow correctness | **water_v3–v5** expose tiny endpoint residues and trickle | Submit exact final bounded angle; use the existing nozzle-shut fact and supply-seat play | Final actual valve closure drains to exact zero and stops emission |
| Spray appearance | Appearance | **water_v6** rectangular billboard particles | Rounded, velocity-aligned droplets | **water_v8** spray visually reviewed; **water_v9** repeats the effect |
| Water finish | Surface correctness | **water_v7** rejects inherited triplanar mode | Explicit UV mode and active normal map | Final programme checks all three loaded PBR mip chains |
| Missing gasket | Mechanical authority | Explicit negative fixture condition | Charging reads existing joint facts | **water_v9** actual supply input produces no fill, pressure or spray |

**water_v9.log.receipt.json** records completed PASS, zero assertions failed,
empty stderr. It exercises actual supply/lever grab, mouse movement and release,
closed-nozzle charging, independent spray, supply closure, draining, flat rest
and missing-gasket denial. Repaired-line preconditions are explicitly staged
fixture facts, not a maintenance-assembly acceptance claim. Charging/spraying
do not sign the tag or fabricate gasket inspection.

**charge_coupling_regression.log.receipt.json** records completed PASS, empty
stderr: original insertion, thread pickup, partial turns, save and support
checks remain. **flat_payout_v1.log.receipt.json** also records completed PASS,
empty stderr: full actual walking payout, reticle aim/limit and static release
still work with empty flattened skin. Default roundness preserves earlier
physical diagnostic modes; production should use cheap visual following.
All original failures are retained. These are **suite_run**, not schema-2
**runtime_contract** receipts, ledger proof or human acceptance.

Focused audits retain reader33 NEW, spatial8 failing /11 reported and systemic25
review, with no new record identities against the preceding controls packet.
Raw outputs are **charge_reader.txt**, **charge_spatial.json** and
**charge_systemic.json**. The earlier full board remains101 PASS /8 FAIL /
1 INCOMPLETE and was not repeated for this candidate. No green-board claim.

## Required before production installation

This candidate is **not installed in the ordinary playable world**. Connect
deployment, supply angle, fixed source, receiver, resting pose and trapped charge
to the cabinet's existing household snapshot/validation/restore authority.
Validate nozzle state against its saved receiver without mutating state during
validation. Preserve old eight-field cabinet and five/six-field nozzle records.
The charge helper's snapshot methods are not household integration.

Publish the existing native asset/rig through its Blender owner, wire ordinary
extraction/nozzle targeting, then exercise world operation and reconstruction.
Measure first spray/shader compilation, steady spray, movement, turning and
transitions at unchanged settings. The earlier occupied-world p95 143.918 ms
remains unrepaired; this fixture supplies no fair world timing comparison.
Continue gasket handoff/dressing, mirror/avatar, street and existing V2 repairs.
