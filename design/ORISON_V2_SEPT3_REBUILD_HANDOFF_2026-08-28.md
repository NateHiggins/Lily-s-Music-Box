# Orison rebuild — Sept 3 handoff pack

**Rewritten 2026-08-29.** The owner issued a world-redesign directive
that supersedes the building-only plan, and the work order below
replaces the floor list this pack carried on Aug 28. Authoritative
state: `origin/main`, plus the management branch
`claude/mgmt-sept3-handoff` carrying the rulings cited throughout.

Audience: the returning spatial-construction owner. Read this first,
then the four rulings it cites.

---

## 1. What changed while you were away

**The brief.** The whole map becomes one seamless traversable place
built from invisible performance cells: predictive streaming, a
landmark visibility network, layered geometry (contact / midground /
distant proxy / impossible horizon), forced perspective, impossible
geometry that means something, temporal sediment, construction as
occluder, and strict performance budgets. The vertical slice it wants
proved first is **ORISON INTERIOR → LOBBY → FRONT DOOR → STREET →
CONSTRUCTION → ARCADE**, continuously traversable, surviving
360-degree inspection.

**Open Shift landed, ethos-corrected.** NpcObservationLedger is the
only writer of NPC knowledge (beliefs earned through acoustic
audibility, in-home sight or direct inspection, each with provenance);
PorterActor performs compensation as a real actor; packing custody is
one inventory record. Your radiator model and its seven surfaces are
untouched. Your `codex/ethos-open-shift` branch is preserved for your
own reconciliation.

**A third gate exists**: `tools/audit_systemic_situation_authority.py`
— fails coordinator-authored NPC knowledge, timers impersonating
actors, shadow custody, objective UI, wall-clock world mutation.

**The ledger learned to refuse prose.** Two shipped documents were
promoting the geometry they described. Intake is now an allowlist on
the **filename**.

**Saves no longer constrain you.** The owner has waived backward
compatibility with shipped save files. The dream generator may be
redesigned without golden-vector versioning; compatibility aliases
retire. The save *architecture* stands — new saves must still
reconstruct concrete facts.

---

## 2. Four binding rulings

**AXIS — the world is +z.** The shipped v1 convention wins: the street
runs outward from the front door along Godot **+z**; v2's mirrored
review apron is what moves. The two worlds were mirror images about
the building and nobody had noticed, because v2's exterior stops at a
6.0 × 3.35 m apron with nothing outside it to disagree. Everything
already in +z stays — the three street bands (north pavement
z 9.45–14.75, carriageway 14.75–23.894, south pavement
23.894–28.316), the arcade throat's portal plane at z 28.316,
Harukiya's envelope, the traffic lanes.
→ **ORISON_NEIGHBOURHOOD_ARRANGEMENT_DIRECTION_2026-08-29.md**

**LICENCE — reimagine freely, but prove expansion.** The owner grants
full authority to move, orient and reimagine any element for
character and flow: *"the rule of cool and future expansion proving is
priority."* The discipline is the second half. **Every first piece is
the template for the Nth.** The first cell teaches how cells are made;
the first portal, how portals are contracted; the first shop, how
shops are bucketed; the first world edge, how the map grows. Judge
every piece by: *is piece two now cheap?*

**COMMERCE — the bodega is the hero shop.** Not an invention: the
fiction built it years ago and never gave it a room.
`schedule_director` anchors it 18.78 m east of the front door on the
same pavement; `resident_routines` walks an authored street polyline
to it; `resident_schedules.json` sends neighbours there twenty-plus
times a day with authored habits, a night clerk, a humming cooler and
a sale sign one resident mentally corrects. `shop_entry_test.gd`
already walks into its shell.
→ **ORISON_COMMERCIAL_DESTINATION_PLAN_2026-08-29.md**

**SIMULATION — bucket separately from rendering.** Two ladders with
opposite cost curves. Rendering is draw-call bound, so few interiors
may be resident; a shop advancing stock, staffing, hours and condition
costs a few floats per simulated minute. **Simulate everything, render
almost nothing.** Four tiers — S0 dormant, S1 statistical, S2
scheduled, S3 embodied — with lossless deterministic transitions;
`porter_actor.gd:69 advance_to` is the reference implementation.
Facades are simulated shops rendered cheaply, never fake ones.
→ **ORISON_SIMULATION_BUCKET_ARCHITECTURE_2026-08-29.md**

---

## 3. Your work order, in order

The old order — F03/F05/F06/B1/ROOF plus apartments — is roughly 75 of
the 80 structural blockers and **not one of them lies between the
front door and the arcade.** Everything on it still gets built; almost
none of it should be built first.

**Hour one, zero geometry.** A correctly-named `*_CHECKPOINT.md`
backticking **F02_B_VESTIBULE** and **F01_WATCH**, and clearing the
stale **B1_PUBLIC_LANDING_E**. Both spaces are built, walked and
owner-accepted, and block STRUCTURAL purely for want of a backtick.
Two blockers, no geometry.

**First build — the bodega interior and its back-counter notions.**
Beat 4 of the golden shift clears (the part source moved onto the
street leg, so the human run stops being pre-determined), the street
gets its first cell, and the resident timetable populates the room for
free. Three payoffs from one room. Build it as a **bucket**: durable
facts and `advance()` before geometry.

**Second — the declared service-hall openings on F02 and F04.**
Traversal is already proved; the schema is merely silent, and that
silence is what holds both floors at SHELL_ONLY.

**Third — cut the `floor_01` export.** This is the hard unlock and
nothing horizontal can start until it lands. `floor_01.gltf` (12.02 MB)
welds the ground storey, the entire 220 × 148 m street/site export,
the Passage shell and eleven fitted shop interiors into per-material
buffers — one spans x −108…104. Cut it at the granularity the
residency proof measures (see §5).

**Fourth — make the v2 street threshold real on the ruled axis**:
apron, vestibule, lobby. The vestibule airlock is the best ready-made
cell boundary in the project and currently exists only in the world
with no street outside it.

**Fifth — F03 only**, as the floor carrying the vertical proof. Then
stop and read the route.

**Sixth, after the route is proven end to end** — F05, F06, B1, ROOF,
the electrical and fire-service riser vocabulary, remaining apartments
by case dependency, the F01 staff restroom.

### Three arrangement moves the measurements made possible

**The arcade stops being a cul-de-sac.** The Vantry Arcade is a
20 × 26 m glass hall with eleven fitted shops, one entrance, a solid
end wall at z 64.6, no second exit and no vertical. Harukiya sits at
x −12…6.4, z 28.32…38.20, **below grade** to y −3.35; the hall at
x 4…24, z 38.6…64.6. They overlap in x, sit 0.4 m apart in z, and are
separated only in height. **A service stair from the hall's west end
descends south into the bar** — second exit, vertical, and the brief's
compression-and-release rhythm honestly earned.

**One world edge proves it can end; the other proves it can grow.**
Keep the west street end exactly as built — three named collision
spans, timber posts, baked wet board, a storm curtain that lets
traffic vanish into weather rather than into a fence. Turn the **east**
end into a sidewalk shed that turns a corner: covered scaffolding, a
dogleg, a barrier plainly temporary rather than plainly final. That is
the expansion-proving template — occluder, streaming gate, compression
point and promise in one build.

**The bodega's back room opens into B1.** Not the arcade — measured
geography kills that; the throat is diagonally across the street and
the link would read as a shortcut. Down into the player's own cellar
instead: it violates *home*, which is the only space the player learns
well enough for the violation to land; parts reach the boiler without
crossing the street, so comprehension buys travel time; and it arrives
where §10's cyclopean payload belongs.

**Trades follow their streets.** The eleven shops are fitted
interiors, so redistribution costs arrangement, not modelling. To the
street: news & cigars as a kiosk, keys cut, shoe rebuilding, model
laundry (its steam vents to the pavement and doubles as an occluder).
Staying in the arcade: photo supplies, radio service, pawnbroker,
funeral parlour, luncheonette, and **Otis & Son** — the elevator
company whose machine you maintain, two blocks from your lift.

---

## 4. Three things that block work already scheduled

**No exterior geometry until the ledger carries a region axis.**
Its only exterior requirement today is `site.street_threshold`, whose
own note concedes the apron is a review shell. Nothing scores the
street, the construction seam, the arcade portal, the throat, the hall
or the shops. Build a perfect arcade route and the board shows zero —
the same failure that has an accepted watch station blocking for want
of a backtick. **Claude lane; management is dispatching it.**

**The exterior has no v2 authoring home**, and nobody scheduled
creating one. Any megastructure generation writes to the v2 output
tree only; v1 stays byte-identical and is proved so by hash. Do not
accept *"we will just edit gen_layout.py"* — that silently spends the
rollback.

**One real save defect.** If the dream module catalogue's revision
changes, saved dreams have no reconciliation path. Land that
reconciliation before geometry work, not after.

---

## 5. What Claude is building in parallel

Not your lane, but you depend on the number it produces.

**The first seamless proof is vertical, not horizontal** — because the
eight floor glTFs are already separate loadable units while
`floor_01` is one welded buffer, and because
`ResourceLoader.load_threaded_request` has **zero uses repo-wide**.
An env-gated floor-residency manager streams those eight files, hidden
inside the elevator's sealed ~2.7 s ride, tested against the atrium
light court — an unbroken B1-to-roof sightline that forces all eight
storeys visible at 25,996 objects and ~31 ms. Production boot
currently blows its 24-second ceiling at **27.7–33.2 s**.

Its deliverable is a **number**: milliseconds per MB of resident
geometry, and how much moves off-thread. **That number decides how
finely you cut `floor_01`.** Do not cut before it lands.

Also in the Claude lane: the ledger's region axis, the simulation
bucket registry, and Wave 1–2 of the simulation plan (below).

---

## 6. The simulation programme, for context

313 systems catalogued across services, commerce, people, fabric,
institution, environment, anomaly and the player's body. The dominant
finding: **the missing piece is almost never simulation — it is an
owner and an `advance()`.** Wave 1 is therefore mostly renaming code
that already runs correctly.

The finding you will care about most: **`with`, `route` and `outfit`
in `resident_schedules.json` have zero readers anywhere.** Eight
authored patrol polylines, roughly fifteen co-presence pairings and a
three-state wardrobe are shipped data being ignored. Switching them on
is the highest perceptible-aliveness-per-line item in the whole
catalogue, and it needs no geometry.

Waves: (1) name what runs — bucket registry, S0 floor; (2) the
building is inhabited — read the unread fields; (3) the complaint
economy — unmet need becomes somebody's report; (4) S0 decay
integrals; (5) goods and scarcity, deliberately after your part-source
space exists; (6) air, water and the delayed bill; (7) rumour,
reputation and absence.

Also useful: an explicit **do-not-build** list. No pressure or flow
solver, no volumetric odour diffusion, no per-appliance electrical
waveform, no drainage hydraulics, no sectional radiator conduction —
each fails the tell test, because the player perceives *cold iron
under a palm*, not a differential equation.

---

## 7. Standing law

`BuildingRootSelector.DEFAULT_ID` stays **"v1"**; M09 stays
unauthorised until PRODUCTION_CUTOVER is clean and the owner signs.
The Godot lane is serialised — one process, wait politely; the runner
needs `-LogPath` to write logs, and its ceiling is 60 s, so heavy
suites run directly. **Historical exit codes are worthless**: before
2026-08-28 the runner returned 0 for everything. Preserved identities:
`OrisonV2AnchorAdapter.REQUIRED` plus the migration contract's table,
the M08E ritual/2B/B1 identities, and `F02_B_RADIATOR_01`'s acoustic
node (the observation ledger derives who hears the riser from
`AcousticGraphData.audibility`; it reaches **3B**, so `omar_bell` is
the canonical hearing neighbour).

Gates, before and after every landing:

```
python tools/audit_orison_v2_completeness.py
python tools/audit_orison_spatial_dependencies.py
python tools/audit_systemic_situation_authority.py
python tools/tests/test_orison_v2_completeness.py
python tools/tests/test_orison_spatial_dependencies.py
python tools/tests/test_systemic_situation_authority.py
```

Spatial deltas update the manifest deliberately in the same commit,
never to silence drift. The ethos baseline accepts no new suppressions
without written justification. The completeness canon lives at the top
of the completeness tool — change the program, change the canon in the
same commit.

**Naming decides what proves anything.** Reports, censuses and
handoffs are inert; a checkpoint without `CHECKPOINT` / `ACCEPTANCE`
in its filename proves nothing either. Backtick the exact ids you
actually proved, and check any new design file first:

```
python tools/audit_orison_v2_completeness.py --evidence-impact <path>
```

**Expect the count to rise before it falls.** A two-apartment floor
took STRUCTURAL 80 → 92 on being built, then → 74 once its checkpoint
named the ids. Build, then checkpoint, then read the number.

---

## 8. Known gap in this pack

The measured technical ceiling is **not** in this document. The
catalogue's ceiling assessment — draw calls, CPU, physics, agent
counts, memory, save size, audio voices, and authoring bandwidth —
failed to complete on a spend limit and has not been re-run.
Management's working assumption, stated as an assumption: the binding
constraint is **authoring bandwidth**, not compute, because every
simulated quantity needs a sensory tell and tells are art, audio and
text. That should be verified before it is relied upon.
