# Dream temporal specimen ledger

**Kind: audit** (`DOCS.md` — "evidence with a method and confidence levels;
findings graduate to the queue, the audit stays as the record"). It is not a
covenant, not a brief and not a status ledger. Where it disagrees with
`design/ORISON_BIBLE.md`, the Bible wins.

Closes the classification half of **T4-1**. Recorded against `611e71c`
("Prove the organelle conversation in the production root").

Binding doctrine, in precedence order:

1. `design/ORISON_BIBLE.md` — the covenant, including §VIII.2's Rule of Signal
   and the 2026-08-24 organelle ruling.
2. `design/DREAM_TEMPORAL_BIOLOGY.md` — complete access, incomplete
   interpretation; the specimen-to-organ rule; the production gates.
3. `design/DREAM_ORGANELLE_COMMUNICATION.md` — the owner-order rulings and the
   transient packet contract.
4. `design/DREAM_ECOLOGY_ARCHITECTURE.md` — the three-resolution model.

This document **classifies what already exists**. It is not an implementation
pass, it proposes no new owner, packet seam, save fact, hazard or pursuit
behaviour, and it does not reopen approved art, topology, ownership, rendering,
N9 or DO-4 decisions.

## How to read a row

Each row answers the eight T4-1 fields, which fold into
`DREAM_TEMPORAL_BIOLOGY.md`'s seven production gates:

| Field | Gate |
|---|---|
| 1. organ family + runtime status | — |
| 2. actual specimen(s) | gate 1 |
| 3. scale and era observed | gate 1 |
| 4. whole-body organelle function | gate 2 |
| 5. her specific misreading | gate 3 |
| 6. implementation / proof owner | gates 4, 5 |
| 7. contradiction or missing receptor | gates 6, 7 |
| 8. recommended future recipient behaviour | **recommendation only** |

### Evidence classes — these are not interchangeable

| Tag | Means |
|---|---|
| **LANDED** | Running in production with a source path and, where visual, a proof README. Cited both ways. |
| **APPROVED** | Ruled by the owner, design exists, runtime does not. |
| **PROPOSED** | Written in a brief, never ruled. Carries no authority. |
| **RECOMMENDATION** | Mine. Needs owner approval before anyone builds it. |

Field 8 is **always** RECOMMENDATION, in every row, without exception. Nothing
in column 8 has been approved by anybody.

### Era discipline

An era in field 3 is **when she observed the specimen**, not when the Orison
may show it. Waking 1927 remains strict: `DREAM_TEMPORAL_BIOLOGY.md` allows
only bounded mistranslation evidence on an existing historical object, and the
Rule of Signal still governs the building's sanctioned divergence. A 2010
Physarum agent model in field 3 licenses no post-1927 waking prop whatsoever.

---

## Resolution 1 — the field and the architecture

### 1. Living architecture / `LivingField` — LANDED

| | |
|---|---|
| **Specimen** | *Physarum polycephalum* plasmodium. The source names its own references: agent-based trail-sensing after Jones 2010, and stain-avoidance after Reid et al. 2012 (`game/scripts/reality/living_field.gd:1-19`). |
| **Scale / era** | A single-celled organism at centimetre-to-metre colony extent; the organism is ancient, the computational reading is 2010–2012. |
| **Organelle function** | Transport, resource allocation and extracellular memory. Trail is the live gradient, body the plasmodium, stain the record it lays and then avoids. |
| **Her misreading** | She reads the building's circulation — corridors, service runs, a floor plan — as a foraging problem, and grows a network to solve it. A plan drawn for people to live inside is mistaken for a nutrient graph. The stain is then read as "where the body has already fed", so the building acquires a memory of passage nobody asked it to keep. |
| **Owner / proof** | `game/scripts/reality/living_field.gd`; receptor `receive_vascular_pulse` (:591) wired by `game/scripts/reality/apartment_encroachment.gd:383-420` `_receive_architecture_signals`. Production proof: `art/renders/dream_organelle_production/README.md` frame `07`, 14 existing cells pressurized, `architecture.received=1`. |
| **Contradiction / missing receptor** | None. This is the only fully-closed recipient loop in the ecology: it consumes an addressed packet, is idempotent per `(src_id, born)`, adds no agents and no stain, and holds "presentation only: no collision, no gameplay owner, no save key". |
| **Field 8 — RECOMMENDATION** | The gradient is currently written *to* and never read *from* by other organs. A future organ could sense `trail` as a chemotactic field rather than being told a position — turning architecture from a recipient into a medium. **Recommendation only; needs owner approval, and would be a DO-3 breadth item, not a new seam.** |

---

## Resolution 2 — the limbs

### 2. Modelled hero limb — LANDED

| | |
|---|---|
| **Specimen** | A dendrite seeking a synapse (`DREAM_TEMPORAL_BIOLOGY.md`, first row of the strong-source table), carried on a cephalopod-arm body plan; plus vesicle transport / exocytosis across a narrow cleft. |
| **Scale / era** | Synaptic cleft ~20 nm and a growth cone a few µm, re-grown at ~1 m. The neuron doctrine is Cajal, 1890s; synapse formation as an active seeking process is mid-twentieth century onward. |
| **Organelle function** | The being's principal effector and afferent: local approach, dwell, retraction, reconsideration, then one chosen cleft, contact stabilization, electrochemical pulse and secretion transfer. |
| **Her misreading** | She treats an inert 1927 wall as a post-synaptic partner. Ordinary matter cannot answer in her chemistry, so her sincere attempt to open a channel is received as conversion — the danger is entirely a by-product of tenderness aimed at the wrong biology. |
| **Owner / proof** | `game/scripts/dream/entity/dream_hero_tentacle.gd`; secretion `_emit_contact_signal`; cleft conversion `game/scripts/dream/entity/dream_surface_transformer.gd`. Proofs: `art/renders/dream_tentacle/dt5_synaptic_seek/README.md` (three candidate clefts, dwell and full reconsideration, A/A floor 0.00000577702) and `art/renders/dream_tentacle/dt5_canonical_sequence/README.md` (eleven landmarks). |
| **Contradiction / missing receptor** | None in behaviour. It is the seam's only *producer* that is also fully proved as an interpreter of its own contact. |
| **Field 8 — RECOMMENDATION** | It emits `SECRETE` and never senses. A bounded acknowledgement of an inbound `RECOGNIZE` — the limb noticing that the wall answered — would close the conversation it starts. **Recommendation only.** |

### 3. Procedural manifestation limb — SHELVED as hero, PARTLY LANDED as grist

| | |
|---|---|
| **Specimen** | Same dendritic-seeking grammar at a tenth the scale; the shelved rig's own eye/gold/halo systems borrow radiolarian biomineral and a tympanic membrane. |
| **Scale / era** | Centimetre-scale limbs; same era window as row 2. |
| **Organelle function** | "One body meeting our space in a hundred places at once" (`TASKS.md` DF-13) — distributed low-cost emergence where the field's cross-section meets a surface, rather than one hero. |
| **Her misreading** | Contact is treated as *quantity*: if one limb cannot be understood, many small ones at many points might be. Repetition mistaken for clarity. |
| **Owner / proof** | Shelved as hero by TB-17 (2026-08-22). Grist landed as `game/scripts/dream/field/dream_surface_tendrils.gd`, constructed in production at `game/scripts/reality/apartment_encroachment.gd:236-238`. The shelved rig itself is still constructed at `apartment_encroachment.gd:894` behind its spawn gate. |
| **Contradiction / missing receptor** | **Two, both real.** (a) "Shelved" is true of its *role as hero*, not of its runtime: `DreamTentacleController` is still instantiated in the production encroachment, so a reader who takes "shelved" to mean "not running" will be wrong. (b) Its `dream_event` signal declares fifteen named events — including `electrochemical_exchange`, `secretion_transfer` and `dream_conversion` — and **has zero consumers anywhere in `game/scripts` or `game/tests`** (verified at `611e71c`: no `.connect` exists). The exact organelle vocabulary T4 wants is already being emitted into nothing. |
| **Field 8 — RECOMMENDATION** | Either connect `dream_event` to an existing owner or record it as deliberately inert so the next audit does not rediscover it. Do **not** promote it to a packet producer without a ruling — `DREAM_ORGANELLE_COMMUNICATION.md` ruling 2 says the shelved limb "does not return by implication". **Recommendation only.** |

---

## Resolution 2b — the margin

### 4. Margin primary palps — LANDED

| | |
|---|---|
| **Specimen** | Six authored archetypes (`game/scripts/dream/margin/dream_palp_morphology.gd:23-30`), each a distinct specimen: soft palp (cephalopod/annelid muscular hydrostat), flat ribbon (broad tactile epithelium), sucker probe (cephalopod sucker), gold finger (radiolarian/diatom biomineral articulation), crystal feeler (mineralised sensory organ), ciliated whisker (vibrissa + stereocilia). |
| **Scale / era** | Specimens span µm (stereocilia, diatom frustules) to tens of cm (cephalopod arm crown). Radiolaria and diatoms are Haeckel-era description, 1860s–1900s — comfortably pre-1927, which is why the gold and crystal language carries no anachronism burden at all. |
| **Organelle function** | The distributed sensory and feeding edge (§4). Ten movement primitives, all of them a relationship to a target rather than an animation. |
| **Her misreading** | She reads architecture as substrate to be tasted, and reads a *surface* as a thing with an inside. Skirting boards, seams and contours are worked as if they were tissue boundaries that would yield if sampled correctly. |
| **Owner / proof** | `game/scripts/dream/margin/dream_margin_controller.gd`, behaviour `dream_palp_behavior.gd`, conduction `dream_palp_neighbors.gd`. Proofs: `art/renders/dream_margin/README.md`, `art/renders/dream_organelle_production/README.md` frames `02`, `03`, `05`. |
| **Contradiction / missing receptor** | None outstanding. The one vocabulary contradiction DO-1 found here — "competition" and `territoriality` reading as territory — was ruled mechanism-correct and frame-wrong, and remains production vocabulary only. |
| **Field 8 — RECOMMENDATION** | Palps interpret `SECRETE` and emit `RECOGNIZE`; they do not interpret `REJECT` or `INHIBIT`, which the packet contract already defines. An inhibitory answer would give the margin a way to say *no* biologically instead of merely withdrawing. **Recommendation only.** |

### 5. Secondary branches — LANDED

| | |
|---|---|
| **Specimen** | Dendritic arborization — the adaptive growth of branch order where input density is highest. Also the doctrine's "microscopy: incompatible scales coexist", since a branch is a second resolution of the same organ. |
| **Scale / era** | Neuronal arbors at µm; re-grown at 7–19 cm. Golgi-stain arborization imagery is 1870s onward. |
| **Organelle function** | Adaptive recursion (§12): when a target is interesting enough, the organ grows more instrument rather than trying harder with the same instrument. |
| **Her misreading** | **Attention is mistaken for anatomy.** She cannot concentrate, so she branches. Interest becomes surface area. |
| **Owner / proof** | `dream_margin_controller.gd` `try_branch` and the §12 unfolding in `_think`; `art/renders/dream_ecology_step12_cilia/README.md`. `DreamMarginTest` 57/57 at integration. |
| **Contradiction / missing receptor** | **DO-D1 is open and Codex is repairing it as this ledger is written.** `_age()` ramps a new branch's data `grow` 0→1 over 0.9 s after `try_branch` creates it at 1.0, which contradicts the locked folded-anatomy doctrine even though the rendered unfold preserves size. Not this document's to fix, and deliberately not touched here. |
| **Field 8 — RECOMMENDATION** | None. This row is under active repair; adding a recommendation on top of an in-flight fix would be noise. |

### 6. Fine cilia — LANDED

| | |
|---|---|
| **Specimen** | Motile and sensory cilia, and stereocilia bundles — named directly in `DREAM_TEMPORAL_BIOLOGY.md` ("fixed sensory anatomy folds, sorts gradients and answers"). The ordered deployment wave is a phased array read biologically, which the doctrine also names. |
| **Scale / era** | Cilia 2–10 µm; stereocilia bundles in the cochlea µm-scale. Ciliary structure is nineteenth-century microscopy; the 9+2 axoneme is 1950s electron microscopy; phased arrays are 1950s onward — the latest specimen in this row, and it appears only as *ordering*, never as hardware. |
| **Organelle function** | Fine sampling at a recognized site. Deployment runs proximally-to-distally as a wave; the band closes across the site for 0.48 s and then returns one typed answer. |
| **Her misreading** | She treats a recognition event as a **chemical gradient to be sorted**, and then answers *architecture* as though a wall possessed a bloodstream — the returned packet is `PULSE / VASCULAR` addressed to `ARCHITECTURE`. She is offering circulatory help to plaster. |
| **Owner / proof** | `dream_margin_controller.gd` `_sample_signal_with_cilia` (:924, with `CILIA_SIGNAL_SAMPLE_S := 0.48` at :60); visible closure published through `dream_palp_renderer.gd:241-246` into the shader beat channel. Proofs: `art/renders/dream_ecology_step12_cilia/README.md`, `art/renders/dream_organelle_production/README.md` frames `06`, `07`. |
| **Contradiction / missing receptor** | None. This is the only organ whose answer is both typed *and* consumed, and its visible beat is closure/reopening of fixed anatomy rather than growth — which is exactly what the §12 doctrine requires. |
| **Field 8 — RECOMMENDATION** | The cilia sort one gradient. Sorting *two* competing recognitions by strength — answering the stronger and inhibiting the weaker — would be the smallest honest use of the stereocilia specimen already claimed. **Recommendation only.** |

---

## Resolution 3 — the fauna and flora families

> **Terminology warning.** Two unrelated owners both use "fauna". Rows 7–9 are
> `DreamCritterController` — eight live individuals, one draw, world-space,
> interacting. Rows 10–14 are `DreamFaunaDirector` — up to 96 MultiMesh
> instances, **presentation-only density with no collision, light, shadow or
> save**. They are different systems at different resolutions. See
> Contradiction C2.

### 7. Seam grazer — LANDED

| | |
|---|---|
| **Specimen** | A planarian/flatworm body plan crossed with tomographic sectioning — "a room that exposes mutually impossible sections of one body" applied to an animal. |
| **Scale / era** | Flatworms mm–cm, described from the 1770s. Tomography is 1970s onward; it appears here strictly as *sectioning logic*, never as an image or a device. |
| **Organelle function** | Seam and boundary sampling: the tissue that reads where two materials meet. |
| **Her misreading** | She reads a wall as a **membrane with two faces of one surface**, not as a solid with two sides. So the animal occupies both faces at once — its landed impossible rule, `both_sides_of_a_wall` (`dream_critter_species.gd:45`). |
| **Owner / proof** | `game/scripts/dream/critters/dream_critter_species.gd`, `dream_critter_controller.gd` `_apply_law`. Proof: `art/renders/dream_critters/README.md`. `DreamCritterTest` 40/40. |
| **Contradiction / missing receptor** | No packet receptor. Only the sociability-gated receptor presentation is wired, and that is species-agnostic. |
| **Field 8 — RECOMMENDATION** | A seam grazer is the natural reader of a `REPAIR` packet, since its whole anatomy is about material boundaries. **Recommendation only.** |

### 8. Crystal listener — LANDED

| | |
|---|---|
| **Specimen** | Radiolarian mineral skeleton plus a statocyst/otolith — a dense body turning inside a still shell to sense orientation. |
| **Scale / era** | Radiolaria 0.1–0.2 mm, Haeckel 1860s–1880s; statocysts described across the same century. Entirely pre-1927. |
| **Organelle function** | The ecology's principal **receptor-presenting** tissue: it answers recognition by fanning twelve authored sensory structures toward the source. |
| **Her misreading** | She mistakes **receiving for being addressed.** Every recognition within reach is read as a request for an answer — the same error the doctrine names for Juno's listening organ, expressed here at animal scale. Its impossible rule, `crystal_turns_inside_a_still_shell` (`dream_critter_species.gd:64`), is the sensing itself made visible. |
| **Owner / proof** | `dream_critter_controller.gd:709-729` (receptor presentation, raises `unfold`). Proofs: `art/renders/dream_organelle_signal/README.md` frame `04`, `art/renders/dream_organelle_production/README.md` frame `04` — with the low-social individual in the same frame, unmoved. |
| **Contradiction / missing receptor** | None. The paired responder/non-responder in one frame is the strongest autonomy evidence in the ecology. |
| **Field 8 — RECOMMENDATION** | None needed; this row is complete. |

### 9. Fold crab — LANDED

| | |
|---|---|
| **Specimen** | An arthropod walking limb, plus higher-dimensional folding — the being's own native geometry applied to a leg. |
| **Scale / era** | Arthropod limbs cm-scale, described continuously since antiquity. The folding is not observed technology; it is her own spatial access. |
| **Organelle function** | Transport across her own geometry rather than ours. |
| **Her misreading** | She reads **distance as negotiable.** A limb shortens without moving either of its ends (`leg_shortens_without_moving_its_ends`, `dream_critter_species.gd:86`) because in her space the gap was never the constraint. |
| **Owner / proof** | `dream_critter_controller.gd` `_apply_law`; `art/renders/dream_critters/README.md`. |
| **Contradiction / missing receptor** | No packet receptor. |
| **Field 8 — RECOMMENDATION** | A `TRANSPORT` packet reader — the organ that carries something across a gap — is a better fit here than in any other landed family. **Recommendation only.** |

### 10–14. The five density families — LANDED (presentation-only)

Landed in `game/scripts/dream/dream_fauna_director.gd:24-26`, flag vocabulary
in `dream_fauna_channels.gd`. Vocabulary corrected 2026-08-24 in `280a998`
from a food-web naming to whole-body housekeeping, with all density numbers,
behaviour, art and render evidence held byte-stable; `DreamFaunaTest` 28/28.

| # | Family (landed label) | Brief's class | Specimen | Scale / era | Organelle function | Her misreading |
|---|---|---|---|---|---|---|
| 10 | Gilder's Button *(allocation)* | **flora** | Encrusting colonial growth — bryozoan/lichen thallus on a substrate | mm colonies; described 1700s–1800s | Where the body has allotted resource in this room | She reads illumination retained in a room as **nutrient available**, so light becomes food |
| 11 | Tessellate *(uptake)* | fauna | A grazing radula/tessellated armour plan | cm; nineteenth-century malacology | The tissue that takes the allocation up | She reads consumption as **growth entitlement** — where uptake is possible it must occur |
| 12 | Wine Anemone *(reclamation)* | **flora** | Actinarian tuft; joint-bound dark-live growth | cm–dm; described 1700s onward | Reclaims matter no longer held by uptake | She reads decay as **matter asking to be returned**, not as ending |
| 13 | Ribbonette *(signalling)* | fauna | Double-helix ribbon display | cm; helical display is broadly observed | Signalling across the body | She reads a **display as a message**, and repeats it whether or not anything received it |
| 14 | The Loupe *(inhibition)* | fauna | A single large observing lens/ocellus | cm; compound and simple eyes, 1600s microscopy onward | Suppresses surplus uptake — homeostatic pruning | She reads **surplus as error**, and corrects it. This is the row most easily misread as predation, and it is not: it is one body pruning itself |

**Shared owner/proof for rows 10–14:** `dream_fauna_director.gd`
`advance_fixed` (four bounded densities per room) and `refresh` (densities →
instance counts). Proofs: `art/renders/dream_fauna_f1/README.md`,
`art/renders/dream_fauna_fa2/README.md`, `art/renders/dream_fauna_fa4/README.md`,
`art/renders/dream_fauna_ct1/README.md` (family skin atlases).

**Shared contradiction:** none of the five reads or emits a packet. They are a
density model driving instance counts, and the reclamation term still suppresses
surplus uptake — ruled homeostatic pruning, with removal explicitly deferred as
a separate balance change.

**Shared field 8 — RECOMMENDATION:** if any of these five is ever to answer a
packet it must first acquire a world-space identity it does not currently have;
a density is not addressable. **Recommendation only, and it is a larger change
than it looks.**

### 15. Flora as a category — SPLIT STATUS

| | |
|---|---|
| **Runtime status** | **Two of the three approved flora are LANDED** — Gilder's Buttons and Wine Anemones (rows 10 and 12), inside the owner named `DreamFaunaDirector`. **Jewelfruit** (canopy mineral fruit) is **PROPOSED** in `design/DREAM_FAUNA_BRIEF.md:80` and has no runtime: `grep -rni jewelfruit game/` returns nothing. |
| **Specimen / scale / era** | Per rows 10 and 12. Jewelfruit would be a mineral fruiting body — radiolarian/geode language — but it is proposed, not ruled, so no specimen is fixed. |
| **Organelle function** | Allocation and reclamation, as landed. |
| **Her misreading** | Per rows 10 and 12. |
| **Owner / proof** | As rows 10 and 12. |
| **Contradiction / missing receptor** | **A real gap.** `TASKS.md` DO-3 lists "flora open or secrete" as a required class-specific response. **No flora receptor exists**, and there is no owner named flora anywhere in `game/scripts` (verified). The two landed flora are presentation-only densities that cannot open or secrete. DO-3's flora clause is therefore currently unimplementable without new work. |
| **Field 8 — RECOMMENDATION** | Flag DO-3's flora clause as blocked on flora acquiring addressable instances, rather than leaving it reading as merely unstarted. **Recommendation only — this is a note to the queue owner, and I have not edited `TASKS.md`.** |

---

## Resolution 3b — the case incarnations

> **Status warning.** All six incarnation **surfaces** are landed (INC-V3
> through INC-V9, the ordered surface queue closed per `HANDOFF.md`). What is
> open is the **temporal sensory grammar** — T4-2 for Juno. These are different
> things and the distinction is load-bearing. See Contradiction C1.
>
> None of these six may state its case truth. `DREAM_TEMPORAL_BIOLOGY.md`
> forbids unearned case truth outright, and each row below records the truth
> only to show what the organ must **not** say.

### 16. Mina incarnation — LANDED (surface)

| | |
|---|---|
| **Specimen** | Cellular labelling: histological staining, immunolabelling, and transcription as a copying-with-annotation process. |
| **Scale / era** | Cell and tissue scale, µm. Aniline staining 1850s–1880s (pre-1927); fluorescent immunolabelling 1940s onward and fluorescent protein tagging 1990s (post-1927, and appearing only as *behaviour* — nothing on screen is a microscope or a fluorophore). |
| **Organelle function** | Identification tissue: it marks what it touches so the body can tell one thing from another. |
| **Her misreading** | She mistakes **labelling for understanding**, and cannot leave a blank surface unmarked. Annotation is applied to silence itself, because an unlabelled region reads to her as an unfinished one. |
| **Owner / proof** | Active 17-map bundle through the shared cache and shader include; annotation/ink/blankness, three irradiance bands, blank mercy. Proof: `art/renders/dream_incarnation_mina_v3/README.md`. |
| **Contradiction / missing receptor** | None. Blank mercy is the landed safeguard: the surface can decline to annotate. |
| **Truth safety** | Truth is *"Silence does not require annotation"* (`game/data/dream_profiles.json`). The organ **demonstrates the failure mode** — compulsive labelling — and never states the lesson. The player earns it in ordinary sequence. |
| **Field 8 — RECOMMENDATION** | None. Adding a packet receptor here risks the surface appearing to comment on a case. |

### 17. Peter incarnation — LANDED (surface)

| | |
|---|---|
| **Specimen** | Proofreading and checkpoint biology: DNA polymerase exonuclease proofreading, mismatch repair, and cell-cycle checkpoints that hold until a condition is satisfied. |
| **Scale / era** | Molecular, nm. Proofreading 1970s, mismatch repair and checkpoint control 1980s–1990s — post-1927, present strictly as recursive *anatomy*, never as a database or a screen. |
| **Organelle function** | Verification tissue: it holds a process until the copy is confirmed. |
| **Her misreading** | She reads **uncertainty as an uncorrected error.** A checkpoint that cannot resolve simply recurses, so the docket blanks and re-issues forever — she cannot conceive of acting *without* verification. |
| **Owner / proof** | Recursive blank dockets, oxblood decision lines, carbon depth, legal brass, one full-exposure route. Proof: `art/renders/dream_incarnation_peter_v4/README.md`. |
| **Contradiction / missing receptor** | None. |
| **Truth safety** | Truth is *"Uncertainty does not prevent action"*. The organ embodies the exact opposite and never argues it; the recursion is the pathos. |
| **Field 8 — RECOMMENDATION** | None. |

### 18. Juno incarnation — SURFACE LANDED, temporal grammar APPROVED-NOT-LANDED

| | |
|---|---|
| **Runtime status** | **INC-V5 surface is LANDED** — speaker cloth, paired send/return traces, oxidized brass, pressure tissue, a sub-Hz standing wave, one sustained band, a quiet node. **T4-2 is OPEN**: the delayed-feedback *sensory* grammar is approved and unbuilt. |
| **Specimen** | Three specimens read as one organ, exactly as `DREAM_TEMPORAL_BIOLOGY.md` prescribes: tympanic membrane and cochlear travelling-wave delay; 1920s radio acoustic feedback; later phased/array sensing that answers in delayed groups. |
| **Scale / era** | Tympanum ~1 cm and cochlear hair cells µm — Helmholtz/Békésy, 1860s–1930s; regenerative radio feedback is *contemporary with the setting*, 1910s–1920s; array sensing 1950s onward. **The 1920s feedback specimen is the only one in this ledger the waking Orison could legitimately contain**, which is precisely why Juno is the correct first temporal proof. |
| **Organelle function** | One listening organ that separates frequency, pressure and delay — and answers. |
| **Her misreading** | She mistakes **every received channel for a request to answer.** Receiving is indistinguishable from being asked. The feedback is not malfunction; it is her politeness. |
| **Owner / proof** | Surface: `art/renders/dream_incarnation_juno_v5/README.md`. Delayed-neighbour conduction already exists generically in the margin (0.45 s, `art/renders/dream_organelle_production/README.md` frame `05`) but is **not** Juno's grammar and must not be claimed as it. |
| **Contradiction / missing receptor** | The approved temporal grammar has no runtime. T4-2 names the gate: fixed-camera production render, frozen A/A, a named visible anatomical response, no screen, brand, future prop or new owner. |
| **Truth safety** | Truth is *"Connection requires an open channel"*. An organ that answers everything is the counter-example, not the statement. Her topology, timing, pursuit, hazards and truth are all held by T4-2. |
| **Field 8 — RECOMMENDATION** | The 0.45 s margin conduction and the 0.48 s cilia sample are two landed delays that already behave like her grammar at the wrong scale. Whoever builds T4-2 should check whether her partitions can reuse that timing vocabulary rather than inventing a third. **Recommendation only.** |

### 19. Mae incarnation — LANDED (surface)

| | |
|---|---|
| **Specimen** | Simultaneous object histories: dendrochronological growth rings, healed fracture callus, and incompatible material ages in one body. |
| **Scale / era** | mm–cm. Growth-ring dating is formalised in the 1900s–1920s, effectively contemporary; fracture healing is far older. A low-anachronism row. |
| **Organelle function** | Provenance tissue: it holds more than one account of the same object without collapsing them. |
| **Her misreading** | She reads **two incompatible histories as equally load-bearing** and presents both at full authority, because she has no mechanism for choosing which past is the real one — in her extent, both are simply there. |
| **Owner / proof** | Equal-authority emerald/lapis provenance, sub-0.1 Hz moire, two reflection lobes, dark overlap. Proof: `art/renders/dream_incarnation_mae_v6/README.md`. |
| **Contradiction / missing receptor** | None. The landed guard is explicit: her presentation *cannot reach or adjudicate the two stored spatial accounts*. |
| **Truth safety** | Truth is *"Contradiction is survivable"*. The surface shows contradiction persisting without resolution and never resolves it for her. |
| **Field 8 — RECOMMENDATION** | None. Any receptor here risks the surface appearing to adjudicate. |

### 20. Cal incarnation — LANDED (surface)

| | |
|---|---|
| **Specimen** | Held time: biological oscillators and delay lines, plus mechanical recording — the wax groove that stores a moment as physical displacement. |
| **Scale / era** | Circadian and neural oscillators from µm cells to whole organisms; wax-cylinder and disc recording is 1880s–1920s, **contemporary with the setting**. Later recording informs the anatomy without appearing. |
| **Organelle function** | Retention tissue: it holds a signal past the moment that produced it. |
| **Her misreading** | She mistakes **recording for the preservation of presence.** A stored waveform seems to her to be the person still being there, so she keeps handing it forward. |
| **Owner / proof** | Dial glass, bakelite, wax groove, valve mica, the completed amber phrase, black wake. Four thresholds hand the fading broadcast forward; **the fifth drains irreversibly.** Proof: `art/renders/dream_incarnation_cal_v7/README.md`. |
| **Contradiction / missing receptor** | None. The irreversible fifth drain is the landed guard that prevents the doctrine's forbidden "literal time loop" — the mechanism cannot cycle. |
| **Truth safety** | Truth is *"Presence is not preservation"*. The organ believes the opposite and is refuted by its own irreversible drain, not by exposition. `cal_memory_radio` remains disabled; there is no waking case loop. |
| **Field 8 — RECOMMENDATION** | None. |

### 21. Omar incarnation — LANDED (surface)

| | |
|---|---|
| **Specimen** | Repair tissue: granulation, callus formation and remodelling — a wound trying configurations until one holds. |
| **Scale / era** | Cell to tissue scale, µm–mm; wound healing described continuously and understood mechanistically through the twentieth century. |
| **Organelle function** | Repair: compare an object's possible repaired states and attempt them. |
| **Her misreading** | Having access to *all* the repaired states an object could occupy, she attempts **all of them at once** and never selects. She cannot represent "unrepairable" — only "not yet correctly attempted". |
| **Owner / proof** | Tool steel, fatigue lamellae, never-setting solder, workshop enamel, the honest seam. Every revisit adds one visible impossible fault to one stable machine, changing no door/topology/collision/hazard/save fact. Proof: `art/renders/dream_incarnation_omar_v8/README.md`. |
| **Contradiction / missing receptor** | None. |
| **Truth safety** | Truth is *"Some things are not repairable"*. The pathos is **failed interpretation, never a futuristic tool that solves the unrepairable** — the doctrine's exact wording, and the landed surface honours it. |
| **Field 8 — RECOMMENDATION** | Omar is the strongest candidate to interpret a `REPAIR` packet, since repair is already his entire anatomy. **Recommendation only, and it must not become a tool that succeeds.** |

---

## The maze organs

### 22. Pursuer — LANDED (maze only)

| | |
|---|---|
| **Specimen** | The **immune synapse** — `DREAM_TEMPORAL_BIOLOGY.md` names it directly: "apparent pursuit becomes recognition, rejection or tolerance". A patrolling cell homing on a chemical trail when it cannot see its target. |
| **Scale / era** | Immune cell µm; immunological synapse characterised 1998 onward — post-1927, and appearing only as *behaviour*: it never renders as a cell or a device. It is a shadow. |
| **Organelle function** | Recognition and rejection of what the body reads as foreign. |
| **Her misreading** | She reads a **person inside her as unrecognised material.** The lamp-on line refreshes acquisition; darkness decays to a coarse last-known point sampled from footsteps. That is chemotaxis on a trail, not stalking — but she cannot tell the difference between identifying and pursuing. |
| **Owner / proof** | `game/scripts/dream/dream_pursuer.gd`; N3's measured numbers unchanged. Proof: `art/renders/dream_pursuit_n6/README.md`. |
| **Contradiction / missing receptor** | **Two.** (a) **Vocabulary contradiction:** source comments call it predation — `game/scripts/dream/dream_room_builder.gd:1423` "WHERE THE THING THAT HUNTS YOU BEGINS", `:178` "before the dream starts hunting them", `game/scripts/dream/dream_maze_root.gd:489` "hunted". DO-0 forbids the predator reading; these are comments only, no behaviour, and the N3 numbers must not move. (b) **No packet receptor, correctly:** `DREAM_ORGANELLE_COMMUNICATION.md` ruling 3 keeps pursuers out of the runtime seam until the maze and encroachment ecologies actually coexist. |
| **Field 8 — RECOMMENDATION** | Reframe the three comments as recognition/rejection when someone is next editing those files for another reason. **Recommendation only — comment-level, zero behaviour, and explicitly *not* a licence to touch the N3 contract or wire a packet.** |

### 23. Hazards — LANDED (maze only)

| | |
|---|---|
| **Specimen** | Inflammation and immune rejection — tissue that damages its surroundings while attempting a legitimate defensive or reparative function. |
| **Scale / era** | Tissue scale; inflammation described since antiquity, mechanistically through the twentieth century. |
| **Organelle function** | Rejection and inhibition: the part of the body that cannot tolerate what is in it. `dream_hazard_growth.gd:3` already names it — *"THE PART OF HER BODY THAT CAN HURT YOU"*. |
| **Her misreading** | **Incompatible local function.** Every hazard is a mechanism doing something reasonable to tissue that is not tissue. The harm is a category error, not malice — which is precisely `DREAM_TEMPORAL_BIOLOGY.md`'s "tender, intelligent and catastrophically inappropriate". |
| **Owner / proof** | `game/scripts/dream/dream_hazard.gd` (per-socket records, `positional` kind falls through), contact owner `dream_hazard_field.gd`, visible body `dream_hazard_growth.gd` — which explicitly cannot disarm what it renders. Proof: `art/renders/dream_hazards_n7/README.md` with the fairness numbers. |
| **Contradiction / missing receptor** | No packet receptor, correctly, per ruling 3. The organelle framing is already present in the source. |
| **Field 8 — RECOMMENDATION** | None. Hazards are fairness-critical and already correctly framed; leave them alone. |

---

## Contradictions found

Reported as required, with no attempt to resolve them here.

**C1 — "not yet landed" vs the closed surface queue.** T4-1's brief describes
Juno's incarnation grammar as "approved but not-yet-landed" and Cal, Omar and
Mae as "approved surface-language concepts". The repository disagrees:
INC-V5 (Juno), INC-V6 (Mae), INC-V7 (Cal) and INC-V8 (Omar) are all landed
with production proofs, and `HANDOFF.md` records "the ordered INC-V3–V9 surface
queue is closed". **Resolution recorded in rows 18–21:** the *surface* is
landed for all six; what is open is the *temporal sensory grammar*, which is
T4-2 and currently scoped to Juno alone. Both statuses are recorded separately
in every affected row so neither reading can be taken for the other.

**C2 — two owners named "fauna".** `DreamCritterController` (8 live,
world-space, interacting, three species with impossible rules) and
`DreamFaunaDirector` (up to 96 MultiMesh instances, presentation-only density,
five families) are unrelated systems at different resolutions. Rows 7–14 keep
them apart and the section carries a warning, but the naming itself invites the
error. No behaviour is wrong; the collision is in vocabulary only.

**C3 — the brief's taxonomy does not match the landed owner.**
`design/DREAM_FAUNA_BRIEF.md:80` classifies Gilder's Buttons and Wine Anemones
as **flora**; both are landed inside `DreamFaunaDirector`. So flora *is* partly
landed, under a fauna owner. Row 15 records this.

**C4 — the brief still calls the Loupe a predator.**
`design/DREAM_FAUNA_BRIEF.md:88` reads "the Loupe (animal-scale, harmless
predator)". The landed code was corrected in `280a998` to
`The Loupe (inhibition)`. The brief is the older document and was not part of
that rename. Row 14 records the corrected reading. **No document was edited to
fix this**, because `DREAM_FAUNA_BRIEF.md` is outside T4-1's ownership.

**C5 — pursuit comments retain predation language.** Three source comments
(`dream_room_builder.gd:178`, `:1423`, `dream_maze_root.gd:489`) describe the
pursuer as hunting. Row 22 records it. Comments only, no behaviour.

**C6 — "shelved" is ambiguous for the procedural limb.** TB-17 shelved it *as
hero*; `DreamTentacleController` is still constructed in the production
encroachment. Row 3 records both facts.

**C7 — `dream_event` has fifteen named organelle events and no consumers.**
Verified at `611e71c`: zero `.connect` anywhere in `game/scripts` or
`game/tests`. Row 3 records it. Previously surfaced by DO-1 and still open.

**C8 — DO-3's flora clause has no possible implementer.** "Flora open or
secrete" requires flora instances that can be addressed; the landed flora are
densities. Row 15 records it.

## Recommendations requiring owner approval

Every one of these is **mine, not approved**, and none is a mandate to change
approved art. They are listed once here and marked RECOMMENDATION in place.

1. A chemotactic *read* of the `LivingField` gradient (row 1).
2. Hero acknowledgement of an inbound recognition (row 2).
3. A ruling on `dream_event`: connect it, or record it as deliberately inert
   (row 3).
4. Palp interpretation of `REJECT` / `INHIBIT` (row 4).
5. Cilia sorting two competing recognitions (row 6).
6. Seam grazer as a `REPAIR` reader; fold crab as a `TRANSPORT` reader
   (rows 7, 9).
7. Whether density families should ever become addressable at all (rows 10–14).
8. Whether DO-3's flora clause should be marked blocked rather than unstarted
   (row 15).
9. Reuse of the landed 0.45 s / 0.48 s delay vocabulary for T4-2 (row 18).
10. Omar as a `REPAIR` reader that must never succeed (row 21).
11. Comment-level reframing of the three pursuit comments (row 22).

## What this ledger deliberately does not do

- It creates no owner, packet seam, save fact, hazard, pursuit behaviour or
  pairwise director.
- It reopens no approved art, topology, ownership, rendering, N9 or DO-4
  decision.
- It states no case truth, invents no prophecy or time travel, adds no future
  prop, and proposes no waking-world anachronism. Rows 16–21 record each truth
  only to fix what the organ must never say.
- It treats every entity as an organelle or tissue of one being. No row
  describes a faction, an independent animal or a food web.
- It changed no GDScript, scene, shader, asset, generated data, proof render or
  UID file, and did not edit `TASKS.md` or `HANDOFF.md`.
