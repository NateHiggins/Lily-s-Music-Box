# GameBoot coupling census — 2026-08-27

**Milestone:** K0-ENGINE extraction falsifier. **Checkpoint:** `6582859`.
**Method:** static source census; Godot was not run.

## Ruling

The old 54-file `GameBoot` reference count overstated singleton coupling by
roughly four times. At this checkpoint:

- 54 scripts contain the word `GameBoot`;
- one is `game_boot.gd` itself and one is a comment-only mention;
- 52 scripts contain executable external member references;
- 35 use only the pure static coordinate helper `GameBoot.b2g()`;
- four more use only the pure static environment helper
  `GameBoot.developer_overlays_enabled()`;
- **13 scripts actually consume singleton state or behavior**; one of those
  (`building_root.gd`) also calls `b2g()`.

Therefore 54 was a lexical upper bound, not a dependency count. The measured
runtime-singleton coupling surface is 13 files. This weakens the extraction
boundary's quantitative coupling claim, but does not make `GameBoot` portable:
the remaining consumers still bind settings, launch mode, scene transition,
audio application and settings persistence to one Orison autoload.

## Classification

| Class | Files | Meaning |
| --- | ---: | --- |
| `b2g()` only | 35 | Static conversion from authored building coordinates to Godot coordinates; no singleton state |
| `developer_overlays_enabled()` only | 4 | Static OS-feature/environment query; no singleton state |
| Singleton state/behavior (including mixed helper use) | 13 | Genuine dependency on settings, launch mode, game start, audio application or settings write |
| Comment/self | 2 | Not an external dependency |

The 13 genuine consumers are:

- `audio/audio_policy.gd`;
- `building/building_root.gd`;
- `building/day_night_director.gd`;
- `building/live_weather_service.gd`;
- `dream/campaign_shell.gd`;
- `dream/dream_caption_layer.gd`;
- `dream/dream_director.gd`;
- `dream/sleep_pressure_director.gd`;
- `player/player_controller.gd`;
- `songbook/mic_recorder.gd`;
- `ui/audio_caption_layer.gd`;
- `ui/pause_services.gd`;
- `ui/title_screen.gd`.

## What the number does and does not say

`b2g()` is product-shaped vocabulary in the wrong owner, but not autoload
coupling. Moving it would improve naming and ownership without changing a
runtime dependency. The developer-overlay helper is similarly a static policy
query. Neither justifies extracting or refactoring production code before the
Early Access gates.

The 13-file surface is still heterogeneous:

- UI owns editing and persistence of user settings;
- player, captions, weather and day/night read settings;
- campaign/dream owners read launch mode;
- audio policy calls back into GameBoot's bus-setting behavior;
- title screen requests scene transition through `begin_game()`.

Those are several contracts sharing an autoload, not one reusable service.
Extraction should first name inputs at consumer seams; it should not package
the singleton wholesale.

## Reproduction

Enumerate scripts, then extract unique `GameBoot.<member>` uses per file. A
file belongs to the first class only when its unique member set is exactly
`GameBoot.b2g`; it belongs to the second only when that set is exactly
`GameBoot.developer_overlays_enabled`. Exclude `game_boot.gd` and the
comment-only `touch_controls.gd` entry. All remaining files are genuine or
mixed singleton consumers.

## Limitations and falsifiers

- This is a member-reference census, not a dynamic call graph.
- Aliases or `get_node("/root/GameBoot")` lookups would escape the method; none
  was found in this pass.
- A consumer may touch only one setting and still count as one coupled file;
  the number measures breadth, not rewrite cost.
- The ruling changes if `b2g()` or `developer_overlays_enabled()` begins reading
  singleton state, or if dynamic consumers are discovered.

No production refactor is recommended before K2. The immediate ledger value is
the corrected denominator: future extraction estimates should say **13 genuine
singleton consumers**, not 54 `GameBoot` references.
