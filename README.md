# Lily's Music Box (Mobile Edition) — Godot MVP

A mobile-first, portrait-oriented 2D top-down prototype focused on trap logic and persistent death remnants.

## Requirements
- Godot 4.2+ (tested with 4.x project format)
- No external assets required

## Run
1. Open Godot and import this folder.
2. Run the project (`F5`).
3. The game starts in the **Conservatory Hub**.

## Controls
### Mobile / Touch
- Drag on lower-left area for virtual D-pad movement.
- **Interact** (bottom-right): confirm room objective.
- **Inspect** (above Interact): inspect cups in Cup Choir.
- **Emote**: cosmetic placeholder.
- **Tap Move** toggle in Run scene enables tap-to-move.

### Desktop
- Mouse simulates touch input (click/drag).

## Gameplay Loop
- Hub -> Start Run -> 5 procedural rooms from weighted templates.
- Current MVP includes two trap templates:
  - **The Cup Choir**: inspect cups, pick the pure tone, interact to clear.
  - **Laundry Orbit**: rotating safe window on a cycle; bad timing kills.
- Dying ends run and returns to Hub.

## Death Remnants
When a trap kills the player:
- A remnant record is persisted locally in `user://death_remnants.save` with:
  - room id + seed
  - death position
  - aura/style/pose/timestamp
- Starting another run can revisit the failed room first (same id/seed), showing remnants in-world.
- Remnants decay after `30` minutes by default.
- Use **Fast Decay** in Run scene to accelerate decay for debugging.

## Mansion Rewire
Escaping all 5 rooms triggers local “server-like” rewire:
- `rewire_count` increments
- room template weights shuffle
- hub chime message updates

State is stored in `user://mansion_state.save`.

## Project Structure
- `project.godot` — project + autoload singletons
- `scripts/server_api.gd` — server abstraction stub (run lifecycle)
- `scripts/death_remnant_store.gd` — persistence + decay
- `scripts/mansion_state_store.gd` — rewire persistence
- `scripts/profile_store.gd` + `data/player_profile.gd` — avatar data
- `scripts/run.gd` / `scenes/Run.tscn` — run orchestration
- `scripts/hub.gd` / `scenes/Hub.tscn` — conservatory hub
- `scripts/rooms/*` + `scenes/rooms/*` — room templates

## Add a New Room Template
1. Create `scripts/rooms/my_room.gd` extending `RoomBase`.
2. Implement:
   - `on_player_inspect()`
   - `on_player_interact()`
   - emit `player_died(position)` or `room_cleared`.
3. Create `scenes/rooms/MyRoom.tscn` with the script.
4. Register in `scripts/run.gd` `room_scene_map` and in `ServerAPI` room choices/weights.

## Acceptance Test Checklist
- Start Run enters room 1.
- Trap death returns to Hub.
- Re-running revisits failed room id/seed and shows remnant.
- Remnants decay with debug fast decay.
- Escaping all 5 rooms rewires mansion and updates hub counter/message.
