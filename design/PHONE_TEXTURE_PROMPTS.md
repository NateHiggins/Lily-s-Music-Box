# NOCTURNE 900 — TEXTURE PROMPTS

Surfaces for the handset and its screen. Written in generator dialect
(see *Talking to the generator* in `MATERIAL_PROMPT_SHEET.md`): open
with a flatbed scanner, state scale as a count or a detail size rather
than in metres, ask for a close crop of a larger surface, and spend the
negatives on lettering.

**These do NOT go through `ingest_material_sources.py`.** The phone is
drawn as a 2D Control today, so each of these is loaded directly as a
`Texture2D` and drawn. If the phone later becomes a 3D object held in
the world (the diegetic build), the four ALBEDO surfaces below want
SLOTS entries and `GODOT_STAGE` at that point, because a GDScript-built
prop is invisible to the Blender bake. The overlays never do — they are
masks, not materials.

Two classes here, and mixing them up is the main way this goes wrong:

- **ALBEDO** — a colour surface, lit by the scene, tiles. Same rules as
  every other material in the project.
- **OVERLAY** — a greyscale mask drawn ON TOP with additive blending.
  Generated as light marks on pure black: black contributes nothing
  when added, so the black areas vanish and only the marks survive. No
  alpha channel needed and no cutout to author.

Save into `art/textures/phone/`.

---

# I. THE SHELL  (albedo)

## 1. `phone_softtouch.png` — the body

The 2011 enterprise finish: soft-touch rubberised plastic, which felt
expensive for about eight months and then went shiny wherever a thumb
lived.

```
A flatbed scanner scan of soft-touch rubberised plastic from a black
business phone casing, very dark charcoal with a fine even matte
texture like fine sandpaper. Worn smooth and slightly glossy in broad
patches where it has been held for years, so the surface reads matte in
some areas and faintly shiny in others. Fine scratches and a scatter of
tiny nicks, dust caught in the texture. Wear spread evenly across the
whole surface, many small marks rather than one big one, nothing that
draws the eye to a single spot. A close crop of a much larger casing:
plastic fills the entire frame edge to edge, no edges, no seams, no
buttons, no background. Lit absolutely evenly like a document scanner,
no shadows and no glare. Flat matte colour only. Square image, sharp,
high resolution, macro detail about the size of a thumbprint across.
No letters or numbers anywhere.
```

## 2. `phone_keycap.png` — the keyboard field

The reason anyone kept these phones, and the surface that carries the
most story: thumbs polish the common keys and leave the rest matte.

```
A flatbed scanner scan of the plastic of a phone keyboard keycap, hard
black moulded plastic with a very fine pebbled grain. Polished to a
soft shine in the centre where a thumb lands, still matte and grainy
toward the edges, with a faint greasy sheen over the polished area.
A few tiny chips at what would be a moulded edge. Wear spread evenly,
no single dominant blemish. A close crop of a much larger sheet of the
same plastic: it fills the entire frame edge to edge, no key shapes, no
gaps, no lettering, no background. Lit absolutely evenly like a
document scanner, no shadows and no glare. Flat colour only, no
hotspots. Square image, sharp, high resolution, macro detail roughly
one centimetre across. No letters or numbers anywhere.
```

## 3. `phone_chrome_band.png` — the side rail

The one flourish the hardware allowed itself.

```
A flatbed scanner scan of a brushed stainless steel trim band from a
phone, fine parallel brush lines running in one direction along the
image. Dulled and slightly clouded overall, with the high points worn
brighter and a scatter of fine cross-scratches from keys and pockets.
A faint darkening of grime along what would be a seam. Wear spread
evenly over the whole surface, many small scratches rather than one
deep one. A close crop of a much larger band: brushed metal fills the
entire frame edge to edge, no edges, no rivets, no background. Lit
absolutely evenly like a document scanner, no shadows, no glare and no
mirror reflections. Flat colour only. Square image, sharp, high
resolution, brush lines clearly visible but not magnified. No letters
or numbers anywhere.
```

## 4. `phone_bezel.png` — the faceplate around the screen

```
A flatbed scanner scan of dark anodised aluminium from a phone
faceplate, near-black with a fine even satin grain and a very slight
warm cast. Lightly scuffed with hairline marks, the anodising worn
thin at a few points to show brighter metal underneath, fine dust in
the grain. Wear spread evenly, nothing dominant. A close crop of a much
larger panel: metal fills the entire frame edge to edge, no edges, no
screw holes, no cutouts, no background. Lit absolutely evenly like a
document scanner, no shadows and no glare. Flat colour only. Square
image, sharp, high resolution, detail about two centimetres across.
No letters or numbers anywhere.
```

---

# II. THE SCREEN  (overlay — light marks on pure black, additive)

*This is the group that does the most work for the least effort. A
perfectly clean screen reads as a rectangle of light; a screen with
somebody's thumbprints on it reads as an object that has been carried.
Generate all three as light-on-black and add them over the rendered
screen.*

## 5. `screen_grime.png` — the thing that sells it

```
A flatbed scanner scan of greasy fingerprint smears and dust on black
glass, photographed against pure black. Several overlapping thumb
smudges with visible whorl ridges, dragged into arcs where a thumb has
swiped, plus fine dust specks and two or three short lint fibres. The
smears are pale grey and semi-transparent; everything that is not a
smear is pure solid black. Marks spread across the whole frame, none
dominant. A close crop of a much larger sheet of glass filling the
entire frame edge to edge, no glass edges, no reflections, no
background objects. Lit absolutely evenly like a document scanner, no
shadows and no glare. Square image, sharp, high resolution, roughly
the width of two thumbprints across. No letters or numbers anywhere.
```

## 6. `screen_scratches.png`

```
A flatbed scanner scan of fine scratches on black glass, photographed
against pure black. Dozens of very fine hairline scratches at varied
angles, a few slightly deeper, and one short curved scuff. The
scratches are thin pale grey lines; everything that is not a scratch is
pure solid black. Scratches spread evenly across the whole frame with
no single dominant gouge and no clustering in one corner. A close crop
of a much larger sheet of glass filling the entire frame edge to edge,
no glass edges, no reflections, no background. Lit absolutely evenly
like a document scanner, no shadows and no glare. Square image, sharp,
high resolution. No letters or numbers anywhere.
```

## 7. `lcd_matrix.png` — the panel's own pixel structure

*Tiny and TILING: this one repeats every few screen pixels, so its
scale matters more than its content. It is what makes a magnified
display read as a display rather than as big text.*

```
A flatbed scanner scan of an LCD pixel matrix seen through a
microscope, a strict regular grid of rectangular subpixels in red,
green and blue stripes separated by thin black gaps, exactly twelve
pixel cells across the image and twelve down. The grid runs perfectly
square to the edges of the image and repeats exactly, so the pattern
would continue seamlessly if tiled. Even brightness across the whole
frame, no vignette, no dust, no cracks, no variation between cells. A
flat orthographic view filling the entire frame edge to edge, no panel
edges, no background. Lit absolutely evenly, no shadows and no glare.
Square image, sharp, high resolution. No letters or numbers anywhere.
```

## 8. `screen_protector.png` — optional, and very good

*A cheap stick-on protector with trapped dust and a lifted corner. The
single most characterful thing you can put on this phone: nobody fits
one of these perfectly, and the failure is always in the same places.*

```
A flatbed scanner scan of a cheap plastic screen protector applied
badly over black glass, photographed against pure black. Three or four
small trapped air bubbles with bright rainbow-edged rings, a scatter of
dust specks trapped underneath, and a faint straight edge line running
near one side where the film does not quite reach. Everything is pale
grey and semi-transparent against pure solid black. Marks spread across
the frame. A close crop filling the entire frame edge to edge, no glass
edges, no background. Lit absolutely evenly like a document scanner, no
shadows and no glare. Square image, sharp, high resolution. No letters
or numbers anywhere.
```

---

# III. WHAT NOT TO GENERATE

Two things that look like texture jobs and are not, recorded here so
nobody spends an afternoon on them:

**The asset-tag sticker.** A half-peeled property-of sticker on the
back is a lovely idea and it needs *legible text* — an inventory
number, the answering service's name. Generators cannot spell, and the
project already knows this: every prompt in every sheet ends with "no
letters or numbers anywhere" for exactly this reason. Author the
sticker as a small quad with the text drawn in code, the same way the
Harukiya's board and the bodega's signs carry their lettering. Generate
the *paper* if you like — scuffed white label stock with a peeling
corner — and put the words on it yourself.

**Pixel-art app icons.** The launcher's icons are ASCII drawn in the
character grid, and they should stay that way. An in-universe hacked
Linux draws its icons out of the same characters as everything else;
swapping in generated pixel art would be prettier and would quietly
break the fiction that the whole OS is a terminal. It would also fight
the 3x5 block alphabet the banners already use. This is a case where
the cheaper thing is also the right thing.

---

# IV. WIRING THEM UP

The shell surfaces replace flat `draw_rect` colours in
`phone_device.gd`; load once in `_ready()` and use `draw_texture_rect`
with `tile = true`. The overlays are drawn last, over the magnified
screen texture, with additive blending:

```gdscript
# additive: black contributes nothing, so only the marks land
draw_set_transform(...)          # match the screen rect
material = CanvasItemMaterial.new()
material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
```

Keep the grime *subtle*. The temptation is to crank it until the
texture is visible; the correct amount is the amount you only notice
when it is switched off. Judge it by framegrab at both 720p and a
handset aspect, not in the editor at 400% zoom — the screen is small on
purpose and a smear that reads as character at full size reads as a
dirty lens at actual size.
