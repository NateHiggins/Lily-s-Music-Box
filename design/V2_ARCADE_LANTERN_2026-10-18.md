# Arcade lantern roof construction — 2026-10-18

Evidence class: **INERT**. Implementation and diagnostic report. This document
grants no spatial, gameplay, runtime, human or photoreal acceptance.

The overhead block in the arcade is the source-authored stepped lantern roof.
Its three solid cap slabs concealed the original opal top light from below.
The replacement keeps the three footprints, tier heights, original glazing,
corner posts, curbs, mast and pendant clock. Only the three cap boundaries
are retired through the existing source-owned native mounting path, including
on passage cell reconstruction.

The native roof uses 140 closed pieces: 2 mm weather skins, folded perimeter
returns, standing seams, well frames, a cross-tie and a collar meeting the
retained clock stem at its actual endpoint. All three tiers have a real
central well. The original top-light surface remains its own source stock.
The roof is one material draw and 8,400 triangles, with metre UV charts and
the registered custom blackened-iron PBR finish. No new catalogue key or
generated texture is introduced.

Six Blender comparisons are retained in
**art/reviews/v2_arcade_lantern_20261018/native05/**. All pieces are closed and
outward-facing; export tangent checks pass. Four actual mesh rays cross the
well, three check the tier undersides and one checks the hanger bearing. Thirty-six further
mesh rays check the full bearing circles of the four retained corner posts.
Four focused tools tests check clear paths against the original solid-slab
negative control, source preservation, deterministic fitting and refusal of
changed tier/light/hanger geometry. The imported Godot bench passed 378
checks, including the existing arcade checks and actual loaded roof rays.

The first native review had missing appended-context texture paths. It is
not accepted as an appearance review. The builder now resolves registered
texture basenames before rendering and saves explicitly rebased paths in the
editable native file. Its original log is preserved as a diagnostic.

A further actual-mesh audit found a 118 mm gap above all four original posts.
The first world batch was explicitly interrupted and supplies no runtime
grant. The corrected roof has closed perimeter channels seated exactly at
the retained post tops. The native and imported checks now sample each centre
and eight surrounding points, excluding the old posts from the physics query
so their own end caps cannot fake a roof bearing. The rejected mesh queries
and the interrupted run are retained as diagnostics. Blender comparisons hold
the same mapped finish and lighting across the two geometry states.

Composed surface, physical repair/save and played-access qualification are
pending. Existing canonical proofs are historical while their broad source
digests differ. No proof is repinned. The native result remains incremental
detail work; it does not close the arcade's fascia, clock-face, overall
lighting or broader material-finish obligations.

## Management report

    REPORT - V2-ARCADE-LANTERN - 2026-10-18
    Branch / HEAD / origin/main / merge-base: main / pending source commit / f5d617379a3f9148450d5ef5eb36ce86c3c788af / f5d617379a3f9148450d5ef5eb36ce86c3c788af
    Worktree clean at end: no; unrelated inherited shared-checkout changes are excluded.
    Protected 17/17: pending clean comparison. Selector: v2; explicit v1 rollback retained.
    Ledger before -> after: 0/1/48/25/65/67 -> pending composed proof renewal; no new grant requested.
    Gates: reader NEW0; focused source tests and imported bench pass; complete clean static preflight pending.
    Godot receipts: import1, import2 and import3 completed; bench2.log.receipt.json completed PASS 378/0. Bench is INERT, not a runtime grant.
    Numbers: 3 original slabs; 140 closed native stocks; 8400 triangles; 1 draw; 6 native comparison views.
    Changes outside expected boundary: native import precision and surface-source dependency registration cover the new roof stock. Three source references extend the spatial manifest; prior rows remain unchanged.
    Open findings: composed qualification and broad V2 obligations remain; human and photoreal acceptance are unproven.
    Decision needed from owner: none for this authorized geometry/detail work.
    BLOCKED composed qualification and clean candidate comparison pending
