# Period reality weather v1

Production `WeatherSkyShot` roof proof for the CAM-19 mailwing detail. The
environment is forced to clear daytime weather. `PERIOD_AIRMAIL_PAIR=1` places
the flight at the deterministic 82% point of its real production path, freezes
the world and camera, captures two hidden-aircraft controls, then changes only
the existing mailwing's visibility for the final frame.

## Measurement

- whole-frame control A/B RMSE: `0.000200635`
- whole-frame control A/final RMSE: `0.00270453` (`13.48x` the floor)
- declared aircraft crop: `120x80+580+320`
- crop control A/B RMSE: `0.000000`
- crop control A/final RMSE: `0.0264044`

The scale is intentional. This is a rare, collisionless background fact seen
from a production player position, not a hero aircraft or an objective. Its
silhouette is readable against clear sky; live low cloud, fog and precipitation
attenuate it, and a closed ceiling suppresses the visible event entirely.
