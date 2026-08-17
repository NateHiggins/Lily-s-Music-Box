# THE REFLECTED WORLD — image prompts

*Owner direction 2026-08-17: "create an elaborate image prompt for the klimt
world that only exists in the reflection in the molten gold."*

Consumed by `game/shaders/dream_klimt.gdshader`, uniform `reflected_world`.
Generated plates land in `ai_sources/` and are promoted to
`game/assets/dream/` once accepted.

---

## THE IDEA, BEFORE THE PROMPT

The dream corridor is bare gilded architecture. Nobody is in it. That is the
whole horror of the place — you are alone in a building that is obviously,
recently, not empty.

**The people are in the reflection.**

Where your lamp melts the gold, the liquid metal mirrors a world that exists
nowhere in the scene: the Orison as Klimt would have painted it, its residents
gold-robed and facing you, the rooms you know rendered as decorative panels.
There is no geometry for it, no room you can walk into, no door that reaches
it. It is a texture sampled by a reflection vector and nothing else.

So the player can only ever glimpse it: melt a surface, catch it at the right
angle, and for a moment the wall remembers who lived here. Turn, and it is
gone. Look directly at the place it appeared and there is only ornament.

This is the one thing in the dream that is not procedural, and it should be
the one thing that feels **painted by a hand**. Everything else in this world
is generated; the memory is not.

It also earns its keep mechanically. The reflection is gated on `molten`, which
is gated on lamp proximity — so the only way to see the residents is to spend
light, and spending light is what draws the Tenant. **The dead are visible
exactly and only when you are in danger.**

---

## TECHNICAL REQUIREMENTS — these bind every plate below

| requirement | value | why |
|---|---|---|
| projection | **equirectangular (2:1 lat-long)** | sampled by `atan/acos` on the reflection vector; a flat plate would swim |
| resolution | **4096 × 2048** | it is only ever seen in fragments, but those fragments are seen very close on a mirror |
| horizontal tiling | **must wrap seamlessly left↔right** | the plate rotates slowly with the domain drift and a seam would read as a tear |
| vertical | must NOT wrap; top and bottom are poles | poles land on ceiling and floor reflections |
| format | PNG, sRGB, no alpha | |
| naming | `klimt_reflected_world_v1.png` | version suffix per house convention |

**Value structure is the trap.** The plate is added to `EMISSION` on molten
metal, so anything near white in the image becomes a blown highlight on the
wall. Keep the whole image in the **mid-to-low range** — the brightest thing
in it should read as a warm ochre, never as paper. There is no white in this
image. The gold does the brightness; the plate does the *content*.

---

## PLATE 1 — `klimt_reflected_world_v1` (the primary)

> An equirectangular 360-degree panorama in the style of Gustav Klimt's golden
> phase, painted as a continuous decorative frieze wrapping the full horizon.
>
> **The upper third**, above the horizon line: a canopy of coiling golden
> spiral tendrils on a warm ochre ground, dense with small concentric eye
> motifs and hanging almond-shaped leaves in viridian and lapis. The spirals
> tighten toward the zenith into a single vast coil.
>
> **The band at eye level**, and this is the subject: a procession of standing
> figures facing the viewer, shoulder to shoulder, encircling the whole
> horizon. They are ordinary people of the 1920s — a laundress, a druggist in
> an apron, a locksmith holding a ring of keys, a woman with a child on her
> hip, an old man with a folded newspaper, a girl with a radio valve in her
> cupped hands. Each is rendered the way Klimt renders his figures: the FACE
> and HANDS painted with soft photographic realism in warm flesh tones, and
> everything else dissolved into flat gold ornament — robes of stacked
> rectangles, spirals, mosaic blocks and concentric eyes, so that the bodies
> are pattern and only the faces are real. They do not smile. They are looking
> directly out, patiently, as though they have been waiting a long time and
> are not surprised to be seen.
>
> **One figure is wrong.** Somewhere in the procession stands a form of the
> same height and posture whose robe is the same gold but whose face and hands
> are not painted at all — a flat black silhouette where the skin should be,
> with no features. The figures on either side of it are turned very slightly
> away.
>
> **The lower third**, below the horizon: a dark bed of earth-brown and deep
> umber scattered with small irregular blossoms in oxblood, teal, lapis and
> dull silver, thinning toward the nadir into plain dark ground.
>
> **Palette**: gold leaf, ochre, bronze, deep umber, warm cream held below
> paper-white, with restrained accents of viridian green, lapis blue and
> oxblood red. Byzantine mosaic influence. Vienna Secession. Flat decorative
> gold against small passages of realist painting.
>
> **Surface**: visible gold leaf texture, fine craquelure, the tooth of gesso
> under metal leaf, hand-applied and slightly uneven.

**Negative:** no white, no pure black, no modern clothing, no text, no
lettering, no signature, no frame or border, no vignette, no photographic
lighting, no cast shadows, no perspective recession, no horizon glow, no
lens flare, no smiling, no crowd blur, no duplicated faces.

---

## PLATE 2 — `klimt_reflected_world_rooms_v1` (alternate)

Same technical requirements. For the variant where what the gold remembers is
the *building* rather than its people:

> An equirectangular 360-degree Klimt-style golden frieze in which the horizon
> band is a row of domestic interiors seen as flat decorative panels, each one
> a small room rendered in gold ornament: a kitchen with a kettle, a bathroom
> with a white enamel basin, a bedroom with an iron bedstead, a stairwell, a
> hallway with a row of numbered doors. The rooms are drawn in elevation with
> no perspective, like panels in a mosaic screen, separated by narrow vertical
> bands of concentric eye motifs. Each room is empty. In one of them, a chair
> is overturned.
>
> Above: coiling spiral tendrils on ochre. Below: dark earth scattered with
> small blossoms.

**Negative:** as Plate 1.

---

## PLATE 3 — `klimt_reflected_captions_v1` (Mina's case, optional)

Mina's grammar is that nouns appear on surfaces and then expand into claims
about the player. If the reflection is to carry a case's truth as well as its
dead, this is the plate:

> Same Klimt equirectangular frieze, but the ornamental bands between the
> figures carry hand-lettered Vienna Secession capitals in gold on umber,
> spelling ordinary nouns — DOOR, FLOOR, HAND, MOTHER, QUIET — set as
> decorative borders rather than as signage, with the letterforms partly
> dissolving into the surrounding spiral ornament.

**Negative:** as Plate 1, except lettering is permitted and is the subject.
No modern typefaces, no sentences, no legible paragraphs.

---

## ACCEPTANCE

A plate is accepted when, in `DreamEnvironmentShot`:

1. A molten wall shows recognisable **faces** at grazing angles, and shows
   nothing but ornament when looked at head-on.
2. No pixel of the reflection blows out. Measure it — the shot harness already
   reports mean/median/p98 per frame.
3. Rotating the domain a full turn shows **no vertical seam**.
4. The wrong figure is findable but not immediately obvious. If a reviewer
   spots it in under about ten seconds the silhouette is too dark or too
   central; regenerate rather than retouch.

Until a plate exists the shader falls back to a procedural studio gradient, so
the metal always has something to mirror and nothing is blocked on this.
