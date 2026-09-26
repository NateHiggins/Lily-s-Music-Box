# V2 boiler flue and durable water-column service

Evidence class: **INERT**

REPORT - V2-BOILER-FLUE - 2026-09-26

Branch / base / origin/main at start / merge-base: main /
771cdfc7d6b0a98f0a3065aa9611105bfd757fd5 (all three references).
Implementation HEAD is the commit introducing this report.

## Implemented scope

The installed boiler's smoke collar now connects to the existing flue shaft.
Three solid cylindrical sections rise at the plant, turn above the maintenance
aisle and enter the shaft's west face. The horizontal underside is 2.48 metres
above the basement floor. Slip-joint bands and rounded elbows describe the
assembly under the service lamp. The obsolete disconnected breeching mass is
hidden and its collision disabled; the semantic identity remains available.

The same authored shaft footprint now has a 2.1-metre masonry roof termination
with an open mouth and coping. Its four walls have matching solid collision.
The existing shaft envelope below the roof remains unchanged. This work does
not cut an open gas passage through every storey or implement smoke transport.
The actual boiler continues to own heat, draft and maintenance activity.

Completed water-column proving now survives Continue and building reconstruction
through the existing household save owner. It adds one boolean service result,
bringing the roster to 185 records, without storing live water level, fuel,
pressure, animations or unfinished preview values. Existing 184-record saves
retain their prior controls and repairs; the omitted boiler result defaults to
unproved. Loading while a service panel is open cancels that preview before
restoring the loaded result.

## Validation

The boiler route checks the actual collar connection, each pipe's physical
collision, horizontal headroom, all existing controls and the return through
the fire door. The roof route adds a walk around the east bulkhead to the
chimney, checks the open mouth and solid masonry, and returns to the primary
stair. Windowed captures expose both ends. The household suite completes the
production maintenance activity, exercises real disk save/reconstruction,
checks both old rosters, rejects malformed service values and cancels a live
boiler preview on load. Cancellation compares the plant with its state at
service entry, since its water level changes during ordinary running.
The approved serial lane records
logs and adjacent suite-run receipts under tmp/v2-flue; clean candidate
verification repeats double import, routes and relevant launch checks.
This is scoped engineering evidence, not runtime-contract or human acceptance.

Four reviewed spatial inventory records are appended; existing records and
classifications are unchanged. Reader audit reports zero new unread fields.
All seventeen protected paths, V2 default and V1 rollback remain unchanged.
Ledger before/after remains 7/8/127/42/151/153; this inert report promotes none.

## Remaining scope

Fuel delivery, flue gas and ash disposal are not newly simulated. The
structural shaft remains an enclosed envelope. Existing H23 debt and broader
unfinished building/campaign work remain separate. The owner's render notes
and three captures stay outside this commit. No new worktree, reference image
or material key is introduced. No owner decision is required for this slice.
