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

`CelestialEphemerisTest` proves calendar epoch, sidereal angle, equinox solar
geometry, observer dependence, lunar normalization and sidereal-day closure.
`WeatherSkyTest` proves the integrated shader and production ownership.
