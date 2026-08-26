# Physical neighbour facade grid

Fixed production `04_roof_skyline` camera, clear public simulation preset,
seed `19280731`. `day` and `night` are accepted claim frames.

Controls are the pre-change plates at
`../cloud_light_v1/clear_day/04_roof_skyline.png` and
`../cloud_direction_v1/clear_night/04_roof_skyline.png`. The 1280x410 scenery
crop changes by normalized RMSE `0.0647824` in day and `0.0445641` at night.

The old shader stamped every envelope with seven bays and five storeys and
ignored the MultiMesh color already authored for that building. The claim
derives bay count from physical width at approximately 1.45 m and storey count
from height at approximately 2.70 m, within scenery-LOD clamps. Thus the center
frontage becomes a plausible 10-bay/3-storey face while adjacent envelopes keep
their own proportions. Recess, sash, glass and occupied emission still come
from the same window calculation, so a lit room cannot miss its opening.

Instance color is normalized for luminance before supplying a restrained hue
shift to both facade and side/rear mass. This breaks clone repetition without
inventing a second exposure value. Day occupancy remains exactly zero; the
night frame shows warm and cool rooms only inside the measured openings.

No mesh, instance, node, material owner, light, collision shape or draw call is
added. `WeatherSkyTest` verifies the persistent instance counts, one facade
calculation, stable room identity, physical extent path and existing ownership.
