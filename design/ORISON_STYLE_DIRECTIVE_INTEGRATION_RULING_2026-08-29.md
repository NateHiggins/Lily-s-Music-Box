# Style directive — integration ruling, 2026-08-29

Work order, not proof — named so the completeness ledger refuses it.
Space identifiers are **bold**, never backticked, so nothing here
promotes a requirement it merely describes.

Subject: the ORISON V2 AUTONOMOUS RE-IMAGINING MASTER DIRECTIVE, a
33-phase style and architecture guide supplied by the owner and
authored **without access to this repository**. Reviewed adversarially
by five independent readers (authority, physical scale, redundancy,
omission, steelman) against measured geometry, shipped code and the
binding rulings.

## Ruling in one paragraph

**The directive is demoted from authority to input, and it is worth
keeping.** It is a better art-direction document than anything this
programme has produced, and it is wrong about almost every number,
every date and every claim of authority. We take its authoring
vocabulary — element-indexed corruption lineage, the stage ordinal,
causal wear derivation, the installation-relationship rule, the
six-jobs threshold test, "what was abandoned rather than removed",
per-issuer typography, and the Phase 33 constraint. We refuse its
supersession clause, its second documentation home, its second world
system, its second ecology, its second sound model, its second audit,
and every datum after 1928-12-31.

## The two clauses that are struck

Rejected on process grounds, before any phase is read as an
instruction:

1. *"This directive supersedes any existing design decision that
   prevents that goal."* The clause is self-judging — the directive
   alone decides what prevents the goal — and what it would supersede
   are not design decisions but owner rulings and a binding contract:
   `VIRTUAL_ENVIRONMENT_ETHOS.md` ("binding design authority"),
   `ORISON_REBUILD_MIGRATION_CONTRACT_2026-08-28.md` ("Status:
   BINDING"), four rulings dated 2026-08-29 and one dated 2026-08-09.
2. *"Do not stop at proposals if repository access allows
   implementation."* Repository access is capability, not authority.
   The Godot lane is serialised; spatial construction is the codex
   owner's lane; the tree is shared, so named paths are staged and
   never `git add -A`.

Where a phase contradicts a ruling it becomes a **named question to
the owner citing document and date**. That route is cheap and
available — the owner rewrote his own Sept-3 handoff wholesale on
2026-08-29.

## The finding that matters most is ours, not theirs

Reading the directive's corruption grammar against ours exposed a
defect nobody had named.

`apartment_encroachment.gd:94` holds a table of **exactly six rows**,
one per named resident case — mina 2A, peter 4A, juno 2C, mae 6C,
cal 5B, omar 3B — each assigning an integer `grammar` that selects a
**hardcoded GLSL branch** at `orison_surface.gdshaderinc:425-466`, and
each clipped at `apartment_encroachment.gd:963` to that resident's
`unit_rect`.

Our corruption is therefore **indexed by resident**. Every grammar is
one person's wound, bounded to one apartment. There is no way to
corrupt a radiator, a railing, a street, a shopfront, a stair or a
foundation — and a seventh grammar requires editing GLSL, which fails
the owner's own expansion-proving test outright.

**Every space on the Sept-3 route** — the bodega, the street cell, the
apron, the vestibule, the lobby, the shed, the throat, the hall,
**B1** — **has no authored way to be wrong, and no gate would ever
notice.** That is the single highest-value thing this review produced,
and the directive's Phase 7 is the fix.

## Adopted

| From | What | Where it lives |
|---|---|---|
| §7 | **Element-indexed CorruptionLineage** keyed on architectural element, not resident | new `game/data/corruption_lineages.json` + loader beside `apartment_encroachment.gd`; the GLSL if/else becomes table-driven so lineage seven is a JSON row |
| §33 | **"No system, no lineage"** as a gate | `ordinary_system` a required field; loader refuses an entry whose named owner script does not exist |
| §6 | **Causal wear derivation** | `tools/bake_wall_finishes.py:89` — replace the rng family pick with causes derived from `building_layout.json` adjacency |
| §4 | **"What was abandoned rather than removed"** | a `## Causality` section in the checkpoint template; linter checks existence only, never truth |
| §1/§2 | **The six-jobs threshold test** as portal acceptance | the portal contract, checked in the threshold's checkpoint |
| §3 | **Landmark visibility record** as data | one file, for the Vantry frontispiece only |
| §26 | **Asset ingest metadata** — era, causes, alien descendant at generation time | three keys on the existing `material.json` |
| §21 | **Per-issuer typographic registers**, notices as text not baked pixels | `issuer` + `body` on `lobby_notices.json` |
| §29 | The rendering technique list (HLOD, texture streaming are the open items) | aimed at the measured draw-call bottleneck |
| §24 | Crouched / near-wall / reverse / max-reach stations | added to existing shot suites, not a new QA process |
| §28 | The moment-to-moment reference as an **acceptance script** | the slice checkpoint; the best-written passage in the directive |
| §31 | Salvage before deleting, but do not preserve dead architecture | one paragraph in the migration contract |

## Amended

**§5 temporal archaeology — keep the method, discard every datum.**
1928 is not the root layer, it is the **present**
(`phone_os.gd:3 FICTIONAL_PRESENT_YEAR := "1928"`, enforced by
`tools/audit_period_dates.py` at a 1928-12-31 cutoff). Re-datum to:
pre-1912 site → 1912 build → 1927 partial demolition → 1928 refit →
the unknown layer beneath. Keep the installation-relationship rule
verbatim and add `installed_onto` as required. This unlocks **191
fixtures** in `light_provenance.json` carrying authored-quality
provenance that nobody may show a player because the field reads
`temporal_status: UNRULED`. Highest yield per unit of work in the
whole document: the content is already written and merely forbidden.

**§8 gold ladder — adopt 0–4 as an ordinal, cap the waking world at 4.**
`corruption_stage: int` alongside the existing `intensity`, with
intensity demoted to the within-stage blend. Precedent is directly
adjacent: `STAGE_INTENSITY` at `apartment_encroachment.gd:108` already
maps named stages to intensity. Stage 5 — "gold becomes the visible
coordinate lattice of reality" — **resolves the ambiguity**, and
`ORISON_BIBLE` §I is a covenant that no scene may. It lives in the
dream lane only. A per-cell 0–5 scalar advanced by progress is a
morality meter under another name and is forbidden by ethos §7.

**§2 WorldDirector — extraction, not greenfield.** A child of
CampaignShell, its residency algorithm lifted from
`dream_room_builder.gd` (the only real streaming that ships). It emits
neutral world events; owners apply them. Delete `persistent objects`,
`narrative state` and `corruption level` from the cell record; add
`simulation_tier` and `last_simulated_minute`, explicitly independent
of `rendering_tier`.

**§15 level 6 — split into three.** "Space alters when unseen" is
adopted unchanged; it is already standing law as the bucket transition
rule with `porter_actor.gd advance_to` as the reference. "Geometry
depends on player position" requires a named owner, a durable
resolved-variant fact, a `DATA_SUBTREE_OWNERS` row and a K3 reload test
before one such space is authored. "Reflection shows different
topology" is presentation-only pending the World3D decision below.

**§31 priority list — insert a rank zero.** Above all eight: binding
owner rulings, the ethos contract, the save architecture, the rollback
selector, the three gates. As written it ranks physical coherence and
interesting traversal above the ethos, which licenses an objective
marker to guide the player through the slice — that is
`OBJECTIVE_UI_LEAK`, a class the ethos audit already fails on.

Also amended: §9 flesh (the parameters already ship as a typed
Resource; the amendment is scope, not a document), §6 naming (adopt
the ban, reject the filename encoding — a manifest is machine-readable
and a filename is not), §20 humour (adopt the pattern and the
70/20/8/2 split as a *reported, non-failing* distribution; reject the
specimen texts, which are 2020s SCP register), §19 ecology (same
ecology at a different rate), §13 construction (adopt the function,
replace the vocabulary — the modern sidewalk shed is a 1980 Local Law
11 artifact), §25 HeroCompositionZone (a rename of `WallArtLaw`, not a
build), §0 (a one-page crosswalk, not a fresh audit), §12 arcade (cut
the galleries — see numbers).

## Rejected

Beyond the two struck clauses: `docs/v2_reimagination/` as a new
documentation root (`audit_orison_v2_completeness.py:603` globs
**only** `design/ORISON_V2_*.md` — a file under `docs/` is not
admitted, not refused, and not reported; it is outside the gate's field
of view, so a parallel tree is not a second opinion, it is a second
canon); the fresh full-tree audit (duplicates 21 agents of completed
work, and its five categories are a coarser version of a nine-value
enum already computed over 3,626 records); WorldState as a peer of
RealityState; the seven-layer authored sound bed (it would downgrade a
550-node physical propagation model to ambience and break the
observation ledger's only honest provenance for who could have heard
something); §32 as a prose gate (prose no tool reads is exactly the
failure the ledger was hardened against); re-specifying the bar
(Harukiya is built and already runs the rule); **every dated artifact
after 1928-12-31**; constant-angle scale cheats at exterior range; a
second waking ecology; push-model spatial causality; a durable per-cell
corruption scalar; a second dimensional standardisation pass.

## Arbitration rules

1. **Authority (rank zero).** The directive is input. A collision
   becomes a named question to the owner, never an agent's judgement.
2. **Lane.** Any phase whose output is geometry, schema or blockout
   stops at a proposal by construction, however clean the artistic case.
3. **Corruption is a fact, not a mesh state.** A lineage's stage is a
   durable integer owned by the element's *existing* owner class,
   committed through RealityState with a `DATA_SUBTREE_OWNERS` row in
   the same commit. Masks, decals, shaders and child nodes are
   deterministic **readers** and may never write. `advance()` is a pure
   function of (facts, elapsed simulation minutes) — never of wall
   clock, frame rate, residency, or a "was observed" flag.
4. **Observer-dependence reads facts, not the camera.** Record "the
   player has seen corridor C from the north end at minute M" as a
   committed observation fact — extending the observation ledger's
   shape, so the *building* observes the player, which is also better
   fiction — and derive topology from the fact set.
5. **Spatial causality is pull, not push.** Space B declares that its
   topology depends on door A; A never reaches into B. Survives the
   authority gate, survives save, and is cheaper.
6. **Dressing and simulated state are two authorities with two slot
   pools.** Exclusion zones constrain seeded meaningless variation
   only. Anything takeable, and anything that is the sensory *tell* of
   a simulated quantity, is an authored anchor owned by its fact owner.
   A hero sightline may be protected from clutter; it may not be
   protected from consequence.
7. **Split the illusion law into two sentences and keep both.** *The
   illusion is more important than literal rendering* — measured true,
   the frame is draw-call bound. *Simulation is never illusory* — every
   quantity the player can perceive or act on is a durable fact with
   one owner. Rendering may lie about how a fact **looks**; it may
   never be the authority **for** the fact. A facade is a simulated
   shop rendered cheaply, never a fake one.
8. **Simulation runs on the honest metric.** Travel time, audibility,
   transit and errand cost read the declared logical adjacency graph
   only. Forced perspective is a rendering transform with **zero read
   path** into simulation — otherwise the first compressed sightline
   silently rewrites who hears the riser.
9. **Rendering residency may never gate simulation tier.**
10. **Impossibility must be declared or it is a bug.** Every intended
    overlap or dangling reference carries a schema field naming its
    kind and the ruling that licensed it. Impossibility the tooling
    cannot distinguish from a mistake is unverified geometry.
11. **No system, no lineage.** A vascular radiator in a building where
    heat is scenery is a monster costume; the same mesh while heat is
    deciding who is cold is a diagnosis. The exact inverse of the
    shipped rule "no tell, no variable" — it keeps the corruption
    catalogue structurally unable to outrun the simulation catalogue.

## The numbers, corrected

The directive's illusions were sized for a city block we do not have.

- **Playable exterior**: 40.70 m wide, sidewalk band 18.34 m deep.
  Longest straight walk is the corner diagonal at **44.64 m**. There is
  no 140 m sighting anywhere in the world, and §3's 60 m approach walk
  exceeds the entire street by 47%.
- **§3 landmark, corrected**: express landmarks in **angular ratio and
  occlusion seconds**, never metres. Target ×3.5–4.0 with ≥6 s of
  continuous occlusion. Delete "expected distance" from the schema — at
  40 m the player has no distance estimate to violate, only an angular
  one.
- **The east dogleg, budgeted**: leg 1 east 6.0 m in the kerb line
  (roof at 3.4 m hides the frontispiece attic), leg 2 south 12.0 m in
  the clear 11.76 m slot. Adds 18.0 m; total exterior route **58.7 m**
  — 97.8% of the directive's ask — giving 6.0 s of occlusion and a
  **×3.7** re-emergence, not ×5.6. Route the slice east first so the
  shed is entered facing away from the arcade.
- **The arcade is currently pre-disclosed.** From the doorstep the
  frontispiece is 23.04 m away subtending 27.7°; from x ≥ 10 the player
  sees the full 26.0 m depth to the back wall — a 52.60 m sightline,
  the longest in the world. There is no reveal to stage. Dropping the
  throat mouth ceiling 4.20 → ~3.30 m closes it for one edited box.
- **The release we own is vertical**: ceiling elevation runs 15.2° at
  the throat mouth → 70.7° at the nave threshold → 72.9° under the
  lantern. **×4.66 in 3.4 s.** Short range makes this *cheaper*, not
  dearer. Add nothing above 4.04 m in the throat.
- **The hall is not a room 20 m wide.** Correct the arrangement doc: a
  **5.32 m public aisle × 26.0 m** under a 9.92 m crown inside a 20 m
  shell. Section ratio 1 : 1.86 — a Parisian passage, not a nave.
  Galleries would leave 2.92 m of aisle; cut them. The clock fits at
  2.2–2.6 m.
- **§14's cheat is banned within 45 m.** dθ/dd = w/d²: a 0.7 m stride
  moves an 8.38 m sign 0.023° at 120 m but moves the frontispiece
  **0.861°** at its real 23.04 m — 37× more detectable per step. Our
  entire exterior is 18–45 m, squarely inside the band where
  stereopsis, motion parallax and angular-size gradient all still work.
- **§28's "street expands upward" is false here.** Sky wedge 62.7° from
  the front door where a real Manhattan canyon of the same width is
  17.8° — our street is 3–4× *more* open than the beat's own reference.
  **But the canyon we already own is at the rear and nobody is using
  it**: the rear light slot measures 16.4–22.2°, within 3° of the real
  thing. Move the beat there; cost nothing.
- **§23's 30 m corridor does not exist** (longest interior straight is
  19.30 m, and the footprint is 28 × 20 m). Either site it under the
  carriageway with a real utility function, or shorten to 19 m and dim
  the violet source by ≈0.40 so it reads the same.
- **§16's 18 m block is under the street, not inside B1.** B1's longest
  room run is 10.53 m; the available 18.02 m is north–south under the
  carriageway. The height concealment is free: 2.62 m of headroom means
  you physically cannot see the top of anything.
- **Occluder sizing rule**: codify 2.40 m as the hoarding standard.
  Hoardings hide the ground plane; roofs carry the world-continues
  promise. An occluder hiding a landmark needs roughly
  2·h·d_occ/d_landmark — which is why the dogleg is the only mechanism
  available.
- **Two live coordinate frames disagree.** The development blockout
  declares street "south" and a 32 × 24.5 footprint; production
  `building_layout.json` has 28 × 20 and negates to +z. State in every
  cell manifest that **`building_layout.json` is the only metric
  authority**, or the first manifest ships a reflected world.

## Owner decisions

1. **The era ladder.** Is the stratigraphy pre-1912 site → 1912 build →
   1927 partial demolition → 1928 refit → the unknown layer? And does
   that promote `light_provenance.json` out of `generated_flavor` into
   player-visible canon? *Highest-yield decision available — 191
   fixtures wait on it, and Phases 4, 5, 13, 17 and 21 wait on them.*
2. **Gold stage 5.** Recommend: waking world caps at stage 4, stage 5
   lives only in the dream where resolution is permitted. Confirm or
   overturn.
3. **Reflected-world divergence.** Both shipped mirror owners share
   World3D, which is exactly how they guarantee zero reflection depth.
   Divergent topology needs `own_world_3d = true` and reopens a cost
   argument the planar mirror's own header settled once. Pay it for a
   bounded set of surfaces, or rule the reflected world
   presentation-only — beautiful, ordered, populated, same rooms.
4. **The street's south side.** Raise it (gateway 9.98 → ~16 m,
   Harukiya mass 22.65 → ~30 m, pulling mid-carriageway to ~33°), or
   drop the beat and move it to the rear slot. Do not narrow the
   street either way — the carriageway bounds are load-bearing for the
   traffic crossing.
5. **The throat ceiling.** Approve the 4.20 → 3.30 m edit, or accept
   that the arcade's reveal is the dogleg's occlusion only.
6. **The player's unit.** **4B** is entirely rear-facing; there is no
   street or arcade window anywhere in it. Re-site the player, or rule
   that the arcade is something you only ever meet at street level —
   which makes the vestibule threshold the genuine first sight, and
   gives the rear canyon a reason to be the view the player knows best
   before it becomes the fire-escape lineage.

## Work this creates

**Unblocked now, no dependency:** wire the three dead schedule fields
(`with`, then `route`, then `outfit` — 25 pairings, 9 polylines, 414
outfit values shipping today with zero readers; highest perceptible
aliveness per line in the project, and `route` gives the street its
inhabited traffic before a single new asset exists). Author
OccluderInstance3D geometry (occlusion culling is *enabled* and the
class appears in exactly one file — read `building_root.gd:7-16` first,
a pass was built and removed on 2026-08-05 with a written reason).
Re-run the technical ceiling assessment, which died on a spend limit
and which Phases 5, 6, 13, 21 and 26 all depend on, because they all
maximise consumption of authoring bandwidth.

**Then:** `corruption_lineages.json` + loader + the table-driven shader
refactor; causal wear in the bake tool; the `## Causality` checkpoint
section; the landmark record; the era-ladder promotion of
`light_provenance.json`; notice issuers and bodies; the
HeroCompositionZone rename (and consume or retire
`resident_decor_profiles.json` in the same change — a complete
seventeen-household decorating brief with zero consumers); the
WorldDirector extraction; the disposition crosswalk.

**Codex lane:** fix the rehearsal's D1 (no rect disjointness check) and
D2 (a stair pointing at a missing level throws, the build continues,
prints its success census and exits 0) **before** any licensed
impossible geometry — until they land, deliberate impossibility and an
authoring bug are the same record with a silent pass. Then the east
dogleg in 1928 vocabulary, authored as a reusable portal/occluder/
barrier template rather than one-off street dressing.

**Correction owed:** the arrangement direction's "20 × 26 m glass hall"
and "0.4 m apart" figures are wrong (5.32 m aisle; 0.15 m between built
faces) and are already being used to size things.

## What the directive gets right that we did not have

We had no style language at all. It supplies one, and the parts that
survive are the parts that are **data rather than prose**.

Its Phase 33 thesis — that the intelligence does not invade the city's
organising systems but reveals their resemblance — is our simulation
programme arriving from the opposite direction. If radiator heat is
already zero-sum arithmetic deciding which resident is cold, then "the
radiator becomes vascular" is not a metaphor bolted onto a prop; it is
the visual reading of a system we are already building. Those two
halves were written by people who never spoke, and they fit.

That convergence is why rule 11 is the most important line in this
document, and why it is stated as a refusal rather than an
aspiration.
