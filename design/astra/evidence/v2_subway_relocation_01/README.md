# Subway entrance outside the arcade

Owner request: move the subway entrance out of the arcade building. Continuation of `2064e5d`.

The complete authored kiosk now sits along the opposite sidewalk, centered at world `(2.5, 0, 16)` and rotated 90 degrees. Its plan bounds are approximately `x=-0.225..5.225, z=15.175..16.825`. The arcade building line is `z=18.521`; the kiosk is also clear of its projecting entrance piers. The original source kiosk straddled that building line and extended inside the shops.

The six affected imported material/collision meshes retain their materials, UVs and triangle topology. Selected positions and normals are transformed together into a dedicated 173 KB buffer. Unselected triangle vertices are asserted unchanged; shared boundary vertices are refused. Source kiosk records extend up to 3.71 m, including the small peak pieces. The V1 source files remain unchanged. Generation is byte-repeatable.

The sidewalk is split around the real stair opening while retaining its outer bounds. The original closed gate remains closed and collidable. This does not add an accessible subway station or change its authored closure.

## Validation

- `route_05.log`: 18 continuous player-input waypoints, zero failures, empty stderr. Walk around both long sides, check the real treads through the pavement opening and gate collision, then approach the arcade through its clear entrance.
- `overview.log`: clean daylight spatial capture, showing the separate kiosk and arcade. See `overview/subway_and_arcade.png`.
- `../v2_earned_conversation_01/route_02.log`: full 76-waypoint complaint, inspection, hardware purchase, return, repair and earned conversation passes on the relocated geometry; empty stderr.
- Final import log is `import_05.log`, with empty stderr.

Earlier evidence is retained. The first route fixture lacked its inherited capture helper and was stopped after the parse failure. The next incorrectly tried to walk through the authored locked gate. A subsequent location exposed an arcade-pier pinch point; the final location avoids it. `route_04` passed before the source audit brought the remaining roof peak pieces along; `route_05` covers the complete final geometry.

Full V2, station gameplay, surrounding street finish, and optical/human/performance acceptance remain separate open work.
