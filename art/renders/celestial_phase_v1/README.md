# Celestial phase production-shader proof

This is an observational evidence pair, not a player-view composition. It
uses the production `NightSkyHalfDome`, the production projected-sphere lunar
terminator and the production 0.27-degree angular radius. The proof camera is
declared at an 8-degree vertical field of view so the approximately
0.54-degree Moon can be inspected without making the Moon itself larger.

The deterministic `clear` weather simulation is selected before normal
building assembly. The scene then freezes the time and light owners. Frames
`full_control_a` and `full_control_b` use a Sun direction opposite the Moon;
`crescent_final` changes only the Sun direction and matching halo illumination
to the 15%-illuminated geometry.

Measurements over the whole 1280x720 frame:

- control A versus control B: SHA-256 byte-identical; RMSE `0.000000`
- control B versus crescent: normalized RMSE `0.164651`

The magnified soft background stars come from observing the 4K panorama
through this narrow proof lens. They are not representative of the player's
72-degree camera. The argument priced here is only the lunar disc: a stable
full circle becomes a geometrically lit crescent above a zero renderer floor.

Capture contract:

```powershell
$env:CELESTIAL_PHASE_PAIR='1'
$env:SHOT_STATION='04_roof_skyline'
tools/run_godot_serial.ps1 -Scene 'res://tests/WeatherSkyShot.tscn' `
  -ShotDir '<absolute output directory>' -Windowed -TimeoutSeconds 60
```
