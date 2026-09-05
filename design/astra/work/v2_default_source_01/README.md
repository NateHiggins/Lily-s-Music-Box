# V2 default preparation — source checkpoint

Owner instruction: continue everything possible without launching Godot toward
making V2 the default. No Godot process was launched for this work.

Base: `409bcac716ede34da837879296fd961472a8a913`.

## Integrated source changes

- The connected V2 root now owns a world environment, celestial key and production
  sky material. Its DayNightDirector reads the existing campaign clock and calendar.
  The sky shader text is extracted exactly from the preserved V1 implementation;
  `sky_extraction.json` records provenance. V1's root remains unchanged. This is
  source reuse, not a new visual or performance acceptance.
- A root-owned shop simulation consumes ScheduleDirector visit facts and elapsed
  campaign minutes. It advances all included buckets atomically, refreshes stock
  presentation, and preserves the saved interval cursor across reconstruction.
  Catch-up is bounded to one day per shop per poll. It neither writes campaign time
  nor invents restocks, purchases, resident visits or maintenance items.
- Seven reviewed source bindings were appended to the spatial dependency inventory.
  Existing records and classifications are unchanged. Three optional, uncommitted
  F01-provider dependencies remain outside that inventory until that source work
  is checkpointed. Those remaining failures are not suppressed.
- Prepared native tests cover exact visit counts, no consumption from elapsed time
  alone, repeated intervals, atomic refusal, bounded catch-up and reconstruction.
  The composed-world fixture additionally checks one environment, a resolved
  day/night profile and an active shop simulation. These fixtures are unrun.

## Source checks performed

`check_source.py` verifies six GDScript files with gdtoolkit 4.5, literal resource
paths, exact shader extraction, seven additive inventory records, and unchanged
selector, V1 root, both metric layouts, fourteen floor exports and clock authority.
The parser is not Godot's compiler; it cannot prove type checking or shader execution.

All seven existing Python audit families and their self-tests were run into fresh
`evidence/v2_default_source_01` and `_02` directories. Systemic authority,
interaction carriers, interaction implementors and audio checks pass. Completeness
and data-consumption audits remain failing; their self-tests pass. The spatial
audit and its live-repository self-test remain failing on the three optional F01
provider references. No old evidence or broad baseline was rewritten.

The completeness ledger reports 108 cutover blockers. This is a conservative
historical evidence inventory, not 108 newly verified defects or proof that prior
runtime checks apply to these changed bytes. Some circulation labels use inference:
F03 has intermediate core platforms and stairs despite an absent public-landing
program finding. It still lacks its full residential program and vertical proof.

## Remaining route to default

1. Finish the F01 provider cut and connected construction/Passage route with actual
   residency/streaming. Current street and shop geometry remains resident.
2. Author and integrate F03's residential/service program, then prove its vertical
   route. Complete missing F05, F06, roof, remaining apartments and service rooms.
3. Complete resident/gameplay consumers, navigation and acoustic/service graph
   derivation, and saved-state reconstruction under V2.
4. When native execution resumes: import/compile, run both prepared fixtures and
   existing terminal/first-shift/save checks, walk both directions through the
   entrance and bodega, acquire the repair item, and capture actual player views.
   Atmosphere needs day/night readability and GPU/shader verification in the
   composed scene, including fixtures that previously supplied a review environment.
5. Complete integrated route, full-shift, performance and human cutover gates. Then
   apply the prepared selector patch and retain the explicit V1 rollback path.

`default_flip.patch` is a concrete one-line proposal, checked for applicability only.
It is **not applied** and is not evidence that the cutover contract has passed.
Old F01 execution_05/capture_01 source baselines must be renewed before resuming;
all their old seals and failed/overlapped runs remain preserved.
