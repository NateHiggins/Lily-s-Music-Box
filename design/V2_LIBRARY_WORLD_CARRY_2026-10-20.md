# REPORT - V2 native library world carry - 2026-10-20

Evidence class: **INERT**

Books and ends now move beyond their original shelf workspace. A real grabbed
binding travelled **24.0499 m** under ordinary player movement input on a native
capsule/floor, then settled and reconstructed at its distant pose. The same
library retains stock identity and ownership. Change signals and handling sound
now originate at the moved stock. Human acceptance and whole V2 remain open.

Branch / parent HEAD / origin/main / merge-base:
**codex/v2-fire-fitting-checkpoint** / **e28dfa7d** /
**82887a14d08357a400047624a6ce720351a748e0** / same main commit.
Worktree clean at end: intended yes after the named-path checkpoint, except ignored
local diagnostics. Protected 17/17 unchanged. Selector V2 with explicit V1 rollback.

## Implementation and authority

The shelf's invisible X/Y/Z carrying box is removed. Native convex-piece sweeps,
world contacts, hand reach, visibility validation and the existing player holder
follow constrain movement. No collision exemption, inventory conversion, new
save owner or teleport substitutes for carrying. Save validation no longer rejects
stock simply because its shelf-relative position exceeds twenty metres. Numeric
shape/type, finite native vectors, normalized rotation and velocity/spin guards
remain. Finite JSON values overflowing native Vector3 are explicitly refused.

The library still owns the same physical records and permutation; moving a book
does not change its title, resident identity, canonical-book identity or case
membership. Existing native geometry, custom UV/PBR/mip materials, typography and
all thirty page spreads are unchanged. No Blender export was needed.

A new optional **change_origin** callable lets a grip report its physical location
while preserving its existing semantic owner in the world-modified signal. Native
book/end body, turn and cover grips supply their current location. Descriptors
without that callable retain their original behavior; invalid locations fall back
to the owner. The shelf's existing audio emitter moves to the handled part before
playing. Its owner and single-hand lifecycle remain unchanged.

## Verification and scope limits

Packet: **art/reviews/v2_library_handling_20261020/**.
**controls-compile17.log.receipt.json** compiles all five changed runtime/test
scripts. **bench47.log.receipt.json** records PASS, **766 checks**, zero failures.
Thirteen carry checks plus two event-origin checks extend the previous native
bench. Primary click and mouse/wheel extract a real binding; **Input.action_press**
drives the ordinary controller, capsule, floor contacts and holder follow for
24 metres. There is no noclip, autopilot or per-frame direct pose placement.
Recorded hand-offset error is **0.0001068 m**. The primary release restores gravity,
the body sleeps on the distant floor, and both the world-change signal and the
handling emitter occur at the book's current position rather than the old shelf.

The original library validates the distant snapshot; full-precision JSON round
trip and a newly instantiated native library reconstruct pose, opening, velocity
and sleep state after physics synchronization. This is **native snapshot proof**,
not a new real-building delivery or full-world disk-save route. The diagnostic
floor and extra library are fixtures, not authored world locations. The floor
uses existing custom oak PBR maps with metric UV scaling; the production carried
voxel light is unchanged. Final carried and rebuilt views were rendered and
visually inspected. Earlier **bench45/46** local passes isolate the carry and
capture work; only final **bench47** is the retained current receipt.

Existing native negatives still verify actual shelf/floor and temporary-wall
collisions, actual blocker identity and the same unobstructed goal after removing
the wall. All previous book, bookend, inspection, cover and sash controls pass.
**shared-controls2.log.receipt.json** passes **99** direct-manipulation checks;
**toilet-controls2.log.receipt.json** passes **39** toilet-inspection checks after
the shared release callback change. Four readable-library tools tests pass.
Reader audit: zero NEW unread fields. Spatial audit: clean, no new failures,
new reported records, unresolved saves or vanished targets.

The previous ten-case **installed8** control-only pass and **installed6** individual
two-world reconstruction checks are reused for their unchanged scopes; neither
is a new source-current building-route proof. Wider precise-contact physics and
whole-world surface qualification remain open. Wrapper receipts are **suite_run**,
not schema-2 **runtime_contract** evidence. No space or requirement is admitted.
Portable raw stdout/stderr hashes remain checked by the tools regression and the
Git-index verification; no receipt hash is repinned.

## Disposition

Ledger before -> after: first slice **7 -> 7**, full runtime **42 -> 42**, full
structural **110 -> 110**, golden shift **8 -> 8**, cutover **134 -> 134**,
retirement **136 -> 136**. Requirements changed: none. The previous complete board
remains 96 PASS, two FAIL, one INCOMPLETE; it is not rerun or reported green here.
Stale composed surface qualification, existing completeness assertions and prior
cohort/ledger regressions still prevent integration. Canonical wardrobe/storage
WIP remains preserved in the shared main checkout.

Open work: actual-building carried-object routes and corresponding disk rebuild;
passive book families; texture-RID teardown warning; broader contact qualification;
remaining V2 content, source-bound proof renewal, integration and human acceptance.
Decision needed from owner: none.

BLOCKED broad integration by composed qualification debt and remaining V2 content
