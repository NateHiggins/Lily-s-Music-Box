# V2 continuous first physical repair

`route_02.log` passes 67 continuous player-controller waypoints with empty stderr. Starting inside V2, the player climbs to 2A, inspects the actual listening head, descends, crosses the street, enters the arcade/hardware shop, buys the diagnosed capsule through the real counter, returns to 2A and repairs the same head through ordinary input. The head stops chirping; the purchased capsule is consumed; WorkOrders records a good repair; Mina receives exactly one temporary stabilization and the core loop reaches conversation_pending. The inherited procurement fixture now has a preparation hook; this route overrides it to require the actually diagnosed job and never reseeds its evidence.

The complaint uses the public case owner and authored dialogue rather than a physical resident encounter. This proves the first maintenance route, not the complete golden shift. Physical Mina interaction, recurrence, manifestation and dream/wake remain open.

The first route stopped at an incorrect ground-level waypoint that still lay on the stairs. Its actual height was 0.636 m. The second route uses the established bottom landing. Geometry, capsule and movement limits were not changed; the failed log and capture remain in route_01.

Authority review exposed a real bypass: factual captions could make the calibrator grant the first stabilization before the transmitter had been repaired. The new control in MinaCaseGameplayTest fails exactly once in `guard_before.log`. The case owner now refuses initial calibration until the first physical repair has granted stabilization. `guard_after.log` passes the full existing case/dialogue/recurrence/integration suite with empty stderr, including that control. The correction changes no dialogue tree or durable save schema.

V2 remains unfinished and V1 remains default. Remaining work includes the full case sequence, finished apartments and controls, resident embodiment and movement, remaining floors, acoustic topology, resource/performance review and human acceptance.
