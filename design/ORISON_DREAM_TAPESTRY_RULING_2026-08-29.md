# The dream tapestry — ruling, 2026-08-29

Work order, not proof. Identifiers **bold**, never backticked.

Owner direction, verbatim:

> "I would like the Orison to struggle to maintain its 1928 identity but
> it exists in a dream tapestry of different era entities that overlap in
> influence both geographically and thematic meta conceptual ways a
> variety of times and references to allow for free form creative
> synchronicity to emerge. it is all just a dream after all, here to
> entertain and titillate and ultimately evaporate with the dew."

## The short version

Four of the five claims are already shipped canon under other names, so
most of this is **ratification, not invention**. The genuinely new claim
is the *struggle*, and it is buildable as a derived read over
maintenance facts that already exist — no meter, no new save subtree.
The 1928 cutoff falls as a blanket refusal and is replaced by a licence.
"It is all just a dream" is ruled an **authorial** frame; said inside
the world it is the one resolution the bible forbids.

## The ontology

The Orison is not haunted by other eras. **It is zoned by them.**

An era entity is a *jurisdiction*: a claim on the ground, the air, the
wire, the paper or the meaning of this plot, issued by a different time,
never formally revoked, still in force. It has no body, no face, no
proper noun a resident says aloud, and no intention toward the player.
The Tenant remains the only intelligence in the building — §III.1 says
it must never be given a form, because a monster can be beaten — and the
one sanctioned link is that the Tenant may borrow an era's grammar
exactly as it already borrows a resident's shadow.

The dream is **not** the substrate. §I rules the waking ontology as
purgatory; `dream_boundary.md` holds the dream as a mutually exclusive
world state — the slot holds one root or the other, *never both*, across
a five-phase transaction committed before any swap. The dream is the
**other room** of purgatory, not its floor.

One constraint governs everything below:

> **An era may be present, may be felt, and may have a footprint. It may
> never be the explanation.**

The moment a player can say "ah, the seventies are bleeding through,
that's what the noise is," §I has lost — not because a rule broke, but
because the ordinary reading died and took the horror with it.

And the reconciliation that makes the direction legal against the paper
trail: **an era may be present without being dated.** §VIII.5.g is
already a licence for *undated arrival* — "things arrive anyway, and
they arrive without a date on them."

## What was already there

I did not know this when I ruled yesterday. Three separate licences for
post-1928 presence already exist, all owner-ruled:

- **The Rule of Signal** (§VIII.2) — anything carrying, capturing,
  switching, storing or reproducing a signal runs 40–60 years early,
  capped at 1967.
- **The purgatory licence** (§VIII.5.g, ruled 2026-08-09 at your
  direction) — "A machine built in 1919 receiving a programme from 1987
  is not a contradiction in a building where the year does not advance —
  it is Tuesday."
- **Centuries of tenancy** (§I) — residents who have been here, some of
  them, for centuries.

And it ships: `music_catalog.json` carries 36 tracks spanning 1962–2008,
each with an in-world provenance, and all eighteen residents have a
favourite and a memory of hearing it. 1928 people with memories of 1978
records, rendered to the player today.

The tapestry is not a new idea. It is the purgatory licence **given an
owner and a footprint**.

*Corrected 2026-08-30: this sentence originally justified itself by
citing "the 313-system census". No such census exists in the tree — the
number came from an unfiled workflow run and I cited it as settled.
The sourced figure is 99 (ORISON_V2_COMPOSITION_CENSUS_2026-08-28.md),
and there the dominant blocker is space rather than authorship. The
claim above survives on its own merits — an era entity genuinely does
need an owner and a footprint, and that is argued in this document
rather than borrowed — but it had no census behind it.*

## The struggle

1928 is an effort, and **the effort is maintenance.**

The building's hold on a space is **derived, never stored**: a pure read
over the maintenance facts the save already records — what part was
fitted, into which socket, at which campaign minute, by whom. Every
fixture whose replacement is out of period with its neighbours marks a
place where somebody gave up and fitted what was available. That is the
whole of the losing. Neglect a circuit long enough and what replaces it
is not from 1928 — the other jurisdictions rise into a room because the
room stopped being maintained, not because a scalar ticked.

Deliberately **not** a stored upkeep number. The repo has already made
that mistake twice and nobody noticed: `reality_game_state.gd:37-38`
declares **building_stability** and **reality_coherence** as durable
floats inside SAVE_VERSION 4, `reality_case_manager.gd:79` and `:142`
increment them monotonically, and a tree-wide grep returns **zero
readers**. Two global progress meters shipped in the save file. Delete
both in the same change that lands the derived hold, and add a generic
rule to the authority audit so the class is caught rather than the
instance.

Influence is **pull, never push**. An entity never writes into a room; a
space declares what it is subject to and its own owner composes one
result. Composition is **winner-plus-trace, never a blend** — one legible
dominant influence, the others present as residue — because five eras
averaged produce one grey era, and a blend *is* a resolution. The house
rule already ships as Mae Kessler's grammar: two systems cross without
merging and their overlap produces dark rather than a third answer.

**No aggregate at any scope.** The loader must structurally refuse a
floor-level or building-level roll-up, because the moment a total exists
someone renders it.

### The tells

Which lamp is actually in the socket. How wrong the lobby master clock
is — `clock_prop.gd:16` already ships a deliberate four-minute error,
already ruled both a station clock running ahead and a bad regulator;
make the constant a function of how recently it was serviced and the
struggle becomes readable off a dial with no narration. Whose notice is
pasted on top of whose. Which station a cabinet bezel names. Paint over
paint on a hard line.

**Forbidden as a tell: any number, bar, percentage, marker or
aggregate.** That is also the better fiction.

## The gate becomes a licence

`audit_period_dates.py` keeps its cutoff and becomes a licensing gate.

1. **Widen the corpus.** It currently opens five hardcoded paths and
   never walks `game/assets/`, which is why twelve arcade cabinets
   carrying `received_from` of 1931, 1948, 1977 and 1988 — composed onto
   a marquee a player reads in 3D — pass silently today.
2. **Require a licence** on any post-cutoff token: `{era | "undated",
   entity, mode, licensed_by, player_surface}`. Missing → fail.
   Unresolvable entity → fail. Outside the entity's own window → fail.
   `"undated"` is first-class, because §VIII.5.g licenses undated arrival.
3. **The one absolute no licence overrides**: mode `fabric` — made then,
   here now — postdating the cutoff on any reachable surface fails
   always. *No station sends copper.* That is what still catches a 1998
   coax cable, and it catches it on **mode**, not on the year.
4. **`licensed_by` is an enum of existing ruling ids**, verified against
   a real document heading. Otherwise the field is a rubber stamp and
   forging a licence is cheaper than obeying one.
5. **Retire the UNRULED trap.** The tool currently *fails the build when
   a decision is made* about `light_provenance.json`. That is not
   enforcing a decision, it is enforcing that none has been made. Convert
   to a transition check.
6. **Report-only for one run**, then baseline the noise.

**Precondition:** no licensed era overlap may be authored until the
codex lane's D1 (rect disjointness) and D2 (a stair pointing at a
missing level throws, the build continues, and exits 0) land. Until
then a deliberate impossibility and an authoring bug are the same record.

## The entities

Eight, capped. Each has a geographic footprint, a thematic footprint,
a system it rides on, and an ordinary explanation.

| Entity | Era | Rides on | Ordinary reading |
|---|---|---|---|
| **WORS 1610** | sends 1962–99 | acoustic graph, BroadcastDirector, cabinet bezels | everyone has a receiver and the building is over-wired |
| **The Ordinance** | 1867–1918 | ventilator stacks, light court, commensals | prewar housing law shaped every one of those features |
| **The Demonstration** | 1912 | the 119-point Vantry network, lobby, roof | a showcase building has showcase circulation |
| **The Sixteen Years** | 1912–27 | the demolition seam, causality sections | partial demolitions leave stubs and nobody documents a stub |
| **The Management** | undateable | notices, work orders, closed bays | landlords defer maintenance and post notices |
| **The Night Shift** | the 24-hour city | bodega hours, Harukiya after 02:00, your own shift | night workers exist and a super works nights |
| **The Survey** | an impulse, not a decade | watch stations, mail bank, coverage counts | buildings have always been surveyed obsessively |
| **The Player's Own Hour** | 2026 | day/night, schedules, live weather, every dial | the clocks in an old building are wrong |

Two notes on that table.

**WORS 1610 is the first to build** because every decision is already
ruled — an era, a geography, a theme, a resident who is its body, and a
hard silence around it. It supplies *timing*, never content: the
elevator arrives on the hour, a door closes on the hour, the boiler
cycles on the hour.

**The Player's Own Hour is entity zero, and it is already shipping,
unruled and invisible to every gate.** The 1928 Orison is currently lit,
timetabled, clocked and weathered by your real present: the day/night
director drives a real J2000 ephemeris at 40.75/−73.92, the schedule
director resolves presence from the real weekday, and live weather in
Queens is piped over the building. Your "struggle to maintain its 1928
identity" is therefore not a feature to build but **an existing
condition to name and gate**. The seam is already in the code, four
minutes wide, on the lobby clock.

Overlaps are designed, and at least two zones must read as nearly pure
single-jurisdiction or the crowded ones stop reading as crowded. The
best of them: **the light court**, where the Ordinance cut a shaft for
air and a shaft is a flue and a flue is an antenna — WORS gets the one
place we already pay for eight-storey coherence. And **the rear slot**,
where mandatory air meets water from below meets night condensation, so
the slot never dries — which matters because **4B** is entirely
rear-facing, and the player's own window becomes the aperture onto an
overlap rather than a siting accident.

**The pairing rule**, shipping in the same commit as the first entity
row: *every era tell must also appear in its host system's own ordinary
fault vocabulary.* A tell only this entity could have produced is not
deniable, and an undeniable tell has already decided §I's argument.
Expect to lose two or three favourites per pass; that is the gate
working.

## Synchronicity

**A synchronicity is a query, not an event.** No generator, no timer, no
event queue, no emitter — a pure reader over independently-owned durable
facts that detects when two of them rhyme and surfaces the coincidence
without authoring either half.

Three files, all runtime lane, none of them geometry:
**campaign_clock.gd** (the only new owner row the whole direction
requires), **coincidence_lattice.gd** (the week's co-presence lattice by
interval sweep, precomputed once — naive per-minute sampling would be
181,440 resolve calls against a boot already 27.7–33.2 s over a 24 s
ceiling), and **synchronicity_reader.gd** (pure; writes nothing, stores
nothing, holds no reference to the player).

**Scoring is surprisal, not equality.** A rhyme is two facts owned by
*different authorities* agreeing on a dimension where agreement is rare.
Measured in shipping data: ~4,120 co-present pair-minutes a week, of
which six pairs account for 150. Equality fires ~588 times a day;
a six-bit surprisal floor fires about six times a week. Same data, same
truth, 400× difference in dignity. **Silence is the default.**

**Determinism.** A pure function of (committed facts, campaign minute),
never stored. The engine is memoryless *by design* — a building that
recorded the coincidence would have authored it. Leaving it unrecorded,
so the only witness is the player who happened to turn to that page, is
what lets it evaporate rather than accumulate into a log of miracles.

**The prohibition that goes in the ruling, not in the culture:** the
engine may never motivate a change to the data it reads. The porter's
timings and Lena's corridor block are **frozen inputs**. Synchronicity
is destroyed retroactively and everywhere by exactly one authored
instance, because the player can no longer tell collision from
arrangement.

**Surfaced** as bare adjacent lines in the *dispatchd* log — a phone app
the fiction already promises and which does not exist. No adjective, no
arrow, never the word "coincidence". Times of day and weekday names
only; never a year.

### The first three rhymes, all from data that already ships

**The Thursday bodega.** Cal Dwyer 5B is at the counter 17:30–17:45 for
hearing-aid batteries and the evening paper. Omar Bell 3B is there the
same fifteen minutes for fuses, flux and milk. Noel is behind it. And on
Thursdays *only*, Nadia Quell is present for the whole forty-five
minutes — via a day-filtered block whose base entry says she listens to
which tenants are talking and about what. The building manager who
eavesdrops, standing between the deaf tenant buying batteries and the
super buying fuses, and neither man's timetable knows she is there.
**Not one authored pairing key touches any of it.**

**The doors round.** The porter applies the shutoff and the ledger
refuses the belief unless the resident is present; presence is answered
from her own timetable, where 05:00–05:45 is *"the doors round: testing
that every door opens, propping what sticks."* Let the fault run to
05:00 and you get a shut-off flat with a tag on the valve and nobody who
knows who did it — because she was out testing that every door in the
building opens, at the hour the one thing that entered hers did so
unseen. Both halves are computed today; nothing puts them side by side.

**The two counts.** The dream director stamps night index from dreams
had and spawn anchor from cases resolved, and *its own comment declines
to collapse them into one number "on the strength of that coincidence."*
The codebase has already noticed a numeric coincidence and correctly
refused to act on it — which is exactly the fact a reader should report.
The night the two integers first diverge is a durable, verifiable fact:
a dream was had that put no case down.

**Then stop.** Ship three, playtest the rate, add nothing until the rate
is known.

One class is **deferred by ruling**: causal near-miss ("the riser
hammered all night into an empty flat") is the most beautiful and the
only one that can lie, because it asserts a negative and our perception
model is incomplete — the ledger only accepts a listener from a room id
two characters long, so 371 of 550 acoustic nodes cannot produce one no
matter what happens in them, **including the corridors where residents
actually spend their time**. That is a real finding for the acoustic
owner on its own merits, and until it is fixed a near-miss would report
a limitation of the model as a fact about the world — a lie the player
could never catch.

## Evaporation

**The world is derived, the facts are stored, and nothing is both.**

We already ship the proof, and it has been mistaken for a dream trick
when it is the strictest persistence discipline in the codebase: the
fractal Orison decays as a pure function of (seed, room, nights) and
stores no map. Its own closing line is *"The house is not forgetting
you. It is just forgetting."* It already evaporates continuously and
reconstitutes — which is what dew does. It also reframes the S0–S3
ladder: lossless deterministic transitions are not a constraint *on*
evaporation, they are the **mechanism** for it.

Four rulings:

1. **Evaporation is presentational and terminal-only.** The world may
   stop being rendered, described and addressed; the fact store is never
   truncated. This sentence goes into the transaction model *before*
   anyone builds toward it, because the save path replaces the target
   directly with no temp-file-plus-rename and no read-back. An ending
   that dissolves is one keystroke from an ending that deletes.
2. **The dew is the player, not the world.** He arrives at 3 a.m., he
   dissolves at dawn, the building is still standing and does not notice
   he has gone. That honours the sentence completely — lightness,
   pleasure, ephemerality, an ending that dissolves rather than
   concludes — and it **resolves nothing**, which is the only version §I
   permits.
3. **The dream evaporates; the building remembers.** An entity's
   *presence* may withdraw by cross-sectional collapse (never
   alpha-fade — that says ghost). The *fact* that it was present is
   durable. The literal physics of dew: the water goes, the mark stays.
4. **Give the waking world a morning, because it does not have one.**
   Simulation time is a circle and nobody counts the laps, so two beliefs
   a day apart are unorderable; the day/night director declares a dawn
   state with no profile and no consumer; the only durable count of
   nights in the project belongs to the dream. Derive a shift index from
   the already-monotonic elapsed minutes and 420 becomes a real boundary
   with something to dissolve into.

## What this amends in yesterday's commit

**Falls:** "every datum after 1928-12-31" as a blanket refusal. It was
void when I wrote it — §VIII.5.g already licensed post-1928 reception,
at your direction, on 2026-08-09, and a ruling does not amend the bible
by disagreeing with it. Restated: **no *undeclared* datum after
1928-12-31.**

**Also falls:** my claim that re-datuming `light_provenance.json` was the
highest yield in the document. The arithmetic was backwards —
`author_light_provenance.py:126` is `rng.randint(1928, 1989)`, so 187 of
191 fixtures are dated in the *future* and re-datuming makes them more
forbidden, not less. **The goal survives by a different route: strip the
absolute year rather than re-dating it.** Keep maker, serial, hand,
quirk and `installed_onto`. That converts 191 records into undated
coverage, which §VIII.5.g licenses and dated provenance never did.

**Promoted to load-bearing:** `installed_onto`. With absolute years
struck it becomes the sole carrier of chronology. **Relative order
survives, absolute dates fall** — which is a better stratigraphy than a
year column ever was, and is exactly "they arrive without a date on
them."

**Survives and becomes the governing precedent:** the refusal of gold
stage 5 because it resolves the ambiguity. The same reasoning refuses
"it is all just a dream" as a diegetic statement. If gold may not become
the visible coordinate lattice of reality, the dream frame may not
become the stated explanation for everything that lattice would have
explained.

**Survives and generalises:** *impossibility must be declared or it is a
bug* — now extended from geometry to time.

**One new constraint, decided while it is free:** `corruption_lineages.json`
does not exist yet, so rule now that **era influence and resident wound
are two independent columns on one key.** A radiator can be corrupted
and can have conceded, in either order, with no coupling. Forbid a
combined accessor, and forbid the dream lane from reading the era column
at all — a scalar shared across the boundary would give gold stage 5 a
waking readout and resolve §I by arithmetic.

**And a defect the causal-wear rule would have caught:** eight dome
lamps in one basement corridor share a room, a display string, a quirk
and the prose "Wartime utility wiring, repeatedly patched" — and are
dated 1979, 1951, 1936, 1985, 1942, 1931, 1975 and 1932. Eight identical
lamps fitted across 54 years with one shared explanation is not
stratigraphy; it is a uniform draw wearing a date. **An era mark must be
derivable, not drawn.** Sibling fixtures on one circuit should share a
date because one electrician did one job on one day.

## On weight

You said *entertain and titillate*, and that lands as feedback. It is
measurable: across `design/*.md` — gate 444, audit 293, "must not" 121,
refuse/refusal 211, forbidden 54, rejected 50; against pleasure 4,
delight 4, playful 2. Roughly one pleasure-word per 15,000. Recent
commits run about 2:1 toward tooling and documents over game content.

Three specifics:

- **`shop_inventory.json` contains exactly one purchasable object in the
  entire game** — a carbon transmitter capsule, because a maintenance
  loop needed a part. There is nothing to want, taste or enjoy anywhere
  in the waking building. That needs rows, not machinery.
- **Evelyn's red pencil has nothing to correct.** Her whole
  characterisation is that she corrects the lobby notices, and
  `lobby_notices.json` is an eight-cell texture atlas with *no text in
  it*. The running gag is literally unreadable. The `issuer` + `body`
  fields adopted yesterday close it, and route through the house English
  lexicon — a module with a test scene and zero production consumers.
- **191 lines of the best atmospheric writing in the repo are in
  quarantine for a crime they did not commit.** Split it: quarantine
  `provenance` (which carries the rng years), release `quirk` (which
  carries no date at all). *"The guard throws bars that seem one rung too
  numerous." "Mica in the pull socket ticks as it warms."* The reader
  already prints them.

Two budget rules for my own lane, in the migration contract: **no new
gate without a named defect it would have caught**, and **a gate may not
be extended in a week it fires zero new findings.**

And one addition to the checkpoint template, which currently asks for
evidence, causality and owners and never this: *is anything in this
milestone worth reading?*

## The minimum version

All five claims delivered; only the *engines* deferred.

1. **Derive the era mark, strip the year** — rewrite the provenance
   generator as a function of room, circuit and adjacency; release
   `quirk`. *(tooling, days)*
2. **Turn the cutoff into a licence** — the six gate changes above.
   Non-negotiable safety item. *(tooling, days)*
3. **`era_entities.json` v1 by transcription** — five carrier-current
   stations already exist in shipped data; transcribe them plus three
   ruled bible entities. **Network footprints only in v1**, no regions,
   because a rect would inherit the coordinate-frame disagreement and the
   first era region would ship reflected. Needs geometry from nobody.
   *(data, one file)*
4. **One campaign clock** — a correctness fix owed anyway: today a
   resident's presence, and therefore whether a belief was legally
   earned, depends on your real weekday. Also add the two missing regexes
   so the authority audit can see host-clock reads at all. *(runtime,
   half a day + re-run the acceptance matrix)*
5. **Wire `with` and `route`** — already unblocked, zero dependencies,
   and it *is* the synchronicity substrate. *(runtime, days)*
6. **The reader and one surface** — the only genuinely new build.
   ~800 lines, zero draw calls, no new save subtree beyond the clock.
   *(runtime, 2–3 days)*
7. **Two paragraphs and some copy** — the evaporation sentence, the
   dream-frame paragraph, the notice bodies, and rows on a counter.
   *(hours)*

Not in the minimum: no era system, no entity runtime, no evaporation
mechanic, no upkeep director, no synchronicity generator, no region
footprints, no geometry, no boot cost, no draw calls.

## Decisions I need

1. **May "it is all just a dream after all" be said inside the world?**
   This ruling assumes no. If you want it spoken, that is an amendment to
   §I and should be requested by name — not arrive as art direction,
   because that is how a covenant erodes without anyone deciding to.
2. **The case ladder.** §I ordains Peter Wren second, and his premise is
   *bureaucracy_dungeon* — the least funny of the seventeen switched-off
   cases and the one most likely to read as more machinery. Promoting
   Rhea's karaoke exorcism instead reuses the bar, the songbook and the
   PA that already exist, and its portal rule is *"Imperfection can be
   voluntary."* Reordering reopens a bible ordination, so it is yours.
3. **The campaign's start day.** Deriving weekday from a durable clock
   makes day zero an authored decision hiding in a clock. Start on Monday
   and a player who plays four hours never sees Saturday's tenant
   meeting or the Thursday bodega collision.
4. **Is the entity register capped at eight?** The temptation is to add
   one per anachronism until the licence means nothing.
5. **The three tuning constants** — epsilon, surprisal floor, top-N. The
   engine fabricates nothing, but a reader choosing which of many true
   coincidences to show is exercising editorial power. Review them as
   copy, not as parameters.

## The risk I care most about

**The dream frame becomes a defect disposition.** Dream logic is a free,
unfalsifiable defence for any inconsistency: a prop in the wrong place, a
save that reconstructs wrong, an NPC who knows what they could not have
heard. The entire ethos apparatus exists to make those things *bugs*.
The frame un-bugs them and costs nothing to invoke.

One paragraph in the ethos, written before anyone builds toward this:
*the dream frame governs how the world is described and how it ends; it
never governs whether a fact has an owner. A defect explained as dream
logic is an undeclared impossibility.*

Dreams are worth building toward precisely because they feel absolutely
real from the inside. The rigour is what buys the strangeness.

---

*And the honest one about this document: it is the 202nd design markdown
on a programme with roughly one pleasure-word per fifteen thousand. If
the next commit after this ruling is another audit rather than a sandwich
on a bodega counter, the tone finding was recorded and not acted on.*
