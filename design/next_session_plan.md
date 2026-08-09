# Priorities — after the schedules landed, the phone became an object, and the cartridges came home

Written at the close of 2026-08-07 and extended 2026-08-08. Everything
below is committed and pushed; WalkTest, LightingAudit, ScheduleTest and
the three cartridge suites are green on the tree as it stands.

## READ FIRST — four things will bite you

**`godot` is not on PATH.** The shim now lives at `C:\devkit\bin\godot.cmd`
(moved out of the repo, verified answering 4.7.1). The user PATH still
points at the old `D:\Python projects\devkit\bin`, which no longer
exists. Until the user repoints it — a one-time thing, and the address
is now stable — call it by full path:

```
C:\devkit\bin\godot.cmd --path game <scene>
```

**A new `class_name` does not exist until Godot rescans, and a test
whose script will not parse HANGS FOREVER rather than failing.** This
cost a 600-second timeout with zero output. After adding any script with
a `class_name`, run this once before anything references it:

```
C:\devkit\bin\godot.cmd --headless --path game --editor --quit
```

**Anything touching the phone's camera needs a REAL WINDOW — no
`--headless`.** The handset photographs the world through a SubViewport,
and headless has nothing to read back, so `capture()` returns `""` and
every check downstream of the roll fails for reasons unrelated to what
is being tested. `CartMazeTest`, `CartShardsTest`, `CartPairsTest` and
all the shot passes are in this category. WalkTest, LightingAudit and
ScheduleTest are fine headless.

**When the world stops the player, use the probe, not your eyes.**
`tests/RouteProbe.tscn` sweeps a player-sized capsule along a route and
names the first collider it touches. It turned "a black plane
somewhere" into a node name in one headless run, after reading the
geometry had produced two wrong answers.

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

## P2 — the phone, which now has all three cartridges in it

The handset is a homebrew radio hot-glued into a BlackBerry frame,
carried bottom-right, rendering in its own World3D pass above the beam
mask, wearing eleven photographs. Its OS boots, runs a shell, takes
photographs to a 40-frame roll — and every tile in the launcher is now
live. No "no cartridge" text left on the home screen.

**The webview decision is CLOSED, and it went to native ports.**
`godot_wry` renders a webview as an always-on-top overlay and can never
appear inside a 3D phone held in the world; `gdCEF` renders to a texture
but has no Android support and never will. Neither covers Windows AND
Android, and these are tilt games shipping to Android. So the three
canvas games were rewritten as GDScript cartridges: `cart_pairs.gd`,
`cart_maze.gd`, `cart_shards.gd`. The HTML originals are UNTOUCHED and
still open in any browser, per the sealed-cartridge rule.

All three hide a photograph the player took, which is what makes them
belong here rather than being minigames bolted on:

- **PAIRS** — match to melt the veil off a photo, piece by piece.
- **MAZE** — roll a marble and the fog lifts wherever it wanders. Reads
  the accelerometer DIRECTLY, replacing the web build's
  `window.__nativeTilt` bridge, which only existed because a browser tab
  could not reach the sensor. On a handset you tilt the real phone to
  roll the marble on the phone drawn inside the game.
- **SHARDS** — glass triangles scattered off a photo; tilt them home and
  they lock with a gold hairline. Repaired, not restored.

Each has a suite (16, 16 and 11 checks) built around the ONE bug in it
that hides: reachability for the maze, tiling coverage for the shards.
Both would otherwise present as rendering artefacts.

Next, in the order they pay off:
- **Hook `PhoneLightMask.punch()`** to the intrusion layer (task #19).
  One line, and it is the payoff for the whole blended-beam system.
- **Verify tilt on real hardware** (task #20). The degrees conversion in
  `_read_tilt()` is reasoned, not measured, and it inherits axis
  conventions from a browser API. Never run on a device.
- **The bodega machine** (task #13) is **ruled, not blocked.** VIII.5.g
  settled it on 2026-08-09: it is not a game platform and there is nothing
  to port to it. It is Vantry-descended receiving furniture with a coin box,
  tuned to the same broadcast every other machine on the row receives. The
  pygame platformer remains a sibling desktop title under the standing rule
  and is now irrelevant here rather than merely deferred.

**The folder layout is DONE.** `phoneos/apps/{shattered,gilded_pairs,
velvet_maze}`, `nomoretears/`, `legacy_arcade/`, and `devkit` moved out
to `C:\devkit`. The cartridge games' Android wrappers are untracked and
ignored — packaging, not project.

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
in the middle of the road. On 2026-08-08 it settled a question the docs
would not: Godot's `draw_colored_polygon` UVs are normalized, which one
rendered frame answered and no amount of reading did.

Ported code gets a test aimed at the invariant that CANNOT be seen. Both
cartridge suites written on 2026-08-08 exist for a single bug apiece —
an unreachable maze cell, a gap between shards — because each is
invisible in the code, looks like a rendering fault on screen, and is
therefore chased in entirely the wrong place. Everything else in those
games is obvious within a second of playing them.
