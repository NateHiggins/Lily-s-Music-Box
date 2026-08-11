# Arcade cabinets

The machines in the bar are playable, and they are lying to you — though not on
purpose, which is worse.

They are not arcade cabinets. There is no video game industry in this world.
They are Vantry-descended receiving furniture with a coin box bolted on: Bakelite
carcass, brass bezel, cloth-braided flex, a valve rack behind a service door, and
a **circular long-persistence scope** where a screen would be. They are not
playing a cartridge. There is no cartridge. They are **tuned** — and what they are
tuned to is a broadcast this world has no transmitter for. The governing ruling is
`design/ORISON_BIBLE.md` VIII.5.g; its precedent is WORS 1610 in §III, out of the
laundry room, 1962 to 1999, transmitter never found.

Each carries an enamel **programme card** in a lit frame. `SOMETHING IN THE HALL`
is a mystery serial, not for children, one sitting. `THE LONG TALLY` is a farm and
market report, prices on the half hour, no action sequences. They are the same
programme. Same room, same colliders, same three waves, same weapon numbers, down
to the byte.

**Every machine is receiving the same signal.** That is the same line
`broadcast_director.gd` already says about the televisions — one signal, one
decode, every lit set tuned to the same interference. The cabinets rhyme with the
sets deliberately; they are the same building doing the same thing in another
room.

That is the joke, and it is checked rather than asserted: the world compiler runs
`worldc invariance` across all twelve compiled cabinets and refuses to write the
catalog if any two of them differ mechanically.

## A note on names

The fiction and the code disagree on purpose, and it is worth knowing which is
which before you go looking.

**In the world** these are not arcade cabinets. There is no video game industry
in the Orison; there is a signal parlour, and the machines are Vantry receiving
furniture with a coin box on them (`ORISON_BIBLE.md` VIII.5.g). Cards, not
marquees. Programme formats, not genres. Chassis years, not console generations.

**In the code** the subsystem is called `arcade` everywhere — `arcade_pit`,
`build_arcade.py`, `arcade_cabinets.json`, `ArcadeCabinetProp`, `arcade_row.gd`,
`game/assets/arcade/`. That is the lineage the implementation grew from and it
is not being renamed: a rename touches twenty files, a catalog, an asset
directory and a scene id, and buys nothing a sentence cannot.

So: **`arcade` is the subsystem, the signal parlour is the fiction.** If a
document says one and the code says the other, they agree.

## Where it comes from

Nothing in `game/` generates these. They are a build output of a separate
project, the Semantic World Compiler at `C:\FPSengine01`, which compiles one
authored level against many natural-language prompts and proves the gameplay is
untouched. See `docs/orison-arcade.md` in that repository for the full contract.

What lands here:

```
game/assets/arcade/
  arcade_cabinets.json      the catalog: 12 machines, their cards, their signals
  semantic_scene.json       the game, once
  packages/cab_*.swcpkg     one ROM per cabinet, ~1.25 MiB each  (~15 MiB total)
```

`arcade_cabinets.json` is a build output. **Do not edit it** — regenerate it. Its
`gameplay_identical` field is `true` only because the compiler proved it.

## How it is put together here

| | |
|---|---|
| `scripts/arcade/swc_*.gd` | the ported runtime: package reader, scene loader, world builder, player, enemies, doors, pickups |
| `scripts/arcade/arcade_machine.gd` | one machine's board — a SubViewport at 480×360, plus the phosphor viewport |
| `scripts/arcade/arcade_attract.gd` | the copy on the screen, straight from the cabinet's `cabinet_language` |
| `scripts/arcade/arcade_catalog.gd` | reads `arcade_cabinets.json` |
| `scripts/arcade/swc_held_object.gd` | the viewmodel and the projectile |
| `shaders/scope_screen.gdshader` | the tube face: circular aperture, phosphor tint, sweep, graticule |
| `scripts/props/arcade_cabinet_prop.gd` | live tube, programme card, panel controls, glow, the switch |
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

So `ArcadeCabinetProp` follows `TVProp`: it adds the live tube face, the
programme card, the glow, the panel's own controls and the interaction, and
nothing else.

**The picture is a round tube, and the trail is real.** `scope_screen.gdshader`
discards outside the tube face, tints to one phosphor, and adds the sweep and the
etched graticule. Persistence is *not* faked there — a fragment shader has no
memory of the previous frame — so it is accumulated upstream in a second 2D
viewport (`ArcadeMachine._build_phosphor`) that **never clears**: each frame a
low-alpha black rect dims the glass, then the new frame blends over it. That is
an exponential decay, which is what a phosphor is.

**The tube has one phosphor**, chosen by chassis year: willemite yellow-green on
the earliest boxes, the blue-white long-persistence radar coating on the last. The
**unmarked** chassis show colour, which no coating available in 1927 can do.
Nothing in the game explains that, and nothing should.

**The panel controls are furniture.** A tuning dial, a telegraph key, a patch bay
wired to nothing, a call bell, a foot pedal. Whatever is on the scope reads a
stick and one button regardless — that is the joke made physical, and it is the
same joke as the format on the card.

`_VARIANTS` in `arcade_cabinet_prop.gd` mirrors the Blender geometry per variant.
**If `asm_arcade_cab` is edited, those numbers move with it.**

Two millimetre-level facts, both learned the hard way:

* The face of the cabinet is prop-local **−Z** (Blender front is −y, `b2g` sends
  it to +Z, and the prop turns a further half circle to meet the room — same as
  the televisions).
* The picture sits **26 mm proud** of the glass. The assembly puts a bakelite
  surround 20 mm in front of the screen; a quad level with the glass is mostly
  behind that surround, which looks exactly like the feed not working.

### Which programme goes in which machine

`ArcadeRow` assigns from the catalog **format-first**, not in catalog order. The
catalog is sorted by id, which is right for a build output and wrong for a room —
the first two entries are both mystery serials, and two side by side read
as one product line rather than as an industry.

Adding a machine is an `arcade_cab` entry in `gen_layout.py`. It takes the next
unused genre in the catalog and nothing here changes.

### Talking to the building

Machines are bound to the nearest acoustic-graph node within 14 m — the bar pair
land on `F01_BAR_LT_DECK0`, the bar's electrical node, about 1.5 m away.

This is done explicitly in `ArcadeRow` because `building_root._spawn_props` only
sets `graph_node_id` for props spawned from **markers**, and cabinets come from
**furniture**. Without it they spawn unbound, `FunctionalProp._on_reality_event`
returns on its first line, and the whole escalation below is wired to nothing.
`ArcadeRow` warns if any cabinet finds no node.

## What happens as reality gets worse

The cabinet loses the picture before it loses the world.

| infection | what you see |
|---|---|
| 0.0 | a clean picture of whatever programme the card claims |
| 0.35 | the tube is rolling, the trace tearing, flickering; the world is intact |
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

The card's claimed format reaches down into the compiled world and redresses it:
a motor-racing card gets daylight, tarmac and guard rail; a farm-and-market card
gets fluorescent tubes, suspended ceiling and carpet tile; a variety hour gets a
black room and magenta rigging. It reaches lighting, palette, every material, the
architecture, the bodies, and the object in the player's hands.

It cannot reach the level. That is the entire design — the harder these skins
work, the more the graybox underneath is worth revealing.

The held object is the sharpest version of it. A farm-and-market card hands you a
clipboard and you issue a **memo**; a motor-racing card hands you a wheel and it
throws **sparks**; a variety hour hands you a microphone and it throws a
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

## Shipping them

`.swcpkg` is not a Godot resource. It has no importer and no `.import` file, so
`export_filter="all_resources"` walks straight past the whole directory. The
preset therefore carries an explicit `include_filter="*.swcpkg"`, and **that one
line is what puts the skins in the build.**

This was worth an hour to prove because of how it fails. The catalog *is* a
`.json` and does ship, so every cabinet still appears, still boots, still plays
correctly - in graybox. Twelve machines telling the row's joke straight, with no
error a player or a tester would see. `ArcadeMachine` now separates the two
cases: a catalog entry with no `package` is deliberate graybox and warns, while
an entry naming a package that fails to load is `push_error`.

To check an export rather than trust it, mount the pack from a scratch project -
`ProjectSettings.load_resource_pack()`, then list
`res://assets/arcade/packages`. Do not grep the pack for path strings; those
strings appear in other resources too, and that false positive is what made this
look fixed when it was not.

## Cost

One live cabinet is a full 3D world in a SubViewport. Machines build lazily on
first approach and only render within 9 m; beyond that the board is switched off.
Nothing is ever unloaded once built — see the open items below.
