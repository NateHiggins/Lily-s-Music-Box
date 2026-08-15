# Grand Mundane title hero — generation record

Status: **production title art record, 2026-08-15.** This document records the
bitmap synthesis used by the title screen; it does not add locations, events
or supernatural facts to canon.

## Owner boundary

> The dream world is our reveal.

The frame may feel like grand fantasy, but every depicted thing must belong to
the waking-world game: old architecture, weather, public infrastructure,
maintenance work, ordinary light and the approved three-zone route. It must not
preview dream geography, the Tenant, a pursuer, a maze, impossible architecture
or an explicitly supernatural event.

## Reference inputs

- `game/assets/ui/title/orison_stairwell_title_v2.png` — Orison material,
  weather and title-screen tonal range.
- `game/assets/ui/title/orison_original_advert_lobby_v1.png` — period graphic
  restraint and building identity.
- `art/renders/weather_sky_t8/final/night/01_north_pavement.png` — shipped rain,
  roadway and middle-distance atmosphere.
- `art/renders/vantry_gateway_k0/weather/01_portal_front.png` — gateway language.
- `art/renders/passage_hours_ps6/after_night/01_movable_middle_layer.png` —
  Vantry Arcade material and warm shop light.

## Built-in ImageGen prompt

Create one 16:9 cinematic title-screen hero image for the first-person game
*Please Remain On The Line*. Synthesize the references into one physically
plausible waking-world night exterior. On the left, the real Orison apartment
building rises through hard rain and low cloud. The wet STREET crosses the
foreground. A historically plausible iron-and-glass transit entrance or service
kiosk stands near the curb with an off-hook Bakelite telephone and its cable.
At center, a solitary 1928 maintenance worker in practical dark work clothes
walks away from camera carrying a toolbox and paper work order. To the right,
the entrance to the Vantry Arcade glows with warm ordinary shop light beneath
its canopy; include a chained handcart as a small mundane detail. Compose these
real things with the scale, mystery and invitation of a grand-fantasy key art
painting, but without any magic. Use rain-slick reflections, soot-black masonry,
muted blue-black weather, amber windows and one cloud-obscured white sky glow.
Keep the right third dark and low-detail enough for title/menu typography. No
words, lettering, logos or UI. No dream world, monster, ghost, deity, magical
portal, cosmic sky, floating object, impossible geometry, gears, clock face,
steampunk machinery, castle, cathedral or Gothic fantasy ornament. The image
must feel like an epic journey into ordinary night work.

## Corrective edit prompt

Preserve the entire composition, worker, kiosk, telephone, street, rain, arcade,
lighting, palette and right-side negative space. Correct only the Orison: it is
exactly seven above-ground storeys, a broad and plausible 1912 Queens apartment
building with a flat parapet and restrained masonry cornice. Remove tower-like,
Gothic, castle and fantasy features. Keep it imposing through real urban scale,
not invented height or ornament. Do not add text or reveal any dream imagery.

## Selected output

The corrected image was generated with the built-in ImageGen tool and installed
as `game/assets/ui/title/orison_grand_mundane_title_v1.png`. Production framing
is proven by `art/renders/title_clockwork_theme/03_grand_mundane_original.png`
and `04_grand_mundane_return.png`.
