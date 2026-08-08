> Paste everything below the line into ChatGPT (with local access to
> `C:\PleaseRemainOnTheLine`). It is written to be self-contained.

---

You have local file access to a Godot 4.7 game repository at
`C:\PleaseRemainOnTheLine`. I want you to do a **prop design pass**:
compare our props against real-world reference, then improve the
modelling and the texturing.

**Do not start editing yet. Read first, then show me your plan for one
prop, and wait for me to approve it before doing the rest.**

## Step 1 — read yourself in (do this before anything else)

In this order:

1. `design/ORISON_BIBLE.md` — the covenant document. **§I THE WORD** is
   the aesthetic law ("both true"). **§VIII THE DIVERGENCE** is the
   alternate-history technology rule and it governs every object you
   will touch. **§VII THE LAWS** binds you, especially accords 9–15.
2. `design/PROP_ART_BRIEF.md` — your actual brief. Deliverables in §7,
   hard technical constraints in §3, priority order in §5.
3. `design/PROP_ACTIVITIES.md` — what each prop is about to be asked to
   DO. This changes the modelling: a crumb tray that will be pulled
   open has to be modelled as a tray that opens.
4. `game/scripts/props/functional_prop.gd` — the base class every prop
   is built from: `make_box`, `make_cyl`, `make_ring`, `make_emitter`,
   `smat`, `retexture`, `merge_static`.
5. `art/data/gen_layout.py` → the `MATERIAL_CATALOG` dict — **the only
   material keys that exist.** Read it before you name a material.
6. `design/ORISON_APPLIANCE_BIBLE.md` — what is plugged in, in whose
   flat, and why it is theirs.

The single most important thing you will read is the **Rule of Signal**
in bible §VIII.2:

> Does it carry, capture, switch, store or reproduce a signal?
> **YES** → it is forty years ahead of its time.
> **NO** → it is 1927, and probably second-hand.

Signal technology diverged in 1873; nothing else did. Apply that rule
before you look up a single reference image.

## Step 2 — look at the props two ways

Both. They show different faults and I want both reported.

**OUT OF THE ENVIRONMENT — the prop warehouse.** There is a lit shed 400
metres east containing one instance of every prop type, on a labelled
grid, under flat even light, with a 1 m grid painted on the floor.
Read `game/scripts/building/prop_warehouse.gd` — its header explains
what it is for. It exists precisely because props are authored in a dark
building at night, which is the worst place to judge them.

Use it to see silhouette, proportion, scale against the grid, and the
whole family side by side — that last one is how you notice that three
props share a silhouette.

It builds only in DEBUG launch mode. `res://tests/FreeCam.tscn` sets
that mode for you, and `PropWarehouse.viewing_stand()` gives the camera
position to stand at.

**IN SITU — where it actually lives.** A prop that reads perfectly on a
plinth can be wrong in the room: too tall for the worktop, invisible in
the dark, blocking a route, or identical to the three around it. Judge
lighting, scale-in-context and silhouette-against-background here, never
in the warehouse.

Use `res://tests/Screenshot.tscn` with `SHOT_DIR` and
`SCREENSHOT_ONLY`, or `res://tests/FreeCam.tscn` with `SHOT_ROOMS`.
**Judge rooms with `SHOT_LIGHTS=1 SHOT_TORCH=1`** — never the fill
light, which is a liar because merged meshes drop lights by AABB.

Both need a **real window** — do not pass `--headless`, it writes
nothing and exits 0. `SHOT_DIR` must be a Windows path that already
exists.

```
SHOT_DIR=C:/shots godot --path game res://tests/FreeCam.tscn
```

## Step 3 — the rule I care about most

**Verify by rendering, never by reading code.** This project has been
bitten repeatedly: a phone screen that rendered perfectly *behind its
own casing*, a torch mask that never drew at all, four scoreboards
laid out past the edge of the screen. All of them looked correct in the
source. Every prop you touch gets a before render and an after render,
and if you cannot show me both, the change is not done.

## Step 4 — what to hand back

Per `PROP_ART_BRIEF.md` §7:

1. `design/PROP_REFERENCE_NOTES.md` — prop by prop: what the real
   object was in 1927 New York at that price point, what we have, and
   what is wrong in specifics (proportion, missing parts, wrong period,
   wrong class of object entirely).
2. Edits to the prop scripts in the existing style. **Match the house
   comment voice** — it explains WHY a dimension is what it is and
   records what was tried and failed. Read a few props first; the
   comments are half the codebase's value.
3. New material keys added to `MATERIAL_CATALOG` in `gen_layout.py`
   (never to the generated JSON), wired through
   `ingest_material_sources.py` if a GDScript prop uses them.
4. A paste-ready texture prompt batch for anything new, to the rules in
   brief §4 — the most-broken of which is **no letters, numbers, words
   or logos in a generated texture, ever.**
5. Before/after renders.

## Step 5 — start here

Start with **`fridge_prop`** — 18 in the building, about to carry a
minigame, and the bible has already ruled that it is a **mix**: mostly
oak-and-zinc iceboxes with a drip tray somebody has to empty, and four
electric monitor-tops. Model both.

Show me: the reference comparison, the warehouse render, the in-situ
render, and your proposed changes. Then stop and wait.

## Things that will waste your time if nobody tells you

- `art/data/material_catalog.json` is **generated**. Hand-edit it and
  the next `gen_layout.py` run silently discards your work.
- A material key not in the catalog **fails the Blender build** with
  `mapping key 'x' not in material_catalog` and exit 1.
- A GDScript-built prop's textures never reach Godot through Blender.
  The key must also be in `ingest_material_sources.py`'s `GODOT_STAGE`
  and in `MatLib.SETS`, or it stays flat colour.
- GDScript has **no tuple unpacking in `for` loops**, and a
  **multi-line lambda does not parse** — the error points at the line
  *after* the fault.
- A new `class_name` does not exist until Godot rescans:
  `godot --headless --path game --editor --quit`.
- **A test scene whose script fails to parse hangs forever** instead of
  failing. Always run a new scene with a timeout.
- Flat metal renders **black** — a high-`metallic` horizontal surface
  reflects away from the eye. Use `brass_dull` (metallic 0.30) for
  anything horizontal. Measure the render by sampling RGB rather than
  judging a dark screenshot by eye.
- Run only **one Godot instance at a time** against the `.godot` cache.
  Two produce phantom test failures.
- The pipeline, after any `gen_layout.py` change:
  `python art/data/gen_layout.py` → Blender build → `cp art/data/*.json
  game/data/` → `godot --headless --path game --import`.

## Ask, do not assume

If something would change the **fiction** rather than the model, stop
and ask. Bible §VIII.6 fences the divergence deliberately: it is not a
licence for anachronism at will, and an object that carries no signal is
1927, second-hand, and probably a bit broken.
