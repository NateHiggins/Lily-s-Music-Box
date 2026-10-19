# Full-length hose: native shell contact

Evidence class: **INERT**. Candidate contact and input diagnostic; no installed
world, full deployment or runtime-contract acceptance.

**game/scripts/props/native_hose_world_contact.gd** extracts the actual skin's
644 ring sections from its imported vertices, bone bindings and weights. Each
section retains 32 outer and 32 inner points. Unsupported weights, missing
sections or a collapsed annulus fail binding. This avoids approximating the
wide flattened cloth with a thin centreline or filling its bore with a solid
capsule. The renderer and contact owner share **native_hose_rig.gd**'s model
frame calculation.

Broad-phase bounds select potentially obstructed sections. Narrow queries use
conservative convex cells between adjacent inner/outer section vertices at the
old and proposed poses. This covers linear vertex travel between those poses.
It is not exact continuous rigid rotation, self-contact, or penetration
recovery. Conservative cells may reject safe motion near complex contacts;
real rack/cabinet qualification is still required. Queries use physical bodies
on layer 1, explicit owner exclusions, a 1-micrometre shape margin and no
increase to the existing length or bearing tolerances.

The candidate's actual grab now supplies this contact owner to its length
constraint. A blocked proposal leaves every centreline point, skin pose and
saved record unchanged. These components still own no maintenance facts.

## Focused checks

The packet is **art/reviews/v2_fire_hose_world_contact_20261019**. It preserves
all three original windowed runs, source snapshots and frames. The initial
programme passed; later programmes add flattened-profile, atomic veto and
fresh transformed-binding checks. They do not replace the earlier originals.
Post-run source snapshots are explicitly labelled.

**stage24_contact3** completed in 11.79 seconds with zero failed checks,
zero script errors and empty stderr. Real physics probes verify:

- A 4 mm-radius probe fits inside the round hose bore and intersects its
  canvas wall when moved outward.
- A 0.5 mm-radius probe fits inside the narrow flattened bore. The actual
  31 mm-wide cloth edge blocks it where a thin centreline proxy would miss.
- An obstacle clear at both endpoint poses blocks the swept shell between
  them. Removing the same obstacle clears that sweep.
- Contact and bore clearance survive world translation and 180-degree
  rotation. Fresh skin/contact binding passes at heights -3.2, 9.6 and
  19.2 m in both 180-degree orientations.
- A valid length-constrained proposal is vetoed by real world contact without
  changing the rig's complete saved pose.

The same run exercises actual cursor selection, primary-click grabbing, mouse
motion and second-click release with the contact owner active. All 644 bones,
the fixed upper port, segment and total lengths, malformed-save controls and
JSON roundtrip checks remain. Loaded rest-pose UV/tangent/PBR mip checks and
the reduced carried voxel light also pass. The moved render was inspected.
The measured small gesture was about 0.9 ms; this is not a complete deployment
performance result. Initial profile extraction was about 125 ms in the first
run. Reader baseline reports zero new fields.

The wrapper receipts are **suite_run**, not test-written runtime contracts.
No complete route, disk/rebuild, moving-surface or eight-station acceptance
is granted by these diagnostics. Prior composed Texture RID warnings remain
open despite this isolated fixture's clean teardown.

## Remaining physical work

The candidate is still referenced only by its bench. Gravity, self-contact,
rack support/release, actual refolding, attached nozzle motion and household
save integration remain unfinished. The current native straight legs have
long intervals between rings; arbitrary new folds need additional bending
resolution rather than a hidden change to the legacy refolding boolean.
Complete that geometry and the physical owner before installing the family.
Human appearance acceptance and the broader V2 build remain **OPEN**.
