# Hail branch v1

`day/04_roof_skyline.png` is a production `WeatherSkyShot` capture with
`WEATHER_SIMULATE=hail_storm` (WMO 96). It is deliberately a mixed photograph:
the fine slanted rain curtain remains, while sparse brighter hard pellets cross
the near field at a much greater fall speed.

The hail field is one bounded `CPUParticles3D` child of the existing
`WeatherFX` owner: 220 maximum five-sided pellets, no shadow, collision,
light, persistence, or gameplay signal. It follows the player and observed
wind, and uses the same building-owned exterior and cover queries as rain and
snow. WMO 96/99 with zero measured precipitation emits nothing.

`LiveWeatherServiceTest` proves the WMO discriminator and measured-total gate.
`WeatherSkyTest` proves mixed hail/rain outdoors and suppression of every
player-following precipitation branch indoors.
