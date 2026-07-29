# Architecture Summary

## The one rule

**Sounds are bodies. Motifs are ideas.** The codebase enforces this split:

- `MotifDefinition` (Resource) — the *idea*: timings, pitch contour, accents,
  which events are implied-but-absent, loop length, mutation tolerance. It
  knows nothing about audio.
- `TranslationProfile` (Resource) — one *body's* capabilities: what timbre it
  speaks with, how much pitch it can express, how accurately it holds time
  and dynamics, which bus (acoustic space) it lives in.
- `MotifRenderer` (Node) — the reusable interpreter. Given a definition and
  a profile it schedules events per loop, applies drift/omission/accent
  scaling/tempo/infection, triggers procedurally generated streams (or
  modulates a continuous drone for hum-type bodies), and emits signals.

Everything else — the support-call scene, the props, the UI — consumes
`MotifRenderer` signals and `GameState` signals. No object references
another object's internals to react to sound.

```
MotifDefinition ──┐
                  ├─► MotifRenderer ──► event_played / loop_started signals
TranslationProfile┘        │                    │
                           ▼                    ▼
                   per-source bus        lamp pulse, radiator shake,
                   (pan) ─► Room/        waveform pulses, notif light
                   Caller/UI bus ─► Master (limiter)
```

## State model

`GameState` (autoload) owns: `call_stage`, `is_noise_isolated`,
`motif_captured`, `current_route`, `radiator_infected`, `computer_infected`,
`room_infection_level`, `caller_infection_level`, `player_response`,
`motif_mutation`, `outcome_triggered` — and emits a signal for each
transition. The outcome is a **latch**: `try_commit_outcome()` accepts
exactly one response per run, so duplicate button presses, debug triggers,
or overlapping motif instances cannot fire a second ending. All transitions
print `[STATE] …` to the console.

## Audio topology

`AudioEnv` (autoload) builds buses in code at startup:

- **Master** — `AudioEffectLimiter` (−1 dB ceiling). Level safety lives here;
  all synthesized streams are also normalized to ~0.62 peak.
- **Room** — reverb. Physical sounds in the apartment (radiator, hum,
  routed speaker playback, the final knock).
- **Caller** — high-pass + low-pass + light overdrive: a phone line.
  (Breathing, murmur-voice, line static.)
- **UI** — dry. Interface sounds and headset monitoring.

Each `MotifRenderer` gets a private `src_*` bus carrying its stereo pan,
sending into its profile's shared bus. Re-routing the captured loop
(speakers → headset → room) is just `AudioServer.set_bus_send` on that one
bus — playback never stops or stacks.

## Scene sequencing

`main.gd` runs the staged call as coroutines guarded by a `run_id`: every
`await` re-checks the id, so **restart = increment the id and reset state**.
Orphaned coroutines from the previous run simply fall through. Skip-to-stage
replays the *real* input path (pressing the actual buttons) with delays
compressed, so debug skips can't reach states the player can't.

## The motif data model

`resources/motifs/incomplete_knock.tres`:

| field | value | meaning |
|---|---|---|
| `event_times` | 0.00, 0.22, 0.44, 0.92, **1.14** | five slots; the last is the implied answer |
| `accents` | 1.0, 0.55, 0.55, 0.85, 1.0 | relative strengths |
| `pitch_semitones` | 0, +3, +2, −2, 0 | contour, from the motif root |
| `missing_indices` | [4] | present in the *shape*, absent in the *sound* |
| `loop_duration` | 1.9 s | the unresolved gap is part of the form |
| `mutation_tolerance` | 0.05 s | how far a mutation may bend the timings |

Renderers skip `missing_indices` unless their profile sets
`omit_missing_events = false` (human humming) or the renderer's
`include_missing_events` is flipped by script (the radiator after the
Complete outcome — the loop *resolves* from then on).

## Adding a new motif

1. Duplicate `resources/motifs/incomplete_knock.tres`, change `id`,
   `event_times`, `accents`, `pitch_semitones`, `missing_indices`,
   `loop_duration`.
2. Hand it to any renderer: `renderer.set_motif(load("res://resources/motifs/my_motif.tres"))`.
   Renderers pick a new motif up at the next loop boundary; no scene logic
   changes. (`main.gd` references one `MOTIF` constant only because this
   prototype has one infection.)

## Adding a new translation profile (a new infected object)

1. Duplicate a `.tres` in `resources/profiles/`, set `id`, pick a `timbre`
   from `AudioFactory` (or add a new `_build` case there — one static
   function returning an `AudioStreamWAV`), and tune the limitation fields
   (`timing_drift`, `pitch_expression`, `accent_accuracy`,
   `event_reliability`, `partial_below_infection`, `bus`, `pan`).
2. Instantiate it: `var r := _mk_renderer(load(".../my_profile.tres"))` and
   connect `r.event_played` to whatever should visibly react.
3. That's all — scheduling, drift, omission, infection scaling, looping,
   one-shots and the debug replay path come from `MotifRenderer` for free.

## Edge-case handling map

| case | mechanism |
|---|---|
| repeated capture/route presses | capture re-press restarts the loop; routes are idempotent + sticky toggles |
| route change mid-playback | bus re-send, no player restart |
| waiting forever at RESPONSE | *is* the silence outcome (16 s window, world fades in the last 6 s) |
| audio device unavailable | Godot falls back to the dummy driver; game logic and visuals proceed (verified headless) |
| focus loss | tree pauses + master mutes; restored on focus-in |
| excessive overlap | 6-voice pool per renderer, normalized streams, master limiter |
| restart during audio | `run_id` guard orphans old coroutines; renderers stop and reset |
| response before setup | respond UI hidden until RESPONSE; `_do_outcome` checks stage |
| multiple outcome triggers | `GameState.try_commit_outcome` latch |
