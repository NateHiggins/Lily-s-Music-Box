# Arcade cabinets

The two machines in the retail bar are playable, and they are lying to you.

Each one boots a small first-person shooter. `SOMETHING IN THE HALL` sells itself
as horror — "A STORY IN ONE SITTING", "HIDE · LISTEN · SURVIVE". `OPERATIONS`
sells itself as a management sim — "HIRE · BUILD · BALANCE", forty weeks to break
even. They are the same game. Same room, same colliders, same three waves, same
weapon numbers, down to the byte.

That is the joke, and it is checked rather than asserted: the world compiler runs
`worldc invariance` across all twelve compiled cabinets and refuses to write the
catalog if any two of them differ mechanically.

## Where it comes from

Nothing in `game/` generates these. They are a build output of a separate
project, the Semantic World Compiler at `C:\FPSengine01`, which compiles one
authored level against many natural-language prompts and proves the gameplay is
untouched. See `docs/orison-arcade.md` in that repository for the full contract.

What lands here:

```
game/assets/arcade/
  arcade_cabinets.json      the catalog: 12 cabinets, their claims, their ROMs
  semantic_scene.json       the game, once
  packages/cab_*.swcpkg     one ROM per cabinet, ~1.25 MiB each  (~15 MiB total)
```

`arcade_cabinets.json` is a build output. **Do not edit it** — regenerate it. Its
`gameplay_identical` field is `true` only because the compiler proved it.

## How it is put together here

| | |
|---|---|
| `scripts/arcade/swc_*.gd` | the ported runtime: package reader, scene loader, world builder, player, enemies, doors, pickups |
| `scripts/arcade/arcade_machine.gd` | one cabinet's board — a SubViewport at 480×360 running one ROM |
| `scripts/arcade/arcade_attract.gd` | the copy on the screen, straight from the cabinet's `cabinet_language` |
| `scripts/arcade/arcade_catalog.gd` | reads `arcade_cabinets.json` |
| `scripts/arcade/swc_held_object.gd` | the viewmodel and the projectile |
| `scripts/props/arcade_cabinet_prop.gd` | live screen, marquee, glow, and the switch |
| `scripts/building/arcade_row.gd` | walks the layout for `asm == "arcade_cab"` and fills each one |
| `scripts/ui/arcade_panel.gd` | standing at the machine, playing it |
| `tests/ArcadeTest.tscn` | boots all twelve, asserts one gameplay fingerprint |

Every ported class is prefixed `Swc`. Orison already has its own `Player`, and a
silent `class_name` collision between two games in one project is a bad
afternoon.

The port is a **copy, not a submodule**. The two projects share a *format*, not
code: `C:\FPSengine01` can be deleted and the arcade keeps working. Re-port by
re-running the copy step in that repository's doc, not by hand-editing here.

### The prop is dressing, not a cabinet

`asm_arcade_cab` in `art/blender/scripts/build_orison.py` already builds the
carcass, coin door, vents, feet, control panel and three buttons into the merged
floor mesh, in one of four silhouettes, and leaves the screen as flat dark
`screen` material. Its own comment says the glow is the Godot prop's job.

So `ArcadeCabinetProp` follows `TVProp`: it adds the live screen, the marquee
artwork, the glow and the interaction, and nothing else. `_VARIANTS` in that file
mirrors the Blender geometry per variant. **If `asm_arcade_cab` is edited, those
numbers move with it.**

Two millimetre-level facts, both learned the hard way:

* The face of the cabinet is prop-local **−Z** (Blender front is −y, `b2g` sends
  it to +Z, and the prop turns a further half circle to meet the room — same as
  the televisions).
* The picture sits **26 mm proud** of the glass. The assembly puts a bakelite
  surround 20 mm in front of the screen; a quad level with the glass is mostly
  behind that surround, which looks exactly like the feed not working.

### Which game goes in which cabinet

`ArcadeRow` assigns from the catalog **genre-first**, not in catalog order. The
catalog is sorted by id, which is right for a build output and wrong for a room —
the first two entries are both horror, and two horror cabinets side by side read
as one product line rather than as an industry.

Adding a machine is an `arcade_cab` entry in `gen_layout.py`. It takes the next
unused genre in the catalog and nothing here changes.

### Talking to the building

Cabinets are bound to the nearest acoustic-graph node within 14 m — both bar
machines land on `F01_BAR_LT_DECK0`, the bar's electrical node, about 1.5 m away.

This is done explicitly in `ArcadeRow` because `building_root._spawn_props` only
sets `graph_node_id` for props spawned from **markers**, and cabinets come from
**furniture**. Without it they spawn unbound, `FunctionalProp._on_reality_event`
returns on its first line, and the whole escalation below is wired to nothing.
`ArcadeRow` warns if any cabinet finds no node.

## What happens as reality gets worse

The cabinet loses the picture before it loses the world.

| infection | what you see |
|---|---|
| 0.0 | a clean picture of whatever game it claims to be |
| 0.35 | the set is rolling, chroma splitting, flickering; the world is intact |
| 0.5 | the skin starts lifting off the world, entity by entity |
| 0.85 | the object in the player's hands goes |
| 1.0 | the authored graybox, under neutral light, identical on every machine |

The order matters. The dressing fails before the level does, because the level was
never the lie. And the collapse order is stable — each entity has a threshold
hashed from its semantic id — so a half-degraded cabinet reads as decay rather
than as flicker.

At full degrade every cabinet on the row is showing the **same frame**. That is
the reveal the whole thing is built around, which is why the compiled
*environment* degrades too: stripping only the meshes would leave twelve
differently-lit rooms, and "same layout, different game" is a much weaker read
than "same room".

Light **energy and range never move** — they decide what the player can see, so
they are gameplay. Only the tint does.

## Why the games look so different

The cabinet's claimed genre reaches down into the compiled world and redresses
it: a racing cabinet gets daylight, tarmac and guard rail; a management sim gets
fluorescent tubes, suspended ceiling and carpet tile; a dance cabinet gets a black
room and magenta rigging. It reaches lighting, palette, every material, the
architecture, the bodies, and the object in the player's hands.

It cannot reach the level. That is the entire design — the harder these skins
work, the more the graybox underneath is worth revealing.

The held object is the sharpest version of it. A management sim hands you a
clipboard and you issue a **memo**; a racing cabinet hands you a wheel and it
throws **sparks**; a dance cabinet hands you a microphone and it throws a
**note**. All of them do 24 damage at 420 rounds per minute, hitscan, identical
spread — the projectile is launched *after* the raycast has already resolved and
applied damage, so it is chasing a decision rather than making one.

## Running and verifying

```bash
godot --headless --path game --import
godot --headless --path game res://tests/ArcadeTest.tscn
```

Expected:

```
[ARCADE] catalog: 12 cabinets, scene=arcade_pit, certified_identical=true
[ARCADE] ok   SOMETHING IN THE HALL    horror         96 entities, 95 bound, 0 unresolved
...
[ARCADE] 12 cabinets, 1 gameplay fingerprint
[ARCADE] PASS
```

95 of 96 bound is correct, not a shortfall: `trigger_vault_alarm` is `LOCKED` in
the semantic scene and appears in every package's `unbound` list with that
reason. "Deliberately graybox" has to stay distinguishable from "silently
missing".

Picture tests need a real window — SubViewports and emissive marquees do not
render headless. Use `--audio-driver Dummy` unless you want the whole building's
soundtrack:

```bash
SHOT_DIR=../art/renders/insitu godot --path game --audio-driver Dummy res://tests/ArcadeShot.tscn
SHOT_DIR=../art/renders/insitu godot --path game --audio-driver Dummy res://tests/ArcadeFeedShot.tscn
```

`ArcadeShot` photographs the row in the bar, one screen close up, and the same
screen infected. `ArcadeFeedShot` photographs each board's raw output plus the
same board fully degraded — the pair that shows six different games landing on
one room. `ArcadePropShot` is one cabinet against a neutral background, for when
a screen looks wrong in the bar and you need to know whether the fault is the
prop or the room.

**New `class_name`s are invisible until an import pass has run.** A missing
`--import` shows up as `Could not find type "ArcadeRow" in the current scope`,
which looks like a typo and is not.

## Regenerating the cabinets

From `C:\FPSengine01`:

```bash
python tools/authoring/build_arcade_scene.py
python tools/build_arcade.py --strict --out C:/PleaseRemainOnTheLine/game/assets/arcade
```

Adding a cabinet is adding a prompt to `prompts/` and re-running. The build fails
rather than writing a catalog if invariance stops holding.

## Cost

One live cabinet is a full 3D world in a SubViewport. Machines build lazily on
first approach and only render within 9 m; beyond that the board is switched off.
Nothing is ever unloaded once built — see the open items below.
