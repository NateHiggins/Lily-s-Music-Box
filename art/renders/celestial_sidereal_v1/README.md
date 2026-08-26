# Celestial sidereal production-shader proof

This same-process A/A/B pair proves that the measured Milky Way is celestial,
not attached to the Orison. It uses the production 4K ESO/S. Brunier
GigaGalaxy map, production `NightSkyHalfDome`, production skyline, clear
weather simulation and the player's 72-degree camera.

The controls evaluate Queens (40.75 N, 73.92 W) at 2026-08-26 02:00 UTC. The
final frame changes only the J2000 equatorial basis to 08:00 UTC. The shader
then applies its IAU equatorial-to-Galactic rotation before sampling the same
unchanged texture. Buildings, camera, weather, map and material remain fixed.

Measurements over the complete 1280x720 frame:

- control A versus control B: SHA-256 byte-identical; RMSE `0.000000`
- control B versus plus six hours: normalized RMSE `0.0911272`

The first frame places the Galactic Centre and dust lanes above the skyline;
six sidereal hours later that region has set outside this view while the rest
of the measured star field crosses it. A zero control floor prices the motion.

Source and limitation details live beside the texture in
`eso_gigagalaxy_galactic_half_dome_4k.source.md`. In particular, ESO notes
that its multi-month photographic composite retains a few bright planets.

Capture contract:

```powershell
$env:CELESTIAL_SIDEREAL_PAIR='1'
$env:SHOT_STATION='04_roof_skyline'
tools/run_godot_serial.ps1 -Scene 'res://tests/WeatherSkyShot.tscn' `
  -ShotDir '<absolute output directory>' -Windowed -TimeoutSeconds 60
```
