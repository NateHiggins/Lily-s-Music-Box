# Visibility transition phase attribution

Prepared from the exact retained `candidate_v1_foundations_01` root and fixture. No live source was changed by preparation and no engine result is claimed here. The sibling preparation JSON binds both original and diagnostic bytes.

The completed candidate's Street/Passage crossings take roughly 610–622 ms synchronously. The completed helper-only omission also stalls, so removing the same-scenario renderer workaround does not resolve this cost. Native error logging makes the omission unsuitable for an isolated measurement of helper overhead.

This diagnostic patch keeps all production calls and all existing functional assertions. It records broad Street/Passage indexing, owner mutation, SurfacePass plus its callbacks, each callback, and individual render-mask operations in the existing transition receipt. It introduces no skipped work, new cache, disabled actor, renderer change or shipping optimization.

The source review gives one hypothesis to test: `SurfacePass.apply_props` invokes its callback whenever cumulative `props_swapped` is positive, including sweeps with no new swaps. `ApartmentEncroachment.reach_props` walks every mesh once per unit and rebuilds material/state records, while `OrganismIncidents.attach_props` rebuilds appliance indices and rearms persisted incidents. None of these facts establishes their measured cost. Simply suppressing the callback without tracking late appliances/material replacements could lose consumers and is not proposed.

The instrument's per-mask timers and dictionary writes add overhead. Use it to locate major costs and check parent/child timing consistency; do not use this run to claim shipping frame time. The final optimization, if one is needed, must be measured again without diagnostic instrumentation and must preserve late-build, governor, owner/material, incident and reconstruction behavior.

The exclusive engine owner must apply the two named files only after checking the original hashes, use the existing serial runner and actual composed fixture, retain the diagnostic source and result, then restore both originals byte for byte in a `finally` transaction. The selected scope must remain explicit. This preparation grants no new exception for native errors, incomplete retirement or missing captures.
