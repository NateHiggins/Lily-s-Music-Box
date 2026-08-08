# Priorities — after the schedules landed and the phone became an object

Written at the close of 2026-08-07, a long session. Everything below is
committed and pushed; WalkTest, LightingAudit and ScheduleTest are green
on the tree as it stands.

## READ FIRST — two things will bite you

**`godot` is not on PATH.** The user moved their `Python projects`
folder into the repo root and the shim went with it. The user PATH
still points at `D:\Python projects\devkit\bin`, which is now empty.
Until that is repointed, call it by full path:

```
"C:\PleaseRemainOnTheLine\Python projects\devkit\bin\godot.cmd" --path game <scene>
```

**When the world stops the player, use the probe, not your eyes.**
`tests/RouteProbe.tscn` sweeps a player-sized capsule along a route and
names the first collider it touches. It turned "a black plane
somewhere" into a node name in one headless run, after reading the
geometry had produced two wrong answers. This is the most useful thing
added this session.

## P0 — the bodega cannot be entered (task #17)

The bar is reachable and verified walkable end to end. The bodega is
not: a straight-in probe at its door still stops. Setting the door leaf
"open" did not clear it, so the leaf keeps collision in its own
doorway. Full probe output and three ordered next steps are in the
task. This matters more than it looks — Cam's 3 a.m. sandwich, Jonah's
coffee and the Guests' chapel are all through that door, so roughly a
third of the schedule's night traffic is currently walking into a wall.

## P1 — finish Songbook Phase 1 (task #6)

Paused mid-build. DONE and committed, but inert: `SongResource` +
`last_train_home.json` (12 phrase slots), the procedural backing and
melody guide, the bar PA effect chain, mic capture with the diegetic
clap-check, and the version store with its genealogy-shaped record.
OUTSTANDING: the terminal prop in the bar, the lyric editor UI (draw
the syllable map — the data already carries it), the timed karaoke
display, and the review screen. Nothing references any of it yet, so
the project builds green with it sitting there.

## P2 — the phone, and what it is waiting on

The handset is a homebrew radio hot-glued into a BlackBerry frame,
carried bottom-right, rendering in its own World3D pass above the beam
mask, wearing eleven photographs. Its OS boots, runs a shell, takes
photographs to a 40-frame roll, and the roll is already the deck the
pairs game will deal from.

Next, in the order they pay off:
- **Hook `PhoneLightMask.punch()`** to the intrusion layer (task #19).
  One line, and it is the payoff for the whole blended-beam system.
- **The webview decision** (task #13) — still unmade, and it blocks all
  three HTML cartridges. `godot_wry` is overlay-only and cannot render
  inside a 3D phone; `gdCEF` renders to a texture but has no Android,
  ever. A native port of the three canvas games is the option that
  solves overlay, Android and the in-world screen at once.
- **The folder layout proposal** is still unapproved. `Python
  projects/` keeps a space and a capital in a git repo, and `devkit`
  living inside the repo it builds is the circular dependency that
  broke PATH in the first place.

## Standing state

- Schedules: 18 residents on the clock, 382 blocks, driving routines off
  the same clock as the sky. Residents WALK to the shops now rather than
  crossing hidden.
- Harukiya: rebuilt to the Belchi Lorente layout — split level, lounge,
  checkerboard table floor, curtained stage. Keeps hours (OPEN /
  AFTER-HOURS / CLOSED).
- Street: both shop signs redesigned off tube neon; the stage boundary
  has a gap at the crossing and its east wall cleared the bodega; the
  boundary bars are gone.
- Textures: 12 retail/bar surfaces + 11 phone surfaces ingested. The
  ingest now flattens baked lighting before tiling, which killed the
  repeating gradient grid.

## Invariants (unchanged, sworn again)

gen_layout authors all coordinates; b2g() is the only conversion; never
hand-edit generated JSON/glTF; all suites green before every commit;
fetch before push; one Godot instance at a time against the .godot
cache; audio stays procedural except catalogued, attributed assets with
gitignored sources. Verify visual work by rendering, never by reading
code — this session that rule caught a screen mounted inside its own
casing, a mask that was never drawing at all, and a bus shelter parked
in the middle of the road.
