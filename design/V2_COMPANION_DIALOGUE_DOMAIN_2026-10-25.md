# Companion offline dialogue corrections

Evidence class: **INERT**. Domain diagnostic, not gameplay acceptance.

The isolated conversation domain now resolves the longest specific object
name before a generic alias: asking about the hot valve does not also select
the cold valve merely because both accept **valve**. A fresh explicit command
clears a pending clarification. Memory counters remain bounded at 64 entries.
The restored branch test now expects the actual next stage of the authored
four-stage conversation rather than an obsolete two-stage response.

The original **offline_v1** failure is retained. The serial **offline_v2** run
completed all 31 checks in 0.49 seconds with zero script errors and failures.
Its test-written **conversation_diagnostic.json**, raw stdout/stderr and wrapper
receipt are archived under **art/reviews/v2_companion_20261024/offline_v2/**.
The wrapper receipt proves execution; neither it nor this explicitly INERT
diagnostic grants a runtime contract or promotes completeness requirements.

The domain remains isolated. Actual physical keyboard input, controller focus,
authoritative world context, game-save integration, autonomous movement and
occupied-world performance qualification remain open in the companion work.
