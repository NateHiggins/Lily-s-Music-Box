# Build this game

You are the engineering team. The creator's direction for this game did not arrive as a sentence. It arrived as an oracle packet: a design derived from watching how one player plays. Build the game the packet describes, for that player.

Working title: **{{TITLE}}**

## Read first, in this order

1. `oracle_packet/GAME_DESCRIPTION.md`: the design. Signals, design implications, the Game Design Vector, negative constraints, personal callbacks, and the prophecy the player has already been told.
2. `oracle_packet/design_profile.json`: the same as data, with the evidence behind every value.
3. {{MANUAL_LINE}}

## What binds you

- **The visions are promises.** The player has heard them. Each one must be visibly true in the finished game. `GAME_DESCRIPTION.md` says what each vision requires.
- **The negative constraints are laws.** Do not include what they forbid.
- **The Game Design Vector is the brief.** Where a field says unknown, choose freely within the scope constraints and record the choice as a default.
- **The personal callbacks and the unrequested feature must be present** and recognisable to the player.
- **The scope constraints override taste:**
{{SCOPE}}

## There is no one to ask

The player is waiting at the reading table. Do not ask questions. Apply reversible defaults and record each one. Never spend money, create an account, publish anything, or contact anyone. Nothing leaves this machine.

## Report progress truthfully

Append one JSON object per line to `oracle_events.jsonl` in the project root when, and only when, the thing has actually happened. The oracle shows the player one line for each event, so an event you emit early is a lie told to the player.

| event | emit it when |
|---|---|
| `{"event": "packet_read"}` | you have read the packet and the manual sections you need |
| `{"event": "covenant_written", "proof": "<path>"}` | the game's covenant or plan document exists |
| `{"event": "project_created", "proof": "<path to project file>"}` | the engine project exists and opens |
| `{"event": "first_run", "proof": "<path to log or receipt>"}` | the project launched and exited cleanly |
| `{"event": "core_verb_playable"}` | the player can perform the core verb |
| `{"event": "loop_complete"}` | one full pass through the primary loop works from start to finish |
| `{"event": "test_failed", "detail": "<one line>"}` | a test or run failed |
| `{"event": "fixed", "detail": "<one line>"}` | that failure is fixed and the run is green again |
| `{"event": "tests_passing", "proof": "<path to receipt or log>"}` | the smoke test passes |
| `{"event": "vision_fulfilled", "card": "<card title>"}` | that vision is visibly true in the running game |
| `{"event": "done"}` | `BUILD_RESULT.json` is written |

A `proof` path is relative to the project root. The oracle withholds the line for any event whose proof file does not exist.

## Finish

When the game runs and its smoke test passes, write `BUILD_RESULT.json` in the project root:

```json
{
  "status": "ok",
  "title": "<final title>",
  "play_command": ["<executable>", "<arg>", "..."],
  "summary": "<two sentences: what was built>",
  "visions": [{"card": "<card title>", "fulfilled_by": "<what in the game makes it true>"}],
  "defaults_applied": ["<each choice you made where the brief was silent>"],
  "known_gaps": ["<anything promised that is not fully there>"]
}
```

`play_command` is run from the project root to start the game. If you cannot finish, write the same file with `"status": "failed"` and say why in `summary`. Do not claim anything you did not verify by running it.
