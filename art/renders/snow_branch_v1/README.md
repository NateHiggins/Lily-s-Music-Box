# Snow branch v1

`day/04_roof_skyline.png` is a production `WeatherSkyShot` capture with
`WEATHER_SIMULATE=snow`. It proves the frozen branch in the same exterior
station used by the clear/cloud/weather sheets.

The authored snow preset carries no liquid precipitation. `WeatherFX` therefore
turns off both rain batches while its existing player-following, exposure-gated
snow owner emits. Mixed live observations may still carry both branches.

The flake field deliberately spans a broad scale range: numerous small flakes
retain depth against the skyline while a few near-camera flakes establish
parallax. A soft radial alpha replaces square particle cards. No new weather
owner, light, collision, persistence field, or draw branch was added.

Focused quantitative proofs live in `LiveWeatherServiceTest` and
`WeatherSkyTest`: pure simulated snow has positive frozen and general
precipitation, zero liquid precipitation and no wet-ground claim; outdoors it
emits snow with both rain branches off, and indoors all three precipitation
branches suppress through the same building exposure query.
