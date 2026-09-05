# Risk register

| Risk | Severity | Evidence / implication | Decisive control |
| --- | --- | --- | --- |
| Branch evidence mistaken for production | BLOCKER | M11A isolated, C1 rehearsal, C2 dirty | Exact adoption matrix and consumer-bound receipts |
| F01 consumer cut alters v1 before world cutover | BLOCKER | C2 dirty default OWNER_FIRST_CELLS despite root v1 | Separate provider parity/rollback and full source lineage |
| Host date enters campaign | RELEASE_CRITICAL | CampaignClock reads host date at creation | Independent authored campaign date, time-of-day-only host input, deterministic reconstruction |
| Incoherent NPC presence | RELEASE_CRITICAL | v1 assume-home; V2 wrapped time passed as elapsed | Existing ledger authority + correct clock/presence injection |
| Direct save writes and missing directory | BLOCKER | No atomic readback; fresh-profile M08F red | I/O/corruption fixtures and actual save owner transaction |
| Green exit hides diagnostics | BLOCKER | Import Unicode messages and historical ObjectDB residue | Raw stderr retained; attribute against untouched minimal control |
| Reused generated assets lack closed provenance | BLOCKER | Missing S2H/voxel resources | Deterministic source/hash/consumer closure before salvage |
| False-positive data audit deletes authoring inputs | MAJOR | Character/material manifests have build readers | Explicit build/runtime provenance; family triage |
| Sparse V2 performance masquerades as full game | BLOCKER | Different content scopes | Content-equivalent profiling and S0-S3 budgets |
| Scope-expanded acceptance | RELEASE_CRITICAL | Visual receipt can be misread as mechanics/release | Exact perceptual question, reviewed commit and composition |
| Unfinished cast/campaign concealed by records | RELEASE_CRITICAL | 18 records; six actual campaign mandates | Mina + case-less embodied proof, Peter reuse, then sequential cases |
| Release claims outrun human evidence | BLOCKER | Controller, listening, lived-experience, accessibility and two-machine gates pending | Prepare concrete candidate; owner/people perform their distinct gates |
