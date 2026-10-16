# V2 watch station transmission and lockout

Evidence class: **INERT**. Implementation report; no room promotion or full
V2 acceptance is granted by this document.

## Result

The station's crank now drives its coded wheel continuously through three
native gears. Partial winding moves the mechanism immediately instead of
leaving the wheel stationary until the record is published. A rotating stop
lug meets a guided lockout bar after the completed stroke. The original
station and network still decide key custody, marking, duplicate refusal
and supervisor reset.

The native stock includes 24-tooth involute gears, bored bearings, shafts,
collars, a crank stop, and a backplate-mounted guide bracket. The gear pair
uses a 20-degree pressure angle with running backlash and small machined
edge breaks. The existing custom machined-brass material replaces the
blotched brass on this station's working fittings; no new catalogue key or
generated lettering was introduced.

A refused supervisor reset now preserves partial winding. Successful reset
returns the crank and gear train home through the original authority.

## Verification

Working evidence is in **tmp/v2-station-transmission-20261016/**. Source is
frozen in **source_freeze_precision.json** for the successful precision-import
verification batch. The earlier six-path snapshot is retained as history.

| Check | Current result | Scope |
| --- | --- | --- |
| Native mesh census | Passed | Nondegenerate authored UVs, closed manifold stocks and positive volumes |
| Exported GLB UV audit | Zero failing surfaces | Decoded exported triangle charts, before Godot import |
| Native motion sweep | 121 positions, zero reported collisions | Adjacent gear teeth and crank stop against case, retracted pawl, guide and bracket |
| Focused installed hand test | 36 checks, zero failures | Actual grab, mouse motion, release, inspection, partial restore, failed-reset preservation and original single-mark lockout |
| First-slice contract | Passed and independently qualified | Opening ritual, seven-station patrol, disk reconstruction and measured teardown |
| Installed night-register save | 26 checks, zero failures; independently qualified | Pointer input, atomic filing and saved state across three production-world constructions |
| Composed surface contract | 26,719 checks, zero failures; independently qualified | 24,584 draws, 16,527 meshes, 5,983 materials, 465 textures; UV, custom PBR and loaded mipmaps |
| Apartment access | Passed and independently qualified, 19 rooms | Collision-bearing routes and actual fixture input; 268 recorded checks plus final receipt-flush check |
| Remaining-apartment access | Passed and independently qualified, 60 rooms | Nine collision-bearing apartment legs; 781 recorded checks plus final receipt-flush check |
| Installed dumbwaiter contract | Passed and independently qualified, 53 checks | Actual mechanism input, save reconstruction, guarded denial and measured teardown |
| Installed roof-tank contract | Passed and independently qualified, 52 checks | Actual mechanism input, save reconstruction, guarded denial and measured teardown |

Native clearance is limited to the named stocks and sampled poses; it does
not prove every mechanism contact or photoreal finish. A decoded comparison against the
published checkpoint finds 20 unchanged parts, one resized pawl, eight added
mechanism parts and none removed. That comparison rounds local triangle
positions to 0.00001 m and does not compare materials or runtime transforms.
The first-slice receipt
contains 132 recorded checks; the suite additionally checks its final receipt
flush. The save receipt does not claim the broader teardown contract.

The first focused run and one repeat reported an opposite projected crank
movement immediately after inspection-cursor warping. The diagnostic recorded
a commanded positive step followed by a net negative step across the frame.
This is consistent with a delayed OS warp becoming an additional gesture;
the OS event itself was not independently traced. The helper now waits for
the actual cursor to settle before grabbing, with a bounded timeout. Three
consecutive repeat runs passed all 35 checks, followed by the final 36-check
run including the reset regression. Actual pointer selection and motion remain
in use; no direct pick or authority substitution was introduced.

The first full surface run found 35 collapsed-UV surfaces: three gears and
two long shafts in each of seven stations. The native charts passed, while
Godot's default compressed import lost precision on the small bevel charts.
The station asset is now included in the existing selective precision policy,
with its authored import sidecar tracked. All 19 surface-policy tools tests
pass. The fresh import and surface run passed, and independent qualification
reported zero defects. Eight new captures were inspected and bound to the
current source and image hashes; the canonical surface packet is renewed.
The failed capture remains diagnostic history. First-slice and save source bindings
are unaffected by this import-policy change.

## Remaining work

The dependent mechanism proofs are renewed. The native
and Godot renders show the fitted transmission, but final station wiring,
coded-wheel contact detailing and whole-world visual acceptance remain open.
The installed register capture still shows repetitive orange wood and sparse
mechanical detailing. Technical checks do not approve those aesthetics.

A separate read-only inventory records the remaining acoustic migration:
the 550-node graph retains V1 topology, with scoped V2 position overrides in
multiple owners. Literal data and historical draw-path matches are candidates
for migration, not proof of current placement or connectivity. The runtime
requirements comparison separates 25 pre-existing gaps from 17 pending proof
renewals. Neither inventory promotes acceptance.

The static legacy graph inventory finds 550 unique nodes and 1,096 directed
connections, with no missing targets. Its 52 cross-network connections and
seven connected components require explicit physical and narrative review;
connectivity alone is not proof of correct V2 routing. A read-only production
owner inventory completed after the verification batch: 192 legacy identities
have unique named owners, 122 have bound functional props, and 128 have scoped
position overrides. The 358 unmatched names are migration candidates, not
proof of absent objects. All 550 graph records were restored exactly after
world teardown. The standalone observer's first attempt failed from an early
autoload dependency; its corrected retry completed without script errors.
This is an INERT inventory, not a runtime acceptance contract. Graph replacement must
invalidate cached propagation plans and prevent delayed deliveries from an old
world reaching a new one; the existing prop lifetime test does not cover that
graph-wide transition.

## Management status

REPORT - V2-STATION-TRANSMISSION - 2026-10-16

Branch / HEAD at validation / origin/main / merge-base: main /
e2ffefd8efb30354c3ad0c3518c43204de9226f8 /
e0b0dd293325a49c207785888112262a4990e474 / same origin/main.
Publication target: **codex/v2-direct-manipulation-checkpoint** only.

Worktree clean at end: no; owned station changes and inherited unrelated
imports, UIDs and review artifacts remain. Stage named owned paths only.
Protected 17/17: unchanged from the preceding checkpoint after LF normalization.
Selector: V2 with explicit V1 rollback.

Ledger before -> after: **0 / 1 / 48 / 25 / 65 / 67** ->
**0 / 1 / 48 / 25 / 65 / 67**; requirements_changed: none. The comparison baseline
is the preceding checkpoint's board, not a fresh merge-base checkout.

Gates: four spatial binding preflights pass; reader NEW 0; UV import gate passes.
Final static comparison: **NO REGRESSIONS**; all 46 tools test suites pass.
All dependent Godot suites are completed and independently qualified. All listed
completed suites have wrapper execution receipts and separately scoped proof.

Changes outside expected station files: the selective mesh-import precision
policy, renewed canonical receipts and this implementation report. Open findings: visual work
above, and the broader unfinished V2 scope. Decision needed from owner: none.

READY for named-path checkpoint publication; broader V2 and human acceptance remain open.
