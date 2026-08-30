# Paranormal pluralism — assessment against the shipped V2 plan

**Status:** work order, not proof — named so the completeness ledger refuses it.
Space identifiers are **bold**, never backticked, so nothing here promotes a
requirement it merely describes.
**Subject:** the owner's proposal that Mina and the Encroachment become one
extraordinary incident among many, in a world supporting multiple kinds of
impossibility that need not share an origin.
**Method:** four grounding passes over the standing corpus and the shipped code,
then three architectural stress tests that walked real call paths for three
incidents chosen to share nothing with the Encroachment. Every number below was
measured at HEAD `1209df3`.

---

## VERDICT

**Stronger, and mostly already true.** Not a new direction — a name for a
position the project has been ruling into existence piece by piece for a month
and has never stated as one thing.

Three findings carry the verdict.

**1. The world model is not Encroachment-shaped, and there is a shipped proof.**
The gravity apartment the proposal offers as a thought experiment **already
runs**. `cam_tilted_room` traverses the complete path — authored data
(`reality_rules.json`), a generic effect layer (`reality_rule_director.gd`), a
per-space owner (`apartment_reality_controller.gd`), player consumption
(`player_controller.gd:1057-1062`), production spawn, and a green test — with
**no dream profile, no encroachment row, no shader grammar, no Mina code and no
save field.**

**2. A generalized anomaly layer already exists.** It is
`reality_rule_director.gd` — **72 lines, zero resident or case name tokens** —
over `reality_rules.json`, keyed by a free String, covering **all eighteen
residents**, carrying **29 distinct rule types** including `gravity`, `topology`,
`memory`, `language`, `broadcast`, `delay`, `recording`, `continuity`,
`contradiction`, `absence` and `history`, with payloads that differ in *shape*:
`cam_tilted_room` carries `gravity_direction [0.72,-0.69,0.0]`;
`peter_form_corridor` carries `loop_depth: 2`. **Do not build a second one.**

**3. The anthology is already authored and has nowhere to live.** Eighteen
heterogeneous incidents ship as data. **Seventeen are `enabled: false`, and
sixteen of their host apartments are ABSENT from v2.** The missing piece is not
machinery. It is rooms.

The proposal costs a ruling and roughly two small seams. It does not cost a
refactor, it does not touch the migration contract, and it does not restart
anything.

**What is genuinely new — and it is only two things.** The axis of plurality
moves from *time* to *mechanism* (one optional field in a file that does not
exist yet). And the claim that **the historical world is deliberately the
control condition, not merely the setting.** That second sentence appears
nowhere in the corpus, and it is the most valuable line in the proposal: it
retroactively gives the obsessive material detail a *mechanical job* instead of
an aesthetic one. Rule it in those words.

---

## WHAT OUR CURRENT PLAN ALREADY SUPPORTS

**The anti-unification thesis was ruled yesterday.** `1209df3`: *"The Orison is
not haunted by other eras. It is zoned by them."* An era entity is *"a
jurisdiction"* with *"no body, no face, no proper noun a resident says aloud,
and no intention toward the player,"* and *"It may never be the explanation."*
That is the proposal's pluralism, one day old, and it is **strictly stronger** —
it carries two locks the proposal leaves open (see below).

**Eight of the proposal's nine anomaly kinds already have a shipped licence or a
shipped instance.** Hyperdimensional organism (§III.1). Purely temporal
(§VIII.5.g, §VIII.5.h). Language (Mina's captions; the house-English strategy).
Radio (WORS 1610, broadcasting 1962–1999 with the transmitter never found).
Architectural (§IX; the bodega back room into **B1**). Identity and memory (Mae
Kessler, *"certainty is not memory"*). Impossible machine (three colour cabinets
with no maker's date; the phonautograph). No visible entity (the three-a.m.
chirp from a listener with no battery). Only *"one resembling a haunting"* is
capped by ruling.

**The permanent refusal to explain was ruled 2026-08-09, at the owner's own
direction, twice, in the same words.** `ORISON_BIBLE.md:768` of the colour
cabinets: *"Do not explain this anywhere in the game."* `:851` of the sixteen
years: *"Do not explain it anywhere in the game."* Neither is attributed to the
Tenant. The proposal's *"not guaranteed to share an origin"* is shipped canon.

**The composition law for many jurisdictions over one space is ruled:** influence
is **pull, never push** — a space declares what it is subject to, its own owner
composes **winner-plus-trace, never a blend**. Two independent non-merging origin
columns already exist on one key, with a combined accessor explicitly forbidden.

**Epistemological progression already ships, in an ethos-legal form.**
`sanity_director.gd:74` holds `sanity_addresses_witnessed`, a durable count of
impossible things the player has been shown, consumed at `:288-291` as a
behavioural bias — *"A player who has already been addressed four times meets a
building that starts from somewhere worse"* — and never rendered. The file's own
header: *"There is no sanity meter, and there is never going to be one."*

**The declaration schema the proposal needs is already ordered.** Arbitration
rule 10, `a53f0a4`: *"Impossibility must be declared or it is a bug."* Every
intended overlap or dangling reference must carry a schema field naming its kind
and the ruling that licensed it. `1209df3` reaffirmed and widened it from
geometry to time. **The field does not exist yet.**

**And a timing fact worth acting on.** The preconditions that gated authoring
licensed impossibility — D1 rect disjointness, D2 the silent missing-level build
— **have already landed**, in `568a6c2`, four commits back:
`_validate_room_overlaps()` fails the build on any overlap above 0.0001 m² on a
level, and `_require_level()` refuses a missing level reference before any
geometry is built. *(One grounding pass concluded D1 had not landed because
`grep -rl disjoint` returns only a PNG filename. It searched for a word, not a
capability. The window is open.)*

---

## WHERE THIS CONFLICTS WITH V2

Six conflicts. Two are blocking, and both have a free resolution already sitting
in the corpus.

**BLOCKING — "one resembling a haunting" implies a second intelligence.**
`ORISON_BIBLE.md` §III.1, ruled 2026-08-11 at the owner's direction: *"There is
one of it, and it is the building"*; *"A shape of its own would make it a
monster, and a monster can be beaten."* **Resolution, free:** the haunting slot
is filled and the fill is load-bearing. A second haunting is either (a) a
**jurisdiction** — footprint, no body, no intention — which the tapestry already
licenses, or (b) the Tenant borrowing an unfamiliar grammar, which the tapestry
explicitly sanctions as the one permitted link. Only a genuinely second
*intelligence* amends §III.1, and **that is an owner decision, not an agent's.**

**BLOCKING — applied to the Dream, this reverses a built system.** §IV.1, owner
ruling 2026-08-24: *"All Dream entities are organelles of one larger
hyperdimensional being."* Sixteen of sixteen phases implemented; the one-mind
reveal is named a central horror beat. **Resolution, free:** scope the proposal
to the **waking lane** in its first paragraph. The tapestry already draws this
boundary and enforces it in data by forbidding the dream lane from reading the
era column at all. The dream is one organism; the waking world is zoned by many.
Both stand, unchanged.

**STRUCTURAL — "entities may recognize one another."** Synchronicity is ruled *"a
query, not an event"*, a memoryless reader scored by surprisal, and *"the engine
may never motivate a change to the data it reads"* — one authored instance
destroys it retroactively and everywhere. **Resolution:** split the clause. Echo
and symbol recurrence: adopt as-is, they are the reader's output. Mutual
recognition: re-express as **co-presence** — two jurisdictions declare footprints
over one space, the space's owner composes winner-plus-trace. The player reads
that as recognition; nothing is authored; §III.1 is untouched.

**STRUCTURAL — the precognitive half of THE BROADCAST.** The chassis, the
station, the out-of-era programme and undated arrival are **all licensed and all
shipped**. Foreknowledge is not, and the two nearest rulings refuse it by name:
*"comedy comes from the house behaving as though it heard what the player
wanted, not from rigging the machine into prophecy"*, and Mina *"is neither
omniscient nor prophetic in play."* **Resolution:** the station does not describe
events before they occur — it **reports facts already committed in the
simulation that this player has not yet observed**. A porter's round already
scheduled, a fault already latent, a resident already en route. Nothing is
predicted; something is disclosed early. `ScheduleDirector.resolve()` is a *pure
function* that can be called with a future minute — the oracle exists, and it
requires no foreknowledge.
**Do not refuse the whole object.** That would repeat `a53f0a4` exactly:
refusing a thing three shipped licences already permit.

**STRUCTURAL — epistemological progression is one careless commit from the
project's third dead global meter.** Ethos §7, the tapestry's *"No aggregate at
any scope… the moment a total exists someone renders it"*, and the style
ruling's rejection of a durable per-cell corruption scalar all forbid it. And the
gate cannot catch it: `JUDGMENT_RE` at
`audit_systemic_situation_authority.py:271-274` matches **six literal tokens**. A
durable float named `epistemic_level`, `skepticism`, `things_seen` or
`worldview` would **pass every gate this project owns** — exactly as
`building_stability` and `reality_coherence` have for thirty days.
**Resolution:** two parts, and the second is not optional. (i) Relocate the
certainty: what accumulates is confidence that *the first explanation is
insufficient*, never confidence about what the second explanation is — which is
what §I's "both true" produces at volume, needing no confirmation event.
(ii) If any new durable fact is needed, copy `sanity_addresses_witnessed`'s
shape, **and land the generic authority-audit rule the tapestry already ordered
in the same commit.**

**COSMETIC — nine kinds exceeds the register's stated cap of eight.** Not a
conflict; the same document lists it as open owner **Decision 4**. Route the
proposal as the answer. Note that the cap's purpose — that the licence keeps
meaning something — is enforced by the *pairing rule*, not by the integer.

**APPARENT ONLY — a generalized anomaly layer.** Already refused twice
(*"we refuse… its second world system, its second ecology"*; *"WorldState as a
peer of RealityState"*; §V *"One authority per question"*). The owner refuses it
himself. And the word is taken: **122 usages** of `anomal` across
`game/scripts/*.gd` already mean *a case-indexed Encroachment haunting*. Keep
the tapestry's vocabulary — jurisdiction, entity, incident — and leave `anomaly`
meaning what it means.

**One scoping sentence is owed.** §VI.5, ruled 2026-08-02: *"everyone is
connected to everyone else — there is no such thing as coincidence in this
building."* It governs the **human relationship web**, which is deliberately and
totally authored. It does not govern the world's impossibilities, which are
independently owned and merely queried. Unscoped, this is the line a future
reviewer will quote to justify collapsing every anomaly into one cause.

---

## MINA / ENCROACHMENT BOUNDARY

The separation the proposal asks for **already exists**, and it is far cleaner
than the folder names suggest.

**Encroachment-specific — eight files and two const tables, not seventy-four.**
Of 74 GDScript files across `dream/`, `cases/` and `reality/`, only **eight
(10.8%)** carry resident or case identity in executable code:
`apartment_encroachment.gd` (the six-row `CASES` table),
`poltergeist_library.gd` (18 poltergeists), `organism_incidents.gd` (voices by
resident id), `dream_incarnation_profile.gd` (the ruled six),
`dream_orison_furnisher.gd`, `mina_case_gameplay.gd`,
`mina_caption_manifestation.gd`, and one hardcoded string in
`domestic_witness_system.gd:208`. Three more matched only on `iris` as eye
anatomy; eight more carry the token only inside a comment.

Keep as unmistakably hers: purple volumetric flesh, living gold anatomy, the
characteristic eyes, crystalline biomechanical growth, the tentacle vocabulary,
the six corruption grammars, and the caption escalation.

**Universal infrastructure — already generic, already identity-free.** The
entity/margin/critter/field substrate: **30 files, zero identity tokens**.
`reality_rule_director.gd` (72 lines, zero tokens). `NpcObservationLedger` — the
sole knowledge authority, beliefs earned through evidence routes.
`OpenShiftSituation` — a durable, anomaly-agnostic observation record with
fifteen required facts. `apply_waking_residue()` — an identity-free
`id → facts` store. `AcousticGraphData.propagate_reality()`. `AudioPolicy`,
`BroadcastDirector` (348 lines, zero case tokens), `Intrusions.perform()` (19
act kinds by string), `WallArtLaw`, `FoundArtPass`, `ScheduleDirector`,
`WorkOrders` evidence flags, `SanityDirector` (460 lines, zero resident names),
`PorterActor.advance_to()`.

**The one boundary that needs correcting in the record.** Corruption is indexed
by resident *unit*, and the operative limit is **not the grammar table**. A
seventh grammar costs about **fifteen lines** — widen
`uniform int grammar : hint_range(0, 5)`, add one `else if` arm, add one const
row. The real limit is the **selector**: `_unit_rooms()` matches
`room.get("unit") == unit`, and **43 of 127 rooms carry no `unit` key at all** —
five corridors, seven atria, seven halls, seven utility, seven storage, plus the
lobby, boiler, laundry, electrical, coal, office, bathroom, roof and common
rooms. Only **22 of 127 rooms (17.3%)** are addressable at any price.

So the earlier framing needs refining in two directions. Inside a case flat,
**every** layered-surface prop is already reachable — `reach_props()` gives each
its own material copy — so "there is no way to corrupt a radiator" is true only
of radiators *outside* a case flat. And no corridor, stair, lobby, street or
shopfront anomaly can ever come through the encroachment pass, at any price,
because those rooms have no unit. **They must be built on a different owner —
and three such owners already ship.**

---

## NARRATIVE EPISODICITY VS TECHNICAL EPISODICITY

**You need the former. You already have it, and it has a name.** §I.1 THE SHIFT:
*"The player's campaign repeats one night-shift movement"* — fault, diagnosis,
errand, repair, conversation, sleep attack, wake in **4B**, repeat. §IV.1:
*"A case is not what makes a resident real. A case is what makes a resident a
chapter."* The corpus's own word for a narrative episode, already decoupled from
world continuity.

**You do not need the latter, and you could not impose it if you wanted to.**
`reality_case_manager.gd` has **no `_process`, no timer, and drives nothing** —
there is exactly one bespoke case owner in the tree. A second incident needs an
owner node and a caller; it does not need permission from a director, **because
there is no director.** Meanwhile the simulation bucket ruling settles the other
half: four tiers with lossless deterministic transitions, *"simulate everything,
render almost nothing"* — so nothing is ever "off".

Narrative episodicity in this repository is already **a row in a JSON file**.
The reconciliation needs one paragraph joining two existing rulings, not a new
architecture.

---

## CHEAPEST ARCHITECTURAL TEST

Three incidents, chosen to share nothing with the Encroachment, walked through
real call paths.

**THE GRAVITY APARTMENT — `CHEAP_AFTER_ONE_SEAM`, 2–4 days.** And it is not a
thought experiment: `cam_tilted_room` **ships**. The full path is authored data
→ `local_gravity()` → `gravity_at()` → `_reality_gravity()` → `up_direction`, and
grep for any of the six resident names across those four files returns **zero in
executable code**. `_reality_gravity()` is already N-zone capable. `safety_net.gd`
already names *"room-local gravity points sideways"* as a supported way the
building lies.
*The one seam:* `local_gravity()` returns **one** vector per case and
`gravity_at(point)` ignores `point` past containment. "Multiple conflicting
directions" is the first authored anomaly needing sub-room resolution — about
60–90 lines. *Out of scope for v1:* wall-walking. `player_controller.gd:1003-1004`
**assigns** `velocity.x` and `velocity.z` in world axes every frame, so
horizontal gravity is erased next tick.

**THE UNRECORDED TENANT — `CHEAP_AFTER_ONE_SEAM`, ~400–550 lines.** Deliberately
the furthest thing from Mina: no shader, no dream, no acts, no visible entity. It
lands almost entirely on systems carrying **no case identity at all** —
`NpcObservationLedger`, `OpenShiftSituation`, `apply_waking_residue`,
`CaseDialoguePanel.run_tree`, `FoundArtPass`, `WallArtLaw`, `ScheduleDirector`,
the acoustic graph, `WorkOrders` evidence flags. **Not one of them needed
widening.**

> **And it found the single real coupling in the entire assessment, and it is the
> calendar.** The incident's defining cadence is *"every night another possession
> appears."* The building's only durable night counter is
> `RealityState.data.dreams_had`, and it has **exactly one writer**:
> `dream_director.gd:125`, inside `enter_armed_dream()`, reachable only when both
> a case id and a `profile_id` are non-empty — and `dream_profiles.json` holds
> **exactly six profiles, all Encroachment cases**.
> **Any incident that reads `dreams_had` gets its calendar from the Encroachment.
> Nights only pass when the player dreams a Mina, Peter, Juno, Mae, Cal or Omar
> case.** That is the one place the proposal is genuinely forced through
> Mina-specific code, and it is not where anyone would have looked.

**THE BROADCAST — `BLOCKED`, and it was the most useful of the three.** Blocked
in *fiction*, not in code. The code proof is four links long and clean: the
acoustic graph takes a **bare String** id; `PoltergeistLibrary.propagation()`
returns `{}` for an unknown one; `:92-93` falls back to the full reachable plan;
and `functional_prop.gd:158` **underscore-prefixes the case id and never reads
it.** *The building's whole nervous system will carry a phenomenon it has never
heard of, today, with no edit.* What blocks it is the precognition, on three
standing rulings — with the substitution above.

**What the three tests prove together.** Two of three are cheap after one small
seam; the third is a fiction question with a shipped answer. Neither cheap one is
forced through Encroachment code anywhere except the calendar. **The Encroachment
is not the world model — it is one consumer of it.**

---

## MINIMUM CHANGES RECOMMENDED NOW

Six. Two are code; four are a ruling. Nothing here is a refactor.

1. **Rule the position, in the proposal's own words**, as an extension of the
   tapestry's pluralism from era-jurisdictions to incident-kinds — and rule the
   control-condition sentence explicitly, because it is the genuinely new idea.
   Scope it to the waking lane in the first paragraph.
2. **Break the calendar out of the Encroachment.** Give the campaign a night
   boundary that does not require a dream profile — ~60–90 lines, modelled on
   `porter_actor.gd`'s `_store()` / `advance_to()` pair. This is the only true
   coupling the stress tests found, it blocks every non-Encroachment incident
   with a nightly cadence, and `campaign_clock.gd` is already owed by a prior
   ruling.
3. **Add the declaration field triple** — `{kind, licensed_by, declared}` — to
   space, door and opening records. This **discharges arbitration rule 10**
   rather than amending anything, and the spatial manifest is indexed by
   identifier, not by schema: a per-space field costs **zero manifest churn**
   (measured — adding an object to all 50 space records changed the universe by
   0 tokens). Land it **before M11 and M12**, which author 75 of the outstanding
   items.
4. **Author the register with `kind` required and `era` optional.** The tapestry's
   own table already carries three non-temporal rows, so moving the axis from
   time to mechanism costs one field in a file that does not exist yet.
5. **Land the generic authority-audit rule** the tapestry already ordered — a
   *structural* check (no persisted numeric field whose only writes are
   monotonic; none with zero readers), not a vocabulary regex — in the same
   commit as any new durable progression fact. Without it this proposal ships
   the project's third dead global meter.
6. **Write the two scoping sentences**: §VI.5 governs the cast, not the world;
   and the two locks — an entity may never be the explanation, and every tell
   must also appear in its host system's ordinary fault vocabulary — are what
   make plurality legal against §I.

**Two items go to the owner by name, not to an agent:** whether a second haunting
*intelligence* may exist (this amends §III.1, ruled at his direction), and open
**Decision 4**, the eight-entity cap, which the proposal's nine kinds answer.

---

## CHANGES NOT WORTH MAKING

- **A generalized anomaly layer, director or framework.** One exists; two more
  were refused; the owner refuses it himself.
- **Renaming `anomaly`.** 122 shipped usages already mean something specific.
- **A per-space or per-cell anomaly scalar.** Forbidden three times over, and the
  repo already shipped the mistake twice with zero readers.
- **Extracting the Encroachment's shader vocabulary into data *for this
  proposal's sake*.** Element-indexed lineage is worth building — it was adopted
  on 2026-08-29 — but the stress tests show it is **not** what unblocks
  pluralism. A seventh grammar is ~15 lines, and corridors are unreachable for a
  different reason entirely (the `unit` selector).
- **Any deliverable expressed as a spatial rect.** The ruled world axis is not
  yet true in the data — v2's apron sits at z −15.0…−11.65 against v1's street
  bands at z 9.45…28.316 — so a rect would inherit the disagreement. Express
  every footprint as an attachment to **named spaces and networks** instead.
- **Wall-walking.** Out of scope for v1 on a hard engine constraint.
- **Restarting, renaming or reorganising anything in v2.** The migration contract
  is BINDING and forbids the replacement becoming a new owner of jobs, cases,
  saves, evidence, semantic audio or interaction behaviour. Everything above
  respects it: new incidents land as **separate data authorities consumed through
  named anchors**, never as v2 gaining an authority.

---

## LONG-TERM OPPORTUNITY

If this holds, the thing the project has been paying for stops being a cost.

Eighteen incidents are authored across 29 rule types. Sixteen of their host
apartments are unbuilt — which means the rebuild is not just replacing geometry,
it is **installing the rooms the existing anthology has been waiting for**. The
obsessive material detail stops being an aesthetic indulgence and becomes the
control condition against which each violation reads. The same corridor can be
temporally unstable in one incident, impossible in length in another, and
perfectly normal except that nobody remembers one door in a third — and the
authoring cost of the third is a JSON row, because the corridor is already built,
already lit, already in the acoustic graph and already in someone's timetable.

The measured risk to that promise is not the anomaly machinery. It is that **the
control condition is thinner than it looks**: `shop_inventory.json` holds exactly
one purchasable object in the entire game; the eight-cell notice atlas has no
text in it, so the character whose entire characterisation is correcting the
lobby notices has nothing to correct; and 415 outfit values, 25 co-presence
pairings and 9 route polylines ship with zero readers. **The highest-leverage
work this proposal motivates is not anomaly machinery at all — it is wiring the
three dead schedule fields and putting rows on a counter.** No geometry, no
schema change, no ruling required.

---

## V2 PLAN INTEGRATION

The plan does not change. Six insertions.

| Where | Insertion |
| --- | --- |
| **Before M11** | The declaration field triple on space/door/opening records (change 3). Zero manifest churn now; expensive after M11 and M12 author 75 records. |
| **M10 lane, alongside the golden shift** | The campaign night boundary (change 2). It is already owed, and it unblocks every non-Encroachment incident with a nightly cadence. |
| **M11 / M12 authoring** | Nothing new. The sixteen ABSENT apartments already have authored incidents waiting; build the rooms, then switch rows on one at a time. |
| **Ethos lane** | The generic authority-audit rule (change 5), landed with any new durable fact — not after. |
| **Ruling lane, no code** | The position itself, the waking-lane scope, the two locks, and the §VI.5 scoping sentence (changes 1, 4, 6). |
| **Deliberately unscheduled** | Element-indexed corruption lineage. Worth building, already adopted, **not** on this proposal's critical path. |

**Sequencing.** Rule now; author as the rooms land. The ruling is free and blocks
nothing. The authoring preconditions cleared four commits ago. And the honest
order is rooms first: the anthology is written, and it is waiting on **M11** and
**M12**, not on a framework.
