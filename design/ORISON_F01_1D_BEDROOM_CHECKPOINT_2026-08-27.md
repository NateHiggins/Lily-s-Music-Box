# Orison F01 1D bedroom checkpoint — 2026-08-27

## Profile and verdict

`F01_D_BED` is Teresa Vale's street-facing bedroom: a narrow sleep room with
one bed, one bedside surface, wardrobe, wall art, two windows and an open route
from its internal door. The room-layout workbench identified `1D_bed0_ns` as
crossing the east exterior boundary. Player-height inspection confirmed the
table was authored on the exterior side of the bed.

- **MOVE `1D_bed0_ns` and `1D_BEDSIDE_TOP`:** place the nightstand on the
  bed's roomward west side. The standing interaction anchor follows it.
- **KEEP:** bed, wardrobe, art, windows, door and circulation aisle.

The bed helper now exposes an opt-in nightstand side. Only the F01 D-bedroom
call uses the roomward side; later D floors, C bedrooms and alcoves are byte-
stable in the regenerated layout.

## Workbench reconciliation and evidence

The old/current workbench comparison reports exactly two moved records in
`F01_D_BED`, both 2.120 m west: `1D_bed0_ns` and `1D_BEDSIDE_TOP`. The current
packet no longer lists the nightstand as a boundary crosser; `storm_pud8`, an
exterior storm effect, remains correctly outside room ownership.

Player-height evidence is in
`art/renders/orison_room_reconstruction/f01_1d_bedroom_checkpoint_01/`:
`00_bedroom_from_door.png` and `01_bedside_clearance.png`.
The proof suite now deliberately keeps the player lamp on. The production lamp
no longer creates a SubViewport or assigns `light_projector`: its former GPU
readback could resurrect a deleted Dream/Klimt plate from reused render-target
memory and stamp it across waking walls. The replacement frames prove the
authored spotlight remains useful without any projected image.

## Validation

- Layout generator: PASS.
- Room-layout workbench self-tests: 29/29 PASS.
- Scoped workbench comparison: exactly two dependent F01 records moved.
- Godot asset import: exit 0.
- `F011DBedroomShot`: PASS, 2/2 captures.
- `LampCookieRenderTest`: PASS, 5/5; no projector and no cookie viewport across
  off/on toggles.
- `WalkTest` FAST: PASS.
