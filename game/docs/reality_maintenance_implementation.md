# Reality Maintenance — Implementation Roadmap

## Non-negotiable case rule

A maintenance minigame suppresses immediate danger. The manifestation
reoccurs until the resident recognizes and changes the underlying emotional
pattern. Permanent resolution requires repeated practical intervention,
resident trust, required conversation insights, and a final integration act.

## Implemented foundation

- `RealityState` persistent campaign-state autoload and versioned JSON save.
- `RealityCases` data-driven case lifecycle autoload.
- Eighteen resident case definitions in `data/reality_cases.json`.
- Separate `building_stability` and `reality_coherence` progression.
- Explicit stages: unseen, active, stabilized, reopened, recognized,
  integration-ready, and resolved.
- Stabilized cases carry `recurrence_pending`; resident interaction reopens
  them unless they are resolved.
- Resolution requires each case's repair count and recognition flags.
- Resolved cases contribute a durable rule to the storage portal.
- Resident placeholders activate/reopen their assigned cases when spoken to.
- Mina's first visual manifestation scaffold in apartment 2A.
- Case manifestations radiate from a resident-bound acoustic-graph origin.
  Nearby fixtures react first and most strongly; delayed, damped effects reach
  other apartments and floors through the building's physical networks.
- Master affected-prop catalog with 54 resident anchors and eight shared
  maintenance/storage props. All 62 are procedurally generated, placed in
  scene, and respond to their case's recurrence intensity.
- `RealityRules` converts case state into composable gravity, topology,
  language, duplication, and affected-prop behaviors. Mina, Peter, and Cam
  provide the first authored rule profiles.
- Eighteen apartment reality controllers own room bounds, canonical transforms,
  deterministic restoration, and room-local gravity lookup.
- Reusable paired reality thresholds preserve body offset, facing, and velocity
  across impossible doorways.
- The player controller consumes room-local gravity, including floor direction,
  falling, jumping, and a restrained camera roll.
- The debug panel exposes Mina's label rules, Peter's topology rules, and Cam's
  tilted gravity for rapid in-building testing.
- Mina's Caption Crisis is playable from the lobby work-order terminal through
  two practical repair rounds, building-wide recurrence, two recognition
  insights, final integration, and a persistent harmless refrigerator caption.
- Mina's caption round uses physical apartment targets with competing factual
  and interpretive labels. The calibrator rejects claims that exceed directly
  observable evidence.
- A reusable objective tracker and physical `CaseInteractable` provide the
  template for subsequent resident cases.
- The F3 Map Distortion Lab applies reversible alternate-map treatments to the
  player's current floor: upside-down, folded, accordion, dollhouse, fractured,
  and breathing. Rendered architecture disagrees with canonical collision,
  floor changes preserve the selected treatment, and `none` restores every
  captured mesh transform exactly.
- All distortion treatments are independently selectable in the F1 debug panel
  so they can be playtested for fear, readability, motion comfort, and case fit
  before becoming authored manifestations.
- Debug controls for Mina's complete lifecycle.
- Focused automated recurrence test.

## Next vertical-slice work

1. Replace Mina's prototype real-talk cards with fully voiced branching
   dialogue while retaining the same recognition flags.
2. Add a shift/visit boundary so recurrence timing can breathe instead of
   depending only on the next resident interaction.
3. Add Mina's resolved portal rule to the former-suite storage display.
4. Apply the reusable case-interaction contract to Peter and Cam.

## Production waves after Mina

- Audio/UI: Juno, Rhea, Cal, Sacha.
- Prop/inventory: Omar, Lena, Iris, Mae, Evelyn.
- Spatial: Nadia, Peter, Cam, Noel, Transient Guests.
- Organic/language: Malcolm, Teresa, Jonah.

Only enable another case definition after its full recurrence and integration
arc can be completed and restored from a save.
