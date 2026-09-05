# Separate Unix timestamp audit proposal

Current status: the two proposed tool files are applied as uncommitted changes;
the scanner header was also corrected to describe its world-clock policy. All44
synthetic controls pass on the applied tool. The stable live source comparison in
`live_evidence/before_timestamp_repair_01/` records old scanner exit0 and candidate
exit1 on exactly8 host Unix world stamps. Those production writes remain pending
repair; no baseline bytes changed. The preparation history below remains scoped
to its original isolated runs.

No live tool or production source changed. `unix_audit.patch` proposes only the
systemic audit and its tests. The period audit already imports that scanner and
rejects FIX host-clock findings, so it needs no duplicate detector.

The delta makes unapproved host Unix reads actionable, propagates named same-file
helpers to their durable consumers, keeps the exact existing random-seed entropy
boundary and the two reviewed pure-ID scopes, and refuses a DOCUMENT/REVIEW baseline
entry as suppression of an actionable production finding. This last policy check
is necessary: several existing Unix findings were DOCUMENT at the same identity
and confidence, so changing disposition alone otherwise remained silently covered.
There is no baseline update or new permanent exemption for the legacy stamps.

Actual isolated evidence: `evidence/original.*` runs the four added contract tests
against the unmodified original audit: **4 failures, exit 1**. The proposed audit
passes **44 synthetic tests, exit 0**, including all existing synthetic suites.
The same tests require rejection and never require the known defect. Live-repository
smoke tests are intentionally not included while production provenance is pending.
An earlier attempted full staged run failed because its live-baseline-shape smoke
test correctly could not find a production baseline in this isolated source folder;
it was not a live repository run. No baseline was copied to manufacture a green.

Known pre-migration sources are maintenance inventory acquire/consume, work order
issue/close and job issue/restore, incident report, and night-register history.
Root owns the separate campaign-time provenance repair and metadata migration.
The save proposal preserves unknown compatible `*_at_basis` metadata unchanged.

The source scan remains heuristic, with no cross-file general taint analysis.
The random-seed exception checks the current exact scope and RNG shape and refuses
durable writes; it is not permission to persist raw host timestamps in that helper.
