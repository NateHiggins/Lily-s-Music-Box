# Agency, knowledge and cinematic continuity

Use this for authored scenes inside playable space. An offline music video has
no player-input contract beyond its isolated fixture's restoration obligations.
Do not turn a film or documentation request into an unsolicited gameplay rewrite.

## Choose the least restrictive presentation

| Mode | View and control | Suitable purpose |
|---|---|---|
| Ambient vignette | Gameplay camera and full agency | Small environmental action, nearby resident business |
| Reactive performance | Existing view; bounded contextual gaze/framing only where supported | Companion or resident response |
| Interactive authored scene | Declared look/move/inspect/choice limits | Exchange or significant physical action |
| Full cutscene | Authored camera; declared skip/pause and recovery | Precisely synchronized reveal |
| Temporal transition | Presentation around an authoritative handoff | Existing prologue or earned visit transition |

Record move, look, interact, choose, skip, pause and replay permissions, timeout
behavior, reduced-motion behavior and save/load policy. Specify what happens if
the player leaves, looks away or ignores a prompt. Prefer sound, actor gaze,
light and visible movement before forcing camera aim. Slow-motion cues cannot
rewrite the campaign clock or timed obligations without the owning contract.

If a reveal matters, distinguish visible opportunity from witnessed knowledge.
Camera visibility alone cannot grant evidence. The existing observation or case
owner determines its prerequisites. Let optional performances coexist with
maintenance, reading and exploration; don't hold the player hostage to idle speech.

## Map authority before authoring events

Record the actual owner and supported API for each affected domain:

| Domain | What presentation may consume |
|---|---|
| Civil time, visit and elapsed clocks | Current snapshot and authorized transition result; their clocks remain distinct |
| Weather, wetness and light | Owner conditions and derived presentation; no invented global clock/weather writes |
| Papers and reading | Actual dated issue, content, physical carrier and custody |
| Case and resident knowledge | Earned/observable facts, branch predicates and what this speaker knows |
| Economy, inventory and saves | Validated transactions and their recorded result, never film-keyframe rewards |
| Dialogue and voice | Authored eligible line IDs/text, selected voice/audio, fallback and subtitle cues |
| Input, view, UI and audio | Explicit temporary ownership, prior state and supported restoration |

The established owner decides **when** a transaction commits. Don't migrate it
to scene entry or audio completion merely to simplify a timeline. Where a prior
validated transition token exists, show that result without committing it again.
Pure presentation needs no persistent transaction. The shipped game uses authored
lines and traditional rules/schedules, never runtime language-model decisions
(RUL-015).

In a loop, player memory and a resident's belief are different facts. Re-entry
rebuilds actors, clothing, issue, weather and light from current authority. Do
not restore an obsolete cinematic snapshot over a newer visit/save. Consult
[the NPC loop plan](../../../../design/NPC_LOOP_PERFORMANCE_PLAN_2026-11-12.md)
for implementation gaps; its proposals are not proof of installed systems.

## Completion, skip and recovery

Use the existing control coordinator with explicit preparing, running, finishing
and recovering states. Acquire only the needed authority after prerequisites
pass; handle failure after partial acquisition too.

- Define valid endpoints for normal completion, skip, cancellation, failure and
  reload. They may have different owner outcomes, but each must be intentional.
- Finishing is idempotent. Duplicate skip/finish events cannot duplicate rewards,
  fares, evidence, props or callbacks. Seeking to the last animation frame is not
  the completion contract; see [Godot guidance](godot-direction.md).
- Stop owned transient sounds, particles and presentation tracks. Return camera,
  cursor, input, UI, audio ducking and actor presentation through their owners.
- Restore only state this scene still owns. Don't overwrite another scene's
  newer control lease or legitimate world changes with a stale snapshot.
- Make exit placement safe and legible. Actual residents cannot jump between
  marks and gameplay positions without a staged or supported transition.
- Clear internal run state before notifying external completion listeners;
  a listener may immediately start another scene. Ignore late callbacks from
  the old run. Test this if the implementation permits chained sequences.

Support readable speaker-labelled subtitles, intentional silent responses,
adequate choice time and reduced motion/flash where appropriate. A required clue
cannot rely solely on colour, tiny focus changes or a forced fast camera turn.
Film capture at 24 fps does not cap gameplay rendering or physics to 24 fps.

## Preserve the actual prologue

The current authority is [Bible §VIII.5.p and amendments](../../../../design/ORISON_BIBLE.md),
with exact pacing in [the prologue ledger](../../../../design/V2_PROLOGUE_2026-10-28.md).
Inspect `game/scripts/game/prologue_director.gd`, `prologue_temporal_console.gd`,
`prologue_temporal_sky.gd` and `prologue_tardi_stinger.gd` before any change.

Preserve the physical aftermarket typing arm, keyboard clearance and exact final
connection line. The simulated privileged command never touches the OS. The
sampled local month/day/time maps into the authored annual loop, not a modern
calendar-year city. The later historical bedroom cutaway does not reset that
destination. Its friendly Tardi greets, waits and retreats: exactly 17 seconds,
black at 13.50, title at 14.00, end at 17.00, with no dialogue, music, threatening
behavior or extra reveal. The package's horror exercise cannot alter these beats.

This guide adds no prologue implementation or qualification claim. Follow the
current dated ruling if the owner later amends it.
