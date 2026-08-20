# The intrusion — workstream E landed

Owner ruling 2026-08-20: *"the warping gold resolves in animated gold
tentacles that intrude in the space that are modeled in 3d with meshes and
embrace the player if they get too close ... the animated otherworldness
ramps with exposure until full hyperdimensional tentacle monster geometry ...
This persists even when the light is not shining on it."*

Captured by `game/tests/DreamSurfaceTargetShot.tscn` with
`DREAM_SHOT_INTRUSION=1`, 1280x720, production `DreamMazeRoot`, seed
`f123456789abcdef`, night 7, no helper light or staged geometry. Frames 01–03
are the pre-existing R-series composition; 04–06 are the intrusion ramp.

## The frames

- **04_intrusion_half_reach** — the durable field at the breach driven to
  roughly half. The limbs' torso-thick grown portions cross part of the room;
  beyond the growth front the same centerlines survive as hair-fine filaments
  probing ahead. Nothing pops when exposure rises: the front slides along
  geometry that was always there.
- **05_intrusion_full_lamp_on** — saturated field. Three limbs at full
  crossing: the overhead arc passes in front of the camera (the brief's
  acceptance shot), the floor run and low drape below, wine-purple anatomy
  with the lamp finding only the gold vessel seams. The breach interior and
  its eye behind.
- **06_intrusion_full_dark_live** — the same body, lamp OFF. The limbs
  remain: wine-dark under the faint ruled afterglow, one eye still open, the
  0.42-energy reflected gold light pooling at the top of frame. Gold response
  is lamp-dominant and nearly gone; the BODY does not retract. This is the
  2026-08-20 hazard-anatomy override photographed.

## The numbers

Same one batched surface — the limbs add **zero draw submissions** at any
reach. Perf station, 1440p, staged breach room (`PERF_DREAM=1
PERF_DREAM_PHASE_TARGET=1 PERF_DREAM_PORTAL_TARGET=1`):

| state | calls | ms |
|---|---|---|
| A — field cold, limbs retracted | 12 / 21 | 2.16 / 2.01 |
| B — saturated + portal live | 194 / 221 | 2.10 / 2.21 |
| C — saturated, portal off (`DREAM_VIEW_PORTAL_OFF=1`) | **12 / 21** | 1.97 / 1.95 |

Rows are lamp off / lamp on. B's call jump is the R6 portal's second view of
the shared world, priced when it landed; C isolates the limbs plus the
reflected light against A: **identical submissions, no measurable frame
cost.** Extension is a vertex-stage decision from one `intrusion_reach`
uniform, derived by `DreamMazeRoot` from the same durable-field sample the
reflected light reads, so the CPU embrace evaluation and the GPU growth can
never disagree.

## The danger contract

Proximity to a grown limb, sustained past a 0.7 s grace, commits the one
existing capture through the landed R8 embrace. No CollisionObject3D, no
damage volume, no second combat system; `DreamHazardField` keeps sole
ownership of every hazard outcome, and the centerlines are mirrored onto the
source hazard as `embrace_paths` for attribution. Proven in
`dream_surface_target_test.gd` (`_intrusion_contract`, 13 checks: 105/105
suite total).
