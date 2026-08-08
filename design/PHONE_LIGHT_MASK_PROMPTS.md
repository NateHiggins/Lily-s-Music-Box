# THE TORCH BEAM MASK

`res://assets/ui/phone_light_mask.png` — 960×540 today, RGB, white in
the middle and about 11% blue-grey in the corners.

## What this asset actually is, because it is not what it sounds like

It is **not** a spotlight cookie. `gl_compatibility` — the renderer this
project targets for mobile — ignores `light_projector` outright, which
`_build_hud()` says in as many words. So the beam pattern is applied a
completely different way: a `TextureRect` on a CanvasLayer, stretched
over the viewport with 48 px of overscan, using
`CanvasItemMaterial.BLEND_MODE_MUL`.

That single fact decides everything about the asset:

| In the image | On screen |
|---|---|
| pure white | frame passes through untouched — this is the beam |
| black | fully dark |
| a colour | the frame is tinted that colour there |

So **the beam is the bright part and the mask is the darkness.** An
artist's instinct is to draw a glow on black; that would multiply the
whole frame down to nothing and leave a bright hole. Backwards.

Three consequences worth writing down:

- **The centre must be pure white**, not "bright". Anything less
  permanently dims the middle of the player's view.
- **The corners must never reach pure black.** At zero the frame is
  gone, not dark, and the building's own fixtures stop reading. The
  incumbent sits at 0.106, 0.122, 0.149 — dark, and biased blue,
  because the emitter is a blue LED behind phosphor.
- **No hard edges and no border.** The rect is oversized by 48 px and
  *drifts* with the hand sway, so any crisp circle or frame edge slides
  across the screen and reads as a UI element rather than as light.
  The gradient has to run off all four sides.

## Where the character goes

A phone torch is a small blue-white emitter behind a moulded plastic
cover that has spent years in a pocket. Everything interesting about it
is a defect:

- **Chromatic aberration.** Wavelengths focus at different radii
  through a cheap lens, so the pool's edge separates — warm amber just
  outside the white core, cold cyan further out. This is the single
  most valuable detail in the whole asset and the reason the current
  mask looks flat: it has a blue tint but no separation.
- **Moulding rings.** Injection-moulded lenses leave faint concentric
  steps. Barely visible is correct; visible is a target.
- **Scratches** read as fine radial streaks, because a scratch scatters
  light along the beam axis.
- **A hair or a crack** throws a spike or a line, and a spike is the
  cheapest character in lighting.
- **Off-centre hotspot.** The phone is carried low in the right hand,
  so the bright core belongs slightly right and above frame centre —
  and nobody's lens is aligned anyway.

## Three states, and why more than one

The torch is on from the first frame all shift (ruled 2026-08-04), which
makes it the most-looked-at surface in the game. One mask means one
mood forever. Three lets the building change the light without touching
the geometry:

| File | When |
|---|---|
| `phone_light_mask.png` | the everyday beam |
| `phone_light_mask_cracked.png` | swap in as sanity pressure climbs — the lens has a fracture throwing flare spikes |
| `phone_light_mask_dying.png` | a weak, cold, tight pool for low battery or a case going badly |

Swapping is a one-line texture assignment on `_light_mask`, so the
Intrusions/SanityDirector layer can reach for it the way it already
reaches for other cues.

## The prompts

Written for a generator being asked cold, with the multiply rule stated
up front because it is the thing a model will get backwards. The
paste-ready batch version — three numbered generations, explicit "these
are new images, there is no source" preamble — lives beside this file
as the batch text handed to the owner.

**Do not** let the generator draw a torch, a phone or a lens. There is
no object in the picture; there is only the pattern light makes. Every
prompt says so twice for that reason.

**Verify by multiplying, not by looking.** A mask judged on its own
looks like a grey blob. Load it, run the game, and check two things: the
centre of the frame is not dimmed, and the corners still show the
building's own fixtures rather than swallowing them.
