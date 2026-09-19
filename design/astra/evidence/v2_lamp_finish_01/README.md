# V2 flashlight tuning and composed validation

Continuation of `f42e055`. V2 now uses base energy 1.5, a 0.018 m light aperture, and nearly neutral scattering albedo. The lamp's thermal spectrum supplies the warmth once. The V1 presentation is unchanged. Existing controller, voxel dimensions, fog density/detail, ecological field and save behavior are unchanged.

Final `OrisonV2LampReview` passes 32 checks with empty stderr. `repair_route.log` passes the existing 73-waypoint actual-input complaint/inspection/procurement/repair route with empty stderr. These are scoped proofs, not full V2 completion.

## Review

`final/thermal_state.json` records a fresh controller advanced exactly two seconds, held steady while capturing energy variants. The carried-device pose is also frozen. `frozen/` was the initial comparison; `tuned/` added the production changes; `final/` adds direct injection timing. Room fixture personalities still evolve between beauty captures, so the room-lit variants establish appearance, not strict pixelwise equality. The lamp-only variants hold the relevant lamp state and camera steady.

The 1.5 output improves the nearby desk/floor read while the room pendant remains the dominant source in the lit-room view. The 2.4 and 4.2 alternatives remain review-only. Clear/cast/clear blocker views visibly remove illumination behind the blocker. Native scene shadows supply mesh occlusion to the engine's volumetric lighting; the custom optical field is not a whole-building geometry voxelization.

## Timing

`final/injection_profile.json` forces 180 fixed-pose injections in the composed world, conservatively paying injection even when a stationary lamp could skip it. All units below are microseconds.

| Work | Count | Median | p95 | Max |
| --- | ---: | ---: | ---: | ---: |
| GPU compute | 178 | 19.744 | 43.296 | 60.608 |
| CPU construction | 180 | 20 | 26 | 32 |
| CPU submission | 180 | 12 | 17 | 32 |

The whole-viewport ABBA samples remain variable even after freezing world simulation. No reliable total-effect overhead claim is made from them. Direct compute timing does not cover fog composition, particles, shadows, or all material costs.

## Scope still open

This finishes the current base-beam tuning pass, not all requested optical work. Human visual acceptance, stable whole-effect performance, and cellular/transparent/SSS material integration remain open. Native PBR already lights ordinary composed opaque surfaces; the isolated lab receiver is not blindly substituted into production because its custom light path does not preserve the scene's ordinary multi-light/shadow behavior. Full V2 golden shift, embodiment and default-cutover gates remain open.
