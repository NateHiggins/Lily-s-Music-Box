Evidence class: INERT. Renewed source-shell discovery, not runtime acceptance.

The 1D furniture clearance changed the layout source binding while leaving wall
trim unchanged. A fresh windowed FrontTrimLayoutProbe run observed all 9085
instances identical to the committed discovery at 3c8f9bec. Only the layout
binding changes in the canonical source snapshot. The existing front trim tests
pass (5 tests); plan_v2_front_trim --check confirms the existing runtime plan is
unchanged: 20 rails, 22 cornices, 21 rooms, 154 spliced source instances.

The preceding headless attempt exited zero but exported identity transforms.
Its result was rejected, not installed. Logs and a bad example remain here.
The probe now explicitly refuses the headless backend. The subsequent windowed
run used that guard and completed successfully. No models or runtime trim moved.
The renderer-dependent data cannot be qualified from the headless run's exit.

The original failed candidate verification remains unchanged and historical.
The radiator collision fix was separately committed/pushed as 3c8f9bec, with
its actual-input hand and 1180-check composed diagnostic evidence in the radiator
collision_owner packet. Broader stale runtime/spatial/surface evidence, physical
radiator repair completion and final human appearance acceptance remain open.
