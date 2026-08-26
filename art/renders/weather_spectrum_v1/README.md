# Weather spectrum v1

Production roof-station captures from `WeatherSkyShot.tscn`. The camera, forced
time and building state are held constant; only `WEATHER_SIMULATE` changes.

- `clear_night/04_roof_skyline.png`: zero cloud, catalog stars and the authored
  Milky Way plate. Persistent neighbour envelopes survive F01 storey streaming.
- `overcast_night/04_roof_skyline.png`: 100% cloud and no precipitation. The
  dynamic deck becomes an optical ceiling rather than a tint over the stars.

The paired 1280x300 upper-sky crop measures mean/standard deviation
0.146018/0.102378 clear and 0.100917/0.007167 overcast. The low overcast
deviation is the claim: the star field has been occluded, not recolored. Pair
whole-frame RMSE is 0.072941; upper-sky RMSE is 0.107278.

Neighbour windows are generated in the same facade calculation as their
recesses. A deterministic occupancy mask selects a minority of rooms and varies
warm tungsten against occasional cooler service light. Legacy `site_lights`
cards remain only as non-emissive compatibility geometry, preventing detached
lights and double exposure.

Rejected during development: no envelope at roof height (floating lights),
coplanar facades (partially missing walls), pale blockout masses, a second
synthetic window grid behind unrelated authored light cards, clipped white
rooms, void-black side masonry, and transparent overcast that left the Milky
Way visible.
