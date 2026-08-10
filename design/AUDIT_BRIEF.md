# THREE AUDITS: TEXTURES, CLUTTER, PLACEMENT

*Filed 2026-08-10. Commissioned by the owner. To be run AFTER the ceiling
pass lands, in this order, as three separate reports.*

These are **audits, not passes.** Do not fix while auditing. A report that
also changes things cannot be reviewed, because there is no way to tell a
finding from a decision. Propose every fix; implement none of them until the
report has been read.

---

## RULES FOR ALL THREE

- **One fenced report per audit.** Findings as: `file:line` or marker id |
  what is wrong | why it matters | proposed fix | confidence.
- **Rank by whether the player can see it.** A wrong texture scale on the
  lobby floor outranks a dead JSON field, always.
- **Verify against BUILT data, not source intent.** Read the layout JSON, the
  glTF contents, the actual render. Source that looks correct and output that
  is correct are different claims.
- **Any visual check must use `SCREENSHOT_STREAMING=1`.** `screenshot_run.gd`
  forces `show_all_floors = true` otherwise, which renders a state the player
  never occupies. That is how every flat came to have no ceiling for a day.
- **Render under authored lights and the torch.** No ambient override — an old
  0.55 override once hid navigation failures and erased real shadows.
- **THE CEILING RULE.** Nothing is applied building-wide before ONE example
  has been rendered and looked at. The failed-plaster pass built 42 zones
  before anyone saw one, and all 42 were wrong.

---

## AUDIT 1 — HOW TEXTURES ACTUALLY LAND ON OBJECTS

The question is not "do the textures exist". It is **"does this material read
correctly at the size of the object wearing it"**.

### Know that there are THREE registries and they are not the same list

| Registry | Lives in | Governs |
|---|---|---|
| `MatLib.SETS` | `game/scripts/material_library.gd` | runtime GDScript props |
| `MATERIAL_CATALOG` | `art/data/` | what Blender bakes |
| `GODOT_STAGE` | **`art/tools/ingest_material_sources.py`** | what gets copied to `res://` |

Membership in one implies **nothing** about the others. This has caused a
documented failure already and cost a review pass. Note especially that
`GODOT_STAGE` is *not* in `gen_layout.py`, which only mentions it in a comment.

### The four failure modes, in order of how badly they show

1. **Catalog key with no runtime set → flat colour.** `material_library.gd`
   documents this in its own comments: a key without a runtime set "is only a
   colour here: the cast grates lose their scale and the grease decal becomes
   an opaque brown card." Find every one of these.
2. **Wrong `meters_per_tile`.** Materials are **triplanar in world space at a
   physical scale**, so a scale error does NOT look like stretched UVs — it
   looks like a doorknob with brick-sized grain, or a wall with the texture of
   sandpaper. Check each key's m/tile against the **smallest** object that
   wears it, never the largest.
3. **One key doing two jobs at two scales.** The same material correct on a
   3 m wall and absurd on a 30 mm knob. These need a second key, not a tweak.
4. **Shared-material mutation.** MatLib caches one material per (key, tint);
   callers that need unique runtime mutation must `.duplicate()`. A prop
   mutating a shared instance changes every other object using it.

### Method

- **Use the warehouse. It is the instrument for exactly this.** It already
  stands 68 displays across 44 kinds, flat-lit, side by side, with variants
  grouped. Sweep it first — a material that is wrong is usually wrong next to
  its own siblings.
- Then spot-check **in situ**, because the warehouse's flat light hides
  roughness and normal-map errors that only a raking torch reveals.
- Report per key: where it is used, the smallest object it lands on, whether
  the grain reads at that size, and the fix — a new m/tile, a different key,
  a second key, or a real texture where a flat colour is standing in.

---

## AUDIT 2 — WHAT IS BUILT AND NEVER USED

Check **both directions**. Dead code is the easy half; live data pointing at
nothing is the half that actually bites.

### Direction A — code that never runs

Scripts in `game/scripts/` never preloaded or instantiated; classes with no
consumer; exported flags never set from anywhere; systems behind a flag that
is permanently false (`OrisonDetailPass.START_LOCKED` is a deliberate one —
confirm before proposing removal, it is kept for scenario use).

### Direction B — data that resolves to nothing

Markers whose `kind` maps to no script; acoustic-graph nodes no prop binds to;
catalog entries nothing reads; JSON fields nothing consumes.

**Two known precedents, because they are the shape to look for:**
- Arcade cabinets once spawned **unbound** — `graph_node_id` was only set on
  marker-spawned props, so `_on_reality_event` returned on its first line and
  the whole escalation was wired to nothing. It looked fine and did nothing.
- The flue markers carry `unit: "F02C"`, which is in **no namespace** — not a
  unit (`2C`), not a room id (`F02_C_BED1`), not a zone (`F02`). Harmless
  today only because props bind by marker id, not by room.

### Also worth finding

Duplicate authoring paths for one thing (the boxfan had both a `mk()` call
inside `dress_unit()` and an explicit marker dict elsewhere — either can be
edited without the other). Props present in the layout but never visible or
never reachable. Two systems doing one job.

### Removal discipline

**Propose, do not delete.** Verify each candidate against the *whole* tree
including tests before proposing. Several sessions share this working tree.
Generated files — `building_layout.json`, the glTFs, `acoustic_graph.json` —
are regenerated, never hand-edited, so a removal there means a generator
change and a rebuild.

---

## AUDIT 3 — IS EACH OBJECT WHERE IT SHOULD BE

Two separate questions, and both matter: is it placed **correctly**, and does
it **belong there**.

### Conventions that are easy to get wrong, and have been

- **Door markers are the HINGE JAMB, not the centre.** Yaw 0 → leaf runs +x;
  yaw 180 → −x.
- **Assembly yaw**: 0 = back faces +y, 90 = −x, 180 = −y, 270 = +x.
- **Pendant markers are ceiling anchors with a drop**, not the fitting
  position. The pool table's pendant once hung 21 cm off the felt because the
  drop was not applied.
- `b2g(p) = Vector3(p[0], p[2], -p[1])`. It is the only conversion.

### Human factors

Player eye is **1.41 m**; `BODY_RADIUS` is **0.33**. Anything meant to be read
must land in a believable reading band. Anything meant to be reached must be
reachable. Anything at eye height is the first thing seen in the room and had
better deserve it.

### Domestic logic

A prop can be mechanically perfect and domestically wrong: right room, wrong
resident; right resident, wrong year; right year, wrong side of the room from
the only power point. It is 1928 and everything ordinary is second-hand
(§VIII.5.h). Ask whether *this* person would own *this* object and put it
*there*.

### Clearance

Exterior door swings **are** audited now — do not assume that hole is still
open. But **furniture-aware NPC navigation does not exist** (`resident_nav.gd`
builds its graph from `fl["walls"]` alone, filed as R6), so placement cannot
lean on the router to prove a route is clear. Residents currently walk through
furniture, so the router will never complain.

### What to look for

Objects intersecting each other, floating, buried in a wall, blocking a route,
unreachable, at an implausible height, or duplicated within one room.
