class_name MotifDefinition
extends Resource
## A motif is an *idea*, not a sound: pure timing/pitch/accent structure.
## Sound sources ("bodies") interpret it through a TranslationProfile +
## MotifRenderer. Nothing in here references audio streams or scenes.

@export var id: String = ""

## Event onsets in seconds from loop start. Includes events that are
## *implied but absent* (see missing_indices) so renderers know where the
## unresolved space sits.
@export var event_times: PackedFloat32Array = PackedFloat32Array()

## Relative pitch per event, in semitones from the motif's root.
@export var pitch_semitones: PackedFloat32Array = PackedFloat32Array()

## Accent strength per event, 0..1.
@export var accents: PackedFloat32Array = PackedFloat32Array()

## Indices into event_times that are expected but not (yet) sounded.
@export var missing_indices: PackedInt32Array = PackedInt32Array()

## Total loop length in seconds — deliberately longer than the last event so
## the unresolved gap is part of the motif's shape.
@export var loop_duration: float = 2.0

## How far (seconds) event times may wander when the motif mutates.
@export var mutation_tolerance: float = 0.05

@export var tags: PackedStringArray = PackedStringArray()


func event_count() -> int:
	return event_times.size()


func is_missing(index: int) -> bool:
	return missing_indices.has(index)


func accent_at(index: int) -> float:
	return accents[index] if index < accents.size() else 1.0


func pitch_at(index: int) -> float:
	return pitch_semitones[index] if index < pitch_semitones.size() else 0.0


## Returns a warped copy. Times drift within mutation_tolerance and one accent
## inverts slightly — enough that the motif stays recognizable but feels wrong.
func mutated(rng: RandomNumberGenerator) -> MotifDefinition:
	var m := duplicate(true) as MotifDefinition
	var times := PackedFloat32Array()
	for i in m.event_times.size():
		var t := m.event_times[i]
		if i > 0:  # keep the downbeat anchored so the pattern stays legible
			t = maxf(0.02, t + rng.randf_range(-mutation_tolerance, mutation_tolerance))
		times.append(t)
	m.event_times = times
	if m.accents.size() > 1:
		var i := rng.randi_range(1, m.accents.size() - 1)
		m.accents[i] = clampf(1.0 - m.accents[i] * 0.6, 0.2, 1.0)
	if m.pitch_semitones.size() > 1:
		var i := rng.randi_range(1, m.pitch_semitones.size() - 1)
		m.pitch_semitones[i] += float(rng.randi_range(-1, 1))
	m.id = "%s~mut" % id
	return m
