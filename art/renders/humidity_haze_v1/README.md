# Bounded humidity haze

Fixed production `04_roof_skyline`, forced clear day, seed `19280731`.
`dry` uses 0% simulated humidity; `saturated` uses 100%. Both retain zero
cloud and precipitation, so the pair isolates the normalized humidity term.

The change is deliberately quiet: normalized RGB RMSE is `0.00394955` whole
frame and `0.00520856` on the 1280x410 scenery crop. Saturation softens the
farthest facades while the near building, blue sky and window grid remain
legible. This is aerial humidity, not fog weather.

Production bounds enforce that distinction. Humidity below 72% adds nothing;
the full 72–100% range can add at most `0.08` to the authored fog multiplier.
Rain and WMO codes 45/48 retain the stronger extinction term. Temperature is
carried as a bounded fact but does not recolor the sky on its own.

No node, material, light, texture, volume, draw, gameplay or persistence owner
is added. `LiveWeatherServiceTest` proves normalization and simulation bounds;
`WeatherSkyTest` proves saturated clear air remains below true fog.
