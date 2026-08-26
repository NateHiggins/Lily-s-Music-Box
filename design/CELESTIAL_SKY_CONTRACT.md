# Celestial sky contract

The building remains 1928. The sky is the real sky above the observer now.

`CelestialEphemeris` accepts UTC and explicit latitude/longitude. It performs
no network request and discovers no location. `LiveWeatherService` remains the
only owner of the player's opt-in location choice; Queens is the fallback.

The solar solution follows the NOAA solar-position model. Star rotation uses
the U.S. Naval Observatory's Greenwich mean sidereal-time expression from
Circular 179. The lunar disc uses a compact continuously evaluated orbital
solution suitable for a visual sky, not navigation. If navigational lunar
accuracy ever becomes a requirement, replace that one calculation with a
baked JPL DE/Horizons table while preserving the same direction API.

The Moon is not a painted circle. Its illuminated fraction is derived from
the angular separation of the evaluated Sun and Moon directions, and the sky
shader projects the solar direction onto a sphere to draw the terminator. In
production the disc keeps the Moon's approximately 0.54-degree apparent
diameter; forced showcase hours retain the older enlarged disc only so their
existing composition remains deterministic. The halo fades with illuminated
fraction, while cloud extinction still owns whether either body can be seen.
This is an astronomical visual model: it correctly distinguishes new,
quarter and full geometry, but does not model libration, topography, eclipses
or atmospheric refraction at the horizon.

The disc's geography comes from NASA SVS's 1024x512 LROC WAC color mosaic,
mapped cylindrically onto that projected sphere with lunar north upright and
the measured near side centered. At naked-eye scale its mip chain becomes a
very small cached sample; the source resolution is intentionally modest.
Because this visual ephemeris does not yet evaluate optical libration, the
surface orientation remains stable rather than pretending to an accuracy the
direction solution does not own.

Twelve bright catalog stars are evaluated as observer-relative directions and
drawn inside the existing half-dome shader. They add no submission, light or
shadow caster. The same authored and live cloud thickness that hides the sun
and moon also hides the stars. This avoids the familiar failure where stars
shine through an overcast sky.

Forced test hours retain the authored deterministic source direction.
Production uses the real UTC instant: the sun is the visible source through
twilight, then the moon. The existing four 4K Orison panoramas remain the
foundation and do not rotate with the stars.

Primary numerical references:

- NOAA Global Monitoring Laboratory, Solar Calculator calculation details:
  https://gml.noaa.gov/grad/solcalc/calcdetails.html
- U.S. Naval Observatory, Computing Approximate Sidereal Time:
  https://aa.usno.navy.mil/faq/GAST
- JPL Solar System Dynamics, ephemerides and Horizons guidance:
  https://ssd.jpl.nasa.gov/planets/orbits.html
- JPL Horizons manual, phase angle and illuminated-fraction geometry:
  https://ssd.jpl.nasa.gov/horizons/manual.html
- U.S. Naval Observatory, primary Moon phases (including the 2023-01-06 full
  Moon and 2023-01-21 new Moon numerical test references):
  https://aa.usno.navy.mil/calculated/moon/phases?date=2022-07-12&format=p&nump=50&submit=Get+Data
- NASA Scientific Visualization Studio, CGI Moon Kit and LROC WAC color map:
  https://svs.gsfc.nasa.gov/4720

`CelestialEphemerisTest` proves calendar epoch, sidereal angle, equinox solar
geometry, observer dependence, lunar normalization, the published full/new
phase instants and sidereal-day closure.
`WeatherSkyTest` proves the integrated shader and production ownership.
