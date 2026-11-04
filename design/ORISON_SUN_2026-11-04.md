# The Sun, the Moon by day, the eclipse and the Star God

Evidence class: **INERT**

Date: 2026-11-04. Branch `claude/sun`. This is a report of what was built and why. Runtime proof comes only from the
review receipts named under Verification.

## Source and rulings

A pasted brief (parts 13 and 14 of the sky-engine series) asked for a physically modelled Sun. It is input, not
authority (**design/ORISON_STYLE_DIRECTIVE_INTEGRATION_RULING_2026-08-29.md**). Lily ruled each piece on
2026-11-04, and the rulings are in `~/homebrew-tools/data/rulings.json`:

| Ruling | Answer |
|---|---|
| `sun_naked_eye` | All four: horizon flattening, light from the Sun, seasonal coal smoke, limb darkening |
| `sun_telescope` | Build the magnified Sun now and review it on the optical bench |
| `sun_star_god` | As the brief has it. The Bible amendment is in §VIII.5, before VIII.6 |
| `sun_eclipse_day` | 1 November 1929. The real annular eclipse over West Africa is total over Queens |
| `sun_two_events` | Both happen. The Emergence stays on 12 October |
| `sun_eclipse_moon_size` | Giant, compressed. The grown Moon's disc, sped up so totality is about ten minutes |
| `sun_storms` | Tie the storm to the existing aurora: radio static and more trolley arcs |
| (message) | The Sun and the Moon can share the sky all year |

What was already there and is unchanged:
- **Sun position** from a real ephemeris (`celestial_ephemeris.gd`).
- **The scheduled solar optics:** halos, sun dogs, arcs, crepuscular rays, the green flash and rainbows
  (`data/weather/phenomena.json`).
- **The year's two real lunar eclipses.**

## Naked-eye Sun

`scripts/building/solar_optics.gd` is the arithmetic:
- Bennett refraction.
- Kasten and Young air mass.
- Rayleigh optical depth, plus an Angstrom aerosol whose beta and alpha follow the month, the hour and the humidity:
  - Coal smoke from October to April peaks at the morning and evening firing, and is fine, so it reddens.
  - Summer haze is coarse and whitens.
  - Spring air is rain-washed; autumn is the clearest.

The director (`day_night_director.gd`) uses it in four ways:
- **Sunlight:** the key light's colour and strength now follow the Sun's real height and that air, with the
  noon keyframe as the white point. The clock-minute keyframes keep the night and twilight.
- **Refraction:** the Sun's drawn direction is lifted by refraction. This applies to the telescope-rate update too.
- **Shadows:** the light's angular size is the Sun's half degree, widened by haze, which softens the shadows.
- **The disc:** squash, sun colour, air and glare are published to the sky.

In `queens_weather_sky.gdshader` the Sun is now a disc of its own:
- squashed by the refraction difference between its limbs (about 0.8 at the horizon)
- limb-darkened (u = 0.6)
- reddened and dimmed from the bottom up by the extra air below its centre

With `sun_flatten` left at 0, as in V1 and forced showcase states, the old round core is drawn.

## Telescope Sun

`shaders/skywatch_sun.gdshaderinc` and `scripts/building/solar_surface.gd` only resolve in fields narrower than
about 3°:
- **Granulation:** cellular noise, about 650 cells across a radius, re-forming over minutes.
- **Sunspots:** generated for each day of the campaign at the end of solar cycle 16's maximum, about seven groups
  alive at once, riding differential rotation. Each has an umbra, a radially filamented penumbra and faculae toward
  the limb.
- **Prominences:** H-alpha loops just past the limb.

## The Moon by day

The sky used to draw one source: the Sun by day, the Moon by night. By day the Moon is now also drawn: its sunlit
side only, at its grown size, pale against the sky. On every day but 1 November 1929 the Sun is drawn over it, so
the grown Moon never eclipses the Sun at the other new moons.

## The eclipse and the Star God

`scripts/building/star_god.gd` is a pure function of the campaign clock, like the Moon's size. The schedule
test checks that it agrees with the `star_god` occurrence in `data/weather/phenomena.json`, which carries the
next morning's newspaper copy.

The eclipse is a grazing one. The Sun passes just inside the giant disc's edge, so the corona shows past the limb
and the figure is seen leaving the Sun.

- **Baily's beads** come from the measured lunar limb (LOLA heights at the limb, at the grown Moon's scale).
- **The light** dims by the share of the Sun still showing, the stars come out in totality, and the director
  relights every frame while the event runs.
- **Phase A:** the day's spots drift into an eye, and waves ring across the Sun's face.
- **Phase B:** the figure grows out of the Sun on the side away from the Moon and leaves the rift.
- **Phase C:** it climbs to 42°, bending the image behind it (`star_god_lens.gd`, a point-mass lens on the mirage
  effect's compositor), then thins to a line and leaves one chromatic ring.
- **That night** the sky glows violet.

## Aurora nights

`scripts/audio/geomagnetic_static.gd` puts generated hiss, crackle and the odd falling whistler on the ghost radio
while the aurora or STEVE shows.

**Not built: trolley arcs.** V2's street has no trams or trolley wire, so there are no arcs to increase. Adding
trolleys is street work in the city lane; that question is Lily's.

## Verification

Runs are in `C:/ov/reports/sun/runs/`; renders are in `C:/ov/reports/sun/shots*`. The sun review
(`SKYWATCH_SUN_REVIEW=1` on `V2SkySpectacleBench`) renders each season at noon, at 6° and at 0.5°, in 60°, 3°, 0.5°
and 0.12° views. The eclipse review renders the event's phases.

Not yet done:
- The surface packet renewal that any sky change needs.
- The composed-world performance of the daytime Moon pass.
- The lens on a real camera.
