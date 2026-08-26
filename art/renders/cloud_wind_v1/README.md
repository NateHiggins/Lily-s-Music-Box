# Observed-wind cloud advection

Fixed `04_roof_skyline` production camera, forced night, scattered preset,
seed `19280731`. Each directory is a four-second same-process pair captured
through the serialized Godot runner.

- `southwest_10kmh` uses the preset's 225° meteorological bearing and 10 km/h.
  Sky-crop normalized RMSE after four seconds: `0.00189354`.
- `from_east_37_5kmh` uses the public simulation overrides (90°, 37.5 km/h).
  Sky-crop normalized RMSE after four seconds: `0.00772462`.

The 3.75× wind speed produces 4.08× measured image motion. The small remainder
is expected from the deliberately slower opposed field evolution and raster
sampling. Buildings remain fixed; whole-frame RMSE for the 37.5 km/h pair is
`0.00523175`.

Direction is priced by the production contract rather than inferred from two
still frames: meteorological bearings are “comes from,” so 0° maps to Godot
south (`Vector3.BACK`) and 90° maps west (`Vector3.LEFT`). The focused test
asserts both mappings, and the simulator wraps 450° to 90° before publication.

The shader derives angular travel from a roughly 2.3 km cloud base
(`0.00012 rad/s` per km/h). It adds no texture, node, volume or draw call; the
existing lower cloud evaluation receives the weather owner's normalized vector
and bounded speed.
