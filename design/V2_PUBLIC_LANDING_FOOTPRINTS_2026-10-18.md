# Public landing footprint derivation — 2026-10-18

Evidence class: **INERT**. Measured authoring preflight, not runtime, spatial,
human or whole-V2 acceptance. The installed building is unchanged.

The latest completed clearance checkpoint is **95c1c7be**. This next batch
addresses the mismatch between public landing semantics and existing physical
platforms. The canonical platform ownership is the geometric source; neither
the lift shaft nor stair void may be filled to make a room rectangle true.

The read-only **tools/derive_v2_public_landings.py** computes the exact union
and exposed edges of each floor's PUBLIC_LANDING platform rectangles. Shared
internal edges disappear, while external and hole boundaries remain. Capsule
support requires a complete horizontal disc to clear every exposed edge.
Straight route validation checks the entire sweep: two supported endpoints
cannot establish passage across a hole or around a concave corner.

## Current findings

| Floor | Platform union, m² | Legacy landing shell | Unsupported shell area, m² | Existing review stance |
|---|---:|---|---:|---|
| F01 | 30.62 | absent | not applicable | absent |
| F02 | 38.32 | present | 6.125 | supported for production 0.33 m radius |
| F03 | 38.32 | present | 6.125 | absent |
| F04 | 38.32 | present | 6.125 | supported for production 0.33 m radius |
| F05 | 38.32 | absent | not applicable | absent |
| F06 | 38.32 | absent | not applicable | absent |

F05 and F06 already have public core volumes whose purpose mentions the
passenger landing and stair. The ledger currently uses those generic core
records for its landing match. Their volume is not a walkable footprint;
the missing dedicated landing-shell identity does not mean a missing floor.
Retain the air/stair/lift core authority while adding precise floor-bearing
programme semantics.

Each old rectangle includes six square metres of lift void plus 0.125 m² beside
the stair. The corrected diagnosis replaces the earlier rounded six-metre
estimate. There are 29 geometrically supported platform-centre candidates.
These are potential capture/route targets, not collision-tested player stances;
furniture, doors, vertical travel and route connectivity still need actual
production-world checks. Missing review stances are reported, not invented.

Seven independent checks cover overlapping rectangle area, internal-edge removal,
concave/hole rejection, a swept route whose endpoints are safe but crosses a
hole, the actual six-floor census, malformed/foreign-floor platform stock, and explicit production radius binding.
They pass. The authoring diagnostic command is:

    python tools/derive_v2_public_landings.py --out tmp/v2-public-landings-20261018/footprints.json

The diagnostic reads BODY_RADIUS directly from the production controller and
binds both its LF-normalized source and the layout SHA-256. The initial
sample-radius preflight was corrected before publication; no runtime pass is
claimed for the earlier 0.24 m diagnostic. It only permits
output beneath repository tmp and does not rewrite generated layout data.

## Integration still required

Migrate the old shell semantics through an owning projection that preserves
openings, review identities, shaft construction and original platform ownership.
Represent the full union rather than its enclosing rectangle. Bind actual
landing furnishings, floor decisions, accessible exits and acoustic ownership.
Update the consumers that currently assume rectangular containing spaces;
then verify the six floors with production collision, grab/motion/release at
relevant doors, real support contacts and played routes. Renew affected native
source bindings through their builders and combine rendering qualification with
that structural batch. No existing receipt may be repinned.

The clean baseline board for the next source batch is captured from
**95c1c7be**: no dirty paths, current surface qualification passes, reader NEW0,
and the standing completion blockers remain 0 / 1 / 48 / 25 / 65 / 67. Current changes are an authoring diagnostic and its tests only;
no runtime material, geometry, interaction or completion grant has changed.

## Verification and management report

The original clean comparison is archived under
**art/reviews/v2_public_landing_footprints_20261018/**. Candidate **f0eaf7dc**
has zero regressions against **95c1c7be**, with 87 gates including 75 tools
suites. The sole new gate-path file adds the seven independent footprint checks;
no existing test, acceptance threshold or baseline is weakened. All 17 protected
paths are unchanged, V2 remains selected, reader NEW0 and design lint is clean.
The four existing surface/service/access packets still qualify. This is static
in-place verification in the owned clean checkout; no new Godot launch or fresh
engine import was performed or claimed. Subsequent changes only archive these
results and clarify this report, leaving production inputs unchanged.

    REPORT - V2-PUBLIC-LANDING-FOOTPRINTS - 2026-10-18
    Branch / HEAD / origin/main / merge-base: main / f0eaf7dc (verified authoring candidate) / 95c1c7be / 95c1c7be
    Worktree clean at end: canonical no (inherited changes excluded); verification checkout clean.
    Protected 17/17: unchanged. Selector v2; existing explicit v1 rollback preserved.
    Ledger before -> after: unchanged blockers0/1/48/25/65/67; zero requirements promoted.
    Gates:87 including75 tools suites; zero regressions, no waivers, readerNEW0, zero design lint errors.
    Godot receipts: no new run; existing four original runtime packets still qualify with unchanged production inputs. This preflight grants no runtime acceptance.
    Numbers: six platform unions, three inaccurate old review shells, six-area census and29 geometric stance candidates; production radius0.33m; seven testsPASS.
    Changes outside expected boundary: none; only authoring diagnostic, independent tools checks and workflow/report documentation.
    Open findings: actual landing semantic migration, programmes, acoustic owners and played route/support proof remain; fullV2 and human acceptance are incomplete.
    Decision needed from owner: none for the authorized next integration.
    READY for this authoring-preflight checkpoint only. Landing integration is not claimed complete.
