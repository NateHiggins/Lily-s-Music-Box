# Dream onset — production contract

*Landed as N5 on 2026-08-15. The ruled experience and medical guardrails remain
in `design/ORISON_MAZE_BRIEF.md`; this file describes the runtime that exists.*

## Scope

`SleepPressureDirector` is the sole production caller of
`DreamDirector.enter_armed_dream()`. It converts an already-earned `armed`
request into one deterministic warning and entry. It owns timing, protection
and physical safety only. It does not decide case eligibility, change a job or
case, build the maze, run the Tenant, author a hazard or provide a cure.

Mina's first profile is `mina_release_print` in
`game/data/dream_profiles.json`. It permits only `gradual`, lasting 2.60
seconds. The generic policy also accepts later profiles that list `sudden`;
their form is selected once from the exact campaign seed. It is never rerolled
during play. **Always warn before sleep** forces `gradual` and is persisted with
the other title-screen settings. Profile validation rejects any future record
that does not include a gradual form, so accessibility cannot silently degrade.

## Owner graph

```text
CoreLoopDirector --eligible request--> DreamDirector --armed fact-->
SleepPressureDirector --one safe entry call--> DreamDirector

Safety answers (read-only):
PlayerController  -> stable body / real floor
OrisonElevator    -> cabin and landing threshold volume
StreetTraffic     -> permanent authored carriageway
call_locked       -> existing engaged/protected interaction authority
```

The sleep owner contains no copies of lift geometry or traffic vehicle state.
Those world owners answer narrow `blocks_sleep_entry(position)` queries.
`PlayerController.sleep_entry_body_is_stable()` rejects noclip, a missing floor,
vertical motion, a road stagger and non-finite position. Horizontal movement,
running, crouching, input and ordinary interaction do not reduce pressure.

Protection and unsafe space pause the clock; they do not clear or decay it.
The current transient block reasons are `engaged`, `unstable_body`,
`elevator_seam`, `traffic` and `waking_world_unbound`. They are diagnostics, not
saved gameplay state.

## Saved facts

`RealityState.data.sleep_pressure` stores only:

| field | meaning |
|---|---|
| `onset_form` | the seed-selected or accessibility-forced form |
| `elapsed_s` | progress through that form's authored duration |
| `started` | whether the first safe warning frame has occurred |

Case, profile, window and seed stay in the N4 `dream` transaction and are not
duplicated here. The onset state is committed when armed, when it first starts,
at 0.5-second checkpoints and immediately before the `entered` commit. A
real-file restore reconstructs the exact warning progress without re-emitting
`onset_started`. An active dream clears the onset facts and presentation.

## Gradual presentation

One scalar drives four synchronized signs:

- a full-frame material lowers peripheral contrast and saturation while leaving
  the central working field legible;
- a temporary Master-bus low-pass moves from 20.5 kHz toward 3.6 kHz;
- the existing Room 0 mechanical hum rises from -60 dB toward -27 dB;
- the modeled service radiophone's look recovery lengthens, so its lamp answers
  late without becoming false or uncontrollable.

There is no forced head roll, FOV pulse, input seizure or cancellation verb.
The low-pass resource and OGG playback are explicitly removed when the
persistent campaign shell exits. Headless proofs exercise the same presentation
state without opening an inaudible OGG decoder.

## Proof

`SleepPressureTest.tscn` passes 20/20 deterministic checks. It holds the same
request through engagement, an unresolved fall, the elevator seam and the live
carriageway; reaches the exact 1.30/2.60-second midpoint; writes real JSON under
`user://tests`; destroys the shell and live campaign facts; reloads the exact
high-bit seed and midpoint; reconstructs presentation without a second warning;
and enters one exclusive dream world exactly once. The test also proves a
dual-form seeded choice and the Always-warn override.

`DreamBoundaryTest.tscn` now passes 36/36, adding direct checks against the real
production carriageway and elevator geometry while retaining every N4
transaction check. `SleepOnsetShot.tscn` is the production-camera A/A/B/C in
`art/renders/dream_onset_n5/README.md`: midpoint affects 27.52% of pixels and
late warning 41.75% against a 0.16% live-frame floor.

Regression proof: TitleScreenTest PASS; ServiceSetTest PASS; CoreLoopTest 28/28;
MaintenanceCounter PASS; GoldenLoopTest 87/87 in 38.2 seconds; WalkTest FULL at
x8/480 Hz PASS in 47.4 seconds. One Godot instance ran at a time under the
60-second bound.

## Deliberately deferred

`DreamMazeRoot` remains an N4 D00 boundary payload. N5 adds no Tenant, borrowed
silhouette, navigation body, maze geometry or hazard. Those begin with N6 and
must preserve this entry owner and N4's exclusive-world transaction.
