# Orison v2 M11B F02/F04 service-openings checkpoint — 2026-08-30

Evidence class: **TECHNICAL CHECKPOINT — FOCUSED PROOF PASS — HUMAN REVIEW PENDING**

## Accepted predecessor and branch boundary

The owner reviewed the M11A-A packet at
**art/renders/orison_v2/m11aa_first_exterior_cell_readability_01/** from
**c8c52aab3a4ed8822c9da81cd28f377bbe107fd8** and returned **HUMAN
ACCEPTED**. Without route-guide visuals, that packet communicates Orison, the
pavement route, the bodega threshold, the interior/deliveries continuation,
and the return toward Orison. The slight frame-1 sign crop remains accepted
non-blocking visual debt.

That verdict was recorded inertly in
**design/ORISON_V2_M11A_A_HUMAN_ACCEPTANCE_RECEIPT_2026-08-30.md** and the
M11A-A checkpoint, then committed as
**0429c07078f746d020d9bdad8c3cb72ba6fc452a** before this branch was created.
It accepts only M11A-A exterior-cell readability. It does not accept the M11B
service openings and does not authorize M09, selector cutover, v1 retirement,
production-layout replacement, or a merge to main.

## Pre-edit ledger declaration

This section was recorded on branch
**codex/orison-v2-m11b-service-openings** at
**0429c07078f746d020d9bdad8c3cb72ba6fc452a**, before any M11B schema,
collision, traversal, lighting, test, or evidence edit.

The baseline completeness audit reports 150 requirements:
**ABSENT 50, HUMAN_ACCEPTED 1, PROGRAMMED 44, RUNTIME_PROVEN 34,
SHELL_ONLY 3, SPATIALLY_PROVEN 18**. The six blocker scopes are
**0 / 1 / 86 / 45 / 101 / 103**.

The pre-edit model and detector disagree in an important, now-recorded way:

- **F02_SERVICE_HALL** is already space-level **PROGRAMMED** because the
  existing crossing-to-hall opening counts as any entrance. That status does
  not prove the missing hall-to-core edge.
- **F04_SERVICE_HALL** is space-level **SHELL_ONLY** because it has no door or
  cased opening at all.
- **circ.F02.service_route** is incorrectly satisfied by
  **F02_SERVICE_CROSSING**, and **circ.F04.service_route** is incorrectly
  satisfied by **F04_SERVICE_CORE**. The current keyword/best-space detector
  does not encode the actual service-circulation obligation.
- **circ.F03.service_route** is likewise incorrectly satisfied by the bare
  **F03_SERVICE_CORE** even though F03 has no lateral service hall. M11B will
  expose, not repair, that separate missing-space debt.

With the pre-edit detector unchanged, adding only the two opening records
would move just **floor.F04: SHELL_ONLY → PROGRAMMED**, changing the summary to
**PROGRAMMED 45 / SHELL_ONLY 2**. The six blocker counts would remain exactly
**0 / 1 / 86 / 45 / 101 / 103**, because PROGRAMMED is still below the
SPATIALLY_PROVEN proof required by the floor row.

M11B will first narrow the service-route detector, with synthetic fixture
tests, so the requirement means an actual lateral service hall connected
directly to that floor's service core. Against the unmodified pre-edit layout,
that corrected detector is expected to expose:

- **circ.F02.service_route: PROGRAMMED → SHELL_ONLY**;
- **circ.F04.service_route: PROGRAMMED → SHELL_ONLY**;
- **circ.F03.service_route: PROGRAMMED → ABSENT** as newly visible,
  non-M11B missing-space debt.

After the two authored M11B openings, the intended direct movements are
**circ.F02.service_route: SHELL_ONLY → PROGRAMMED** and
**circ.F04.service_route: SHELL_ONLY → PROGRAMMED**. The derived
**floor.F04** row should also move **SHELL_ONLY → PROGRAMMED**;
**floor.F02** remains PROGRAMMED. The deliberate open-shell requirements
**circ.F02.public_landing** and **circ.F04.public_landing** remain SHELL_ONLY.
The truthful expected final summary under the corrected detector is therefore
**ABSENT 51, HUMAN_ACCEPTED 1, PROGRAMMED 44, RUNTIME_PROVEN 34, SHELL_ONLY 2,
SPATIALLY_PROVEN 18**, with all six blocker counts unchanged. Any different
result will be reported rather than baselined.

No checkpoint wording may promote either opening beyond what source geometry,
collision, bidirectional PlayerController traversal, and the four-frame packet
actually prove.

## Independently derived shared-wall authority

The two openings happen to resolve to the same plan values, but each result was
derived independently from that floor's endpoint records. Neither floor copied
the other floor's coordinates as authority.

### F02

- **F02_SERVICE_HALL** is a service space with plan rectangle
  **[8.3, -2.65, 9.5, 9.25]**.
- **F02_SERVICE_CORE** is a core space with plan rectangle
  **[9.5, 0.3, 13.2, 10.2]**.
- Their positive-length shared boundary is the **x = 9.5** plane from
  **z = 0.3** through **z = 9.25**.
- **F02_SERVICE_HALL_CORE_OPENING** is centered at **[9.5, 3.2]**. Its
  **1.2 m** width occupies **z = 2.6–3.8**, wholly inside that boundary, and
  its head is **2.4 m** above the finished floor.

### F04

- **F04_SERVICE_HALL** is a service space with plan rectangle
  **[8.3, -9.25, 9.5, 9.25]**.
- **F04_SERVICE_CORE** is a core space with plan rectangle
  **[9.5, 0.3, 13.2, 10.2]**.
- Their independently computed positive-length shared boundary is again the
  **x = 9.5** plane from **z = 0.3** through **z = 9.25**.
- **F04_SERVICE_HALL_CORE_OPENING** is centered at **[9.5, 3.2]**. Its
  **1.2 m** width occupies **z = 2.6–3.8**, wholly inside that floor's
  boundary, and its head is **2.4 m** above the finished floor.

The production capsule is **0.66 m** in diameter and **1.524 m** high. Each
opening therefore provides **0.54 m** of aggregate width margin and **0.876
m** of head margin. Each route rectangle is **[8.9, 2.6, 10.1, 3.8]**. The
focused proof independently checks the lift landing, live risers and shafts,
stair starts, flights, void and half landing, service return, door swings, and
required clearance envelopes on both floors. The closest declared hazards
remain outside the aperture: the service-lift shaft ends at **z = 1.6**, the
continuous risers end no farther north than **z = 1.15**, and the service stair
begins at **z = 5.0**. The opening interval therefore retains respectively
**1.0 m**, **1.45 m**, and **1.2 m** of plan separation.

## Generic single-owner construction

The two new source records use one schema: two endpoint identities, a declared
level, center, axis, width, height, and **shared_wall_owner**. The builder has
no F02- or F04-specific construction branch.

Before geometry is built, the production reader now refuses a single-owner
opening unless:

- exactly two declared space endpoints exist on the declared level;
- those endpoint rectangles have one positive-length shared boundary;
- the opening axis and fixed coordinate match that boundary;
- the entire opening interval fits on the boundary;
- width and head height meet the maintenance minimum and do not exceed the
  storey;
- the named owner is one endpoint and actually authors that wall side;
- every opening on the same endpoint partition uses one stable owner;
- single-owner aperture intervals do not overlap; and
- no unrelated door, ordinary opening, or window cuts the partition that the
  owner contract controls.

The service core owns the physical shared wall on both floors. The owner's
wall builder creates two collision-bearing adjacent runs and one
collision-bearing head, cutting only the declared aperture. The hall shell
omits only its coincident shared interval, so it cannot duplicate that wall;
its wall beyond the shared interval remains. Floors and ceilings are built by
their existing independent paths and receive no opening subtraction.

Each record also produces one generic three-piece cased reveal. Its two jamb
pieces and head are explicitly non-colliding, so the casing improves the
leafless opening's read without becoming a second collision authority or
narrowing the capsule clearance.

The same generic record also mounts a source-owned, non-colliding bulkhead
practical above the opening: one backplate, one opal lens, and one restrained
warm light. It is part of the production blockout—not a capture-only light—and
gives the cased maintenance connection a stable architectural read on both
floors. F02 and F04 use the same construction path.

The guard suite includes focused refusals for an owner outside the endpoints,
an off-wall center, an aperture beyond the shared span, conflicting owners on
one partition, and an unrelated aperture on the omitted partition. A refusal
builds no partial blockout.

## Focused objective and piece-two proof

**OrisonV2M11BServiceOpeningsTest** passes **75/75 checks** with zero failures.
It loads the authoritative blockout source, derives each floor contract
independently, builds a fresh production blockout and production
**PlayerController**, inspects the resulting collision topology, traverses the
opening in both directions, and tears the fresh world down.

For each floor, the runtime proof establishes:

- both typed endpoint nodes exist;
- the core owns exactly three partition segments: two adjacent runs and one
  head, all collision-bearing;
- the hall owns zero segments on the shared overlap and retains one colliding
  wall run beyond it;
- three samples through the aperture prism are collision-free;
- both jamb sides and the head retain collision;
- both approaches retain floor support and no floor or ceiling subtraction is
  introduced;
- the live production capsule remains collision-enabled and grounded;
- the player starts once from the legitimate service-landing side, then uses
  production autopilot movement with no intermediate position assignment,
  noclip, or test-only collision removal;
- core/landing → opening → hall and hall → opening → core/landing each cross
  the expected aperture plane exactly once; and
- the world, blockout, and controller weak references release through normal
  scene teardown.

The complete traversal result is **4/4 directions PASS**:

1. **F02 public/service landing → core → F02 opening → service hall**;
2. **F02 service hall → F02 opening → core/landing**;
3. **F04 public/service landing → core → F04 opening → service hall**; and
4. **F04 service hall → F04 opening → core/landing**.

The F04 cycle is piece two, not a second implementation. Both records report
the same topology and construction cost: **2 adjacent collision segments, 1
colliding head, 3 non-colliding reveal pieces, 2 non-colliding practical
meshes, 1 practical light, 0 nonowner shared segments, 1 retained nonowner
run, 3 clear portal samples, and 2 floor-support samples**.
The second warmed cycle produces no ObjectDB, resource, or orphan
amplification, and final focused teardown returns to the warmed ownership
baseline.

## Immutable four-frame packet

The new packet is **art/renders/orison_v2/m11b_service_openings_02/**. It is a
single successful **1600×900 Forward+** run with exactly four nonzero PNGs:

1. [F02 core-side approach](../art/renders/orison_v2/m11b_service_openings_02/01_f02_core_side_approach.png) —
   SHA-256 **a4fd73b220ed8d7b5fa28b906c7088b3941a027806f5584ea4e1342e3dc19fc4**;
2. [F02 hall-side return](../art/renders/orison_v2/m11b_service_openings_02/02_f02_hall_side_return.png) —
   SHA-256 **dbf41652e486f98f48612d897ca793cf6196b69735d5c94f115bc85eeddeb937**;
3. [F04 core-side approach](../art/renders/orison_v2/m11b_service_openings_02/03_f04_core_side_approach.png) —
   SHA-256 **4d17c6ea7d67d5efe781f87bd20b206ce6ca7db983a640c8eef8dac8faa7e0fb**;
4. [F04 hall-side return](../art/renders/orison_v2/m11b_service_openings_02/04_f04_hall_side_return.png) —
   SHA-256 **36883da61769870da0777d4f93da387fb0d09b92bef0c41c2778e0b6f1212055**.

The packet uses the production blockout inside the established F02/F04 review
compositions. A real production **PlayerController** owns the active playable
camera at a **1.41 m** standing eye; the review-controller cameras are disabled
before tree entry. The capture adds no capture-only camera, geometry, or light;
the production PlayerController owns its ordinary camera and carried service
light, while the opening practical is source-owned blockout architecture.
Canvas layers, schema envelopes, landing cues, labels, arrows, and debug
overlays are hidden. Each floor receives one initial core-side placement;
subsequent frame positions come from collision-bearing PlayerController
movement through data-derived threshold waypoints with no station teleport.
Every frame records floor support, collision layer and mask **1**, no noclip,
no visible canvas layer, and no visible readability cue.

The exact saved-frame luminance samples record mean luma / fraction below 16
as **23.31 / 0.6144**, **30.56 / 0.6062**, **39.68 / 0.5099**, and **37.28 /
0.5814**. Every frame clears the source gate of mean at least **18/255** and
dark fraction at most **0.72** while retaining the service-core night contrast.

Both review compositions, blockouts, players, and cameras release after their
floor cycle. The packet receipt reports **35 → 35 nodes, 34 → 34 resources,
and 0 → 0 orphan nodes** across the complete capture. The general object
monitor warms from **1,643 to 1,660** objects, so this checkpoint does not use
that broad counter alone as retained-owner evidence; the matched M11A
capture-lifecycle regression and final retention sweep remain part of the
pending regression receipt below.

The images are technical evidence only. **M11B HUMAN REVIEW IS PENDING**. A
successful capture does not answer the human readability question.

## Corrected completeness result

The service-route detector now requires a capsule-sized direct edge between a
typed lateral service hall and that floor's typed service-lift/stair core. It
validates the endpoints' exact shared boundary, edge axis or cardinal door yaw,
fixed plane, full opening span, width, head height, and declared owner. An
axis-less opening cannot masquerade as a yaw-authored door. Route proof is
capped by the weakest evidence tier of hall, core, and exact edge, so endpoint
evidence cannot promote an unproved connection. A public crossing, geometryless
record, or bare vertical core can no longer satisfy the requirement. Synthetic
fixtures prove every refusal, the direct-edge transition, legitimate F01 door
yaw, exact spatial evidence-tier preservation, and bare-core-without-hall
refusal.

The live corrected ledger matches the pre-edit declaration exactly:

- **150 requirements**;
- **ABSENT 51**;
- **HUMAN_ACCEPTED 1**;
- **PROGRAMMED 44**;
- **RUNTIME_PROVEN 34**;
- **SHELL_ONLY 2**; and
- **SPATIALLY_PROVEN 18**.

The blocker scopes remain **0 / 1 / 86 / 45 / 101 / 103**.

The truthful row movement is:

- **circ.F02.service_route: SHELL_ONLY → PROGRAMMED**, now scoped to
  **F02_SERVICE_HALL**, **F02_SERVICE_CORE**, and
  **F02_SERVICE_HALL_CORE_OPENING**;
- **circ.F04.service_route: SHELL_ONLY → PROGRAMMED**, now scoped to
  **F04_SERVICE_HALL**, **F04_SERVICE_CORE**, and
  **F04_SERVICE_HALL_CORE_OPENING**;
- **floor.F04: SHELL_ONLY → PROGRAMMED**;
- **floor.F02** remains **PROGRAMMED**; and
- **circ.F02.public_landing** and **circ.F04.public_landing** remain
  **SHELL_ONLY** because their authored decision zones remain deliberate open
  shells.

The corrected detector also exposes **circ.F03.service_route: PROGRAMMED →
ABSENT**. F03 has a service core but no typed lateral service hall. This is a
newly visible pre-existing requirement, not an M11B regression, and M11B does
not construct or claim it.

## Scoped spatial limitation

These openings provide safe access from each service landing/core to the north
portion of its service hall. They do not repair or claim uninterrupted
south-to-north travel along the entire service spine. The existing
**HEAT_STACK**, **TELEPHONE_MESSAGE_RISER**, and
**ELECTRICAL_SERVICE_RISER** occupy the narrow southern F02/F04 hall reach
between approximately **z = 0.3** and **z = 1.15**. That longitudinal riser
choke is outside the new opening interval and does not obstruct either proved
core↔hall crossing, but resolving it would require the prohibited riser or
floor redesign. It remains explicit spatial debt rather than being hidden by a
teleport or an overbroad service-route claim.

M11B likewise does not create the absent F03 lateral hall, redesign either
stair or service lift, split floor 01, extend the building-wide generator, or
change apartment geometry.

## Selector and protected boundary

The current selector source still declares **BuildingRootSelector.DEFAULT_ID
= v1**. No M11B diff touches either production **building_layout.json**, the
selector module, **game/project.godot**, **orison_root.tscn**, or any production
floor GLTF/BIN. The pre-edit byte baseline records selector SHA-256
**d2b3db95d72e4a418c0e7184e6b3368da723a945192024a10ee937ea604c9802**
and both layout SHA-256 values as
**68838c933c0954092c63403f36ec7fb26d6c0956c01c23109465c680608b399d**.
All fourteen floor GLTF/BIN hashes were also captured before editing.

The final disk-byte comparison matches **17/17** protected paths to that
pre-edit baseline: both layouts, the selector, and every floor 01–06/B1
GLTF/BIN are unchanged. A named-path diff over the same set exits **0**. The
committed selector remains **v1**.

## Final regression and audit closure

The focused schema, refusal, objective, piece-two, capture, and corrected-ledger
proofs above pass. The serialized closure set reports:

- **OrisonV2BlockoutGuardTest:** exit **0**; every deliberate malformed-owner,
  off-wall, out-of-span, conflicting-owner, and competing-aperture fixture is
  refused, and no partial blockout survives a refusal;
- **OrisonV2BlockoutTest:** exit **0**; schema, construction, generic cased
  reveals, service continuity, and existing blockout invariants pass;
- **OrisonV2M11BServiceOpeningsTest:** **75/75 PASS**, exit **0**;
- four real PlayerController traversal directions: **4/4 PASS** with two
  grounded plane crossings per floor, collision enabled throughout, and no
  noclip or intermediate position assignment;
- immutable M11B capture: **4/4** exact **1600×900 Forward+** frames, engine
  exit **0**, hash mismatches **0**, orphan delta **0**;
- **OrisonV2M08ESpatialTest:** exit **0**; all six owners and the complete
  collision-bearing maintenance route pass;
- **OrisonV2IntegratedTest** (M08A): exit **0**; all ten integrated gates,
  continuous street-to-bedside traversal, byte stability, and
  adapter/acoustic restoration pass without a shutdown warning;
- **orison_v2_m08f_runtime_test:** **29/29 PASS**, exit **0**; selector and
  layout assertions pass. Its legacy headless ServiceSet receipt playback
  still emits the previously documented four-ObjectDB/two-resource
  **appliance_pop.ogg** shutdown warning. The warning is reported, not hidden,
  and is not attributed to these opening records; the focused M11B and M08A
  worlds exit without it;
- **MaintenanceServiceRoundTest:** all **13** public service-round checks pass,
  exit **0**, with empty stderr;
- **OrisonV2M11AFirstExteriorCellTest:** **40/40 PASS**, exit **0**, including
  the semantic save/reconstruction, rotated piece-two, selector/hash, and zero
  retained ObjectDB/resource assertions;
- matched M11A capture lifecycle: **3/3 PASS**, engine exit **0**. The control,
  first module cycle, and second module cycle are executed in one warmed
  process; cycle two adds **0 nodes, 0 resources, and 0 orphans** and has no
  positive object growth (**-116** raw objects) over cycle one. Both cycles
  report zero module-owned live survivors; all retained resources are
  attributed to the stable MatLib and ResourceLoader process caches;
- completeness audit: exit **2**, truthfully incomplete at the exact 150-row
  ledger above; the nonzero result is the existing whole-building queue, not
  an M11B test failure;
- spatial audit: exit **0**, **3,684** records, zero new unclassified,
  classification changes, vanished targets, or unresolved save contracts.
  Its **31**-record increase is entirely test-tier; production **593**, data
  **1,741**, and scene **5** are unchanged;
- systemic-authority audit: exit **0**, **59** findings, zero new actionable
  findings or policy violations;
- data-consumption audit: exit **1** with the reviewed repository debt exactly
  unchanged at **1,289 unread fields, 11 unread files, 2 monotonic-only durable
  numbers, and 1 malformed record**; no M11B source field or file is unread;
- static audit suites: completeness **99/99**, spatial **51/51**, systemic
  **34/34**, and data-consumption **14/14**, all exit **0**;
- checkpoint evidence-impact: exit **0**, admitted as a checkpoint with
  **requirements_changed = []**; and
- selector assertion plus protected bytes: **v1**, **17/17 hashes match**, and
  named protected-path diff exit **0**.

The focused M11B teardown starts with **1,707 objects / 26 resources / 0
orphans**, records **1,755 / 26 / 0** after F02 and **1,643 / 26 / 0** after
F04, and proves that a second warmed cycle causes no ObjectDB, resource, or
orphan amplification. Every focused world, blockout, and controller weak
reference and every captured review/player camera weak reference releases.
The broader capture process warms from **1,643 to 1,660** objects while nodes,
resources, and orphans settle at **35 / 34 / 0**;
that broad counter is not relabeled as a leak or as zero-retention proof. The
focused repeated-cycle and matched M11A lifecycle receipts supply the scoped
ownership result instead.

The repository-wide data audit may retain reviewed historical debt, but final
closure must demonstrate no new unread file, unread field, monotonic-only
persisted value, spatial drift, systemic-authority violation, completeness
promotion, or protected-byte change attributable to M11B. A nonzero audit with
known historical findings must be reported as nonzero, not rebased or
described as clean.

## Decision still required

The focused implementation is technically proved and the four-frame packet is
ready for owner review. The checkpoint remains **HUMAN REVIEW PENDING** until
the owner answers this question:

“Do both service openings read as deliberate, safe connections between core and
hall—and does F04 prove that another opening of this kind is now data work
rather than bespoke geometry code?”
