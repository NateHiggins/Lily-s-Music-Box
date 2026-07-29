class_name TranslationProfile
extends Resource
## How one physical "body" interprets a motif. The same MotifDefinition
## rendered through different profiles must stay recognizable without
## sounding identical — profiles encode what each body *can't* do.

enum RenderMode {
	SAMPLE,  ## trigger a one-shot stream per event (knocks, breaths, ticks)
	TONE,    ## same trigger path, tuned pitched material (kept separate for intent)
	NOISE,   ## same trigger path, unpitched noise material
	HUM,     ## continuous drone; rhythm = amplitude swells, pitch = slow bends
}

@export var id: String = ""
@export var render_mode: RenderMode = RenderMode.SAMPLE

## Key into AudioFactory's procedural stream table ("knock", "tone",
## "breath", "vocal", "hum_loop", ...).
@export var timbre: String = "knock"

## Max seconds an event may land early/late. 0 = machine-perfect.
@export var timing_drift: float = 0.0

## 0 = body cannot express pitch at all, 1 = full contour.
@export var pitch_expression: float = 0.0

## Random semitone wobble added per event (human voices are unstable).
@export var pitch_instability: float = 0.0

## 0 = all events equally loud (body can't do dynamics), 1 = exact accents.
@export var accent_accuracy: float = 1.0

## Base chance each event actually sounds; low infection lowers it further.
@export var event_reliability: float = 1.0

## If true this body never voices the motif's implied-but-absent events
## (a renderer can override for scripted completion).
@export var omit_missing_events: bool = true

## While infection is below this level, only the first partial_event_count
## events play (e.g. the computer notification "quoting" the motif's head).
@export var partial_below_infection: float = 0.0
@export var partial_event_count: int = 2

@export var base_volume_db: float = -10.0

## Mix bus this body sends into ("Room", "Caller", "UI").
@export var bus: String = "Room"

## Stereo placement, -1..1. Where the body sits in the apartment.
@export var pan: float = 0.0

@export_multiline var notes: String = ""
