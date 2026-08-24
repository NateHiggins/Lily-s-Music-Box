# SERVICE ROUND M1 — shared hand-work and first live radiator

Production capture at 2560 × 1440, Godot 4.7.1 Forward+ on the production
radiator, production materials and production service-strip code. The harness
adds only a neutral wall, floor, camera and two review lights; it does not
substitute a proof mesh or draw the mechanism in the UI.

## Frames

- `01_radiator_control.png` — the untouched production 4B radiator family:
  cast sections, one-pipe supply handwheel, replaceable far-end air vent, riser
  union and pitch shim.
- `02_radiator_service_active.png` — the same camera and lighting at step 3/4.
  The real vent has rotated toward its authored seating value while the narrow
  paper strip names the action and shows travel/target. The room remains the
  dominant image; this is not a full-screen game board.

No A/A noise pair is required for this claim: the harness contains no live
shader, resident, weather, simulation-clock or procedural animation. The
control/active difference is deterministic. The first capture exposed an
illegible strip because its paper style was attached to a non-drawing margin
container; the production presenter now uses `PanelContainer`, and this final
frame is the corrected capture.

## Deterministic proof

- `MaintenanceActivityTest.tscn`: **PASS**. All three profiles validate; every
  micro-verb stays inside 3–12 seconds; wrong verbs, missed detents and early
  releases do not advance; quality is recoverable; abort returns no patch;
  accessibility scales precision/hold requirements; the director owns neither
  jobs nor mechanisms.
- `MaintenanceActivityLiveTest.tscn`: **PASS**. Preview changes visual fittings
  without publishing heat or vent facts; abort restores; completed output uses
  the radiator's public setters; both physical service reaches remain rayable.

The annunciator and boiler profiles are authored but are not live consumers at
M1. No work order, resident route, case progression or Dream communication is
claimed complete here.
