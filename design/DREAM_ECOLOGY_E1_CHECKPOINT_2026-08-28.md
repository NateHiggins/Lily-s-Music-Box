# DREAM-ECOLOGY-E1 checkpoint — 2026-08-28

## Ownership map (written before implementation decisions)

| Ecological fact | Existing authority extended | Boundary retained |
| --- | --- | --- |
| Field growth, source position, physical body/trail | `LivingField` via `ApartmentEncroachment` | Colony reads its census; it does not duplicate voxels or agents. |
| Ether quantity and support | One transient `DreamMossColony` record owned by `DreamEcologyDirector` per existing field source | Bounded query data only; no physics particle or save payload per ether unit. |
| Target scoring | `DreamTargetProfile`/contact candidates plus colony observable scoring | No case truth, narrative outcome, or hidden global knowledge is accepted. |
| Contact information | Existing target/contact profiles and `DreamEcologyDirector` typed signal ring | A completed cilium sample emits `SrcClass.CILIA / Fn.PROBE / Chem.VASCULAR`. |
| Organelle lifecycle | Existing local controller plus ownerless `DreamOrganelleLifecycle` vocabulary | Colony gates ecological birth/support/return; it does not replace visual lifecycle owners. |
| Signaling and coordinated attention | `DreamEcologyDirector` | Existing 32-packet ring and four-voice cellular audio pool remain capped. |
| Disturbance | Existing interaction/incident entry points, routed to director | Colony records causal recall/collapse; presentation owners perform poses. |
| Senescence | Existing organelle owners and lifecycle vocabulary | Colony marks unreachable transient records senescent in place and records residue. |
| Residual stain | `LivingField.stain`, fauna/margin stain owners | Colony provides density-correlated transient collapse facts; it is not a second global stain authority. |
| Cleanup/repulsion | `OrganismIncidents` -> `LivingField.repel` | Colony cleanup API accepts only an explicit authorized call; no autonomous fading. |

## Causal lifecycle and state machine

The authoritative colony phases are `searching`, `seeded`, `tending`, `exploring`, `networked`, `complex`, `disturbed`, `recalling`, `withering`, `stained`, and `cleared`. Every transition stores a concise time, phase, and measurable reason.

The pioneer chooser filters inaccessible, ineligible, exterior, sealed, and decorative candidates before scoring observable target density, information value, surface continuity, volume, disturbance/stain avoidance, and route cost. A seeded choice is deterministic. Stable occupied `LivingField` surface and returned information increase maturity; elapsed time by itself cannot.

Cilia are the only class permitted before a cilium record exists. Production cilia sample nearby profiled props on a bounded four-second cadence and report through the existing typed signal ring. Specialized limbs require cilia, moss maturity, stored information, root range, and local ether. Complex organelles additionally require maturity >= 0.62, connected ether volume >= 1.2, three information modalities, two reinforced routes, available capacity, and no collapse.

## Ether model

Ether is a bounded query over the moss origin and at most 64 route polylines. Concentration is strongest at the moss, falls with distance, is biased by route conductance, and is multiplied by obstruction loss. It has no per-unit node. Organisms hold a finite reserve, recover in dense ether, drain outside it, and must have either direct class-radius support or a live, sufficiently conductive, non-isolated route.

## Information vocabulary and specialization

Observations may contain only observable channels: moving parts, heat, vibration, electrical activity, controls, openings/seams, recent interaction, material complexity, case-authorized anomaly, state signature, and modalities. The first state signature is valuable; identical repeats diminish; a changed signature restores novelty.

| Class | Preferred channel | Support radius | Excursion | Ecological effect |
| --- | --- | ---: | ---: | --- |
| Cilium | adjacent touch/material | 0.9 m | 5 s | first worker; local sample and vascular report |
| Palpator | material/heat | 2.2 m | 14 s | broad touch response |
| Vibration listener | vibration/moving mechanisms | 3.0 m | 20 s | mechanical/sound investigation |
| Ocular examiner | visible movement | 2.8 m | 16 s | line/motion inspection |
| Sucker sampler | material/heat | 2.0 m | 12 s | close surface sampling |
| Manipulator | controls/openings | 2.4 m | 14 s | seams, controls, cavities |
| Relay tendril | route value | 3.6 m | 24 s | long information support |
| Complex organelle | multimodal | 2.8 m | 18 s | mature supported cohort only |

Low ether, high information load, disturbance, or excursion deadline forces return, in that priority order. Reports restore ether and reinforce useful routes. Three empty returns weaken a route; sufficiently weak routes become inactive. A return without a valid path becomes senescent residue at its actual position.

## Disturbance, stain, and cleanup

Disturbance emits an existing alarm/inhibit packet, seizes coordinated attention, and moves the colony through alert, recall, ether failure, withering, and stain. Stain density is strongest at the moss heart, follows reinforced routes, and includes stranded organism impressions. `LivingField` remains the rendered/repellent stain owner. Authorized maintenance remains the only clearing route.

## Budgets and limitations

Per colony: 48 remembered targets, 64 routes, 24 organisms, including at most 8 cilia, 6 specialized tentacles, and 4 complex organelles. The director signal ring remains 32 packets and cellular audio remains four voices. Target and route eviction are deterministic; production does no per-frame whole-scene scan.

This is the lifecycle-authority checkpoint requested for a task too large for one safe production pass. It does not yet provide final bespoke ether-moss rendering, visual cilium folding, all six production tentacle morphologies, fauna return animation, or the requested 13-shot production capture. Those should build on this authority rather than introduce another simulation.

## Validation and evidence

`game/tests/DreamMossEcologyTest.tscn` is the dedicated deterministic lifecycle scene. It proves all 25 requested behavioral categories with 26 assertions. Existing `LivingFieldTest` passes 24/24 at 2.95 ms/tick in the recorded run, and `DreamOrganelleLifecycleTest` passes 16/16. Machine-readable evidence is under `art/renders/dream_ecology_e1/2026-08-28/`.
