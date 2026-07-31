class_name BroadcastAudio
extends Node3D
## Sound for the televisions, synchronised to what the picture is doing.
##
## No audio file is involved. This project synthesises every sound at
## runtime and has none on disk, so the sets are voiced out of the same
## procedural library the radiators and boilers use: `murmur_loop` for a
## programme, `buzz_loop` for a signal that has gone, `hum_loop` for the
## station's own cards. A real broadcast bed would have been easier and
## would have broken the one rule the audio system has.
##
## The synchronisation is the point. `build_broadcast.py` writes a sidecar
## manifest of every segment in the reel — when each channel starts, when
## the picture tears, where the adverts fall — and this reads the video's
## own playback position against it. So a set goes to static at the exact
## frame its picture does, from across a room, through a wall, without
## anything having to analyse the video.
##
## One emitter per television, positioned from the same layout data the
## geometry comes from. They are 3D and attenuated, so a set two rooms away
## is a suggestion of one rather than a sound effect.

const MANIFEST := "res://assets/video/orison_broadcast.json"

## Per segment kind: stream, volume, pitch. Adverts are louder than the
## programme they interrupt, which is both period-accurate and the single
## cheapest joke available here.
const VOICE := {
	"channel": ["murmur_loop", -19.0, 1.0],
	"advert": ["murmur_loop", -13.0, 1.08],
	"bumper": ["hum_loop", -17.0, 1.12],
	"title": ["hum_loop", -17.0, 0.94],
	"glitch": ["buzz_loop", -11.0, 1.0],
}

var sets := 0
var current_kind := ""

var _video: VideoStreamPlayer
var _segments: Array = []
var _length := 0.0
var _emitters: Array[AudioStreamPlayer3D] = []
var _cursor := 0


func build(layout: Dictionary, video: VideoStreamPlayer) -> int:
	_video = video
	var file := FileAccess.open(MANIFEST, FileAccess.READ)
	if file == null:
		push_warning("broadcast manifest missing: %s" % MANIFEST)
		return 0
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return 0
	_segments = parsed.get("segments", [])
	_length = float(parsed.get("length", 0.0))
	# Every television in the building, from the layout the geometry is
	# built from — the screens themselves are merged into the floor meshes
	# and have no nodes of their own to hang a speaker on.
	for fl in layout["floors"]:
		for furniture in fl.get("furniture", []):
			if str(furniture.get("asm", "")) != "tv":
				continue
			var at: Array = furniture["at"]
			var emitter := AudioStreamPlayer3D.new()
			emitter.position = GameBoot.b2g([float(at[0]), float(at[1]),
					float(fl["z"]) + 0.75])
			emitter.unit_size = 3.4
			emitter.max_distance = 16.0
			emitter.attenuation_model = \
					AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
			add_child(emitter)
			_emitters.append(emitter)
			sets += 1
	print("[BROADCAST AUDIO] %d sets, %d segments" % [sets, _segments.size()])
	return sets


func _process(_delta: float) -> void:
	if _video == null or _segments.is_empty() or _emitters.is_empty():
		return
	var kind := _kind_at(_video.stream_position)
	if kind == current_kind or kind == "":
		return
	current_kind = kind
	var voice: Array = VOICE.get(kind, VOICE.channel)
	var stream := PropAudio.get_stream(str(voice[0]))
	for emitter in _emitters:
		emitter.stream = stream
		emitter.volume_db = float(voice[1])
		emitter.pitch_scale = float(voice[2])
		emitter.play()


## Walks forward from where it left off rather than searching the whole
## reel: playback is monotonic apart from the loop, which the wrap handles.
func _kind_at(at: float) -> String:
	if _length <= 0.0:
		return ""
	var t: float = fposmod(at, _length)
	if _cursor >= _segments.size() or float(_segments[_cursor]["t"]) > t:
		_cursor = 0
	while _cursor + 1 < _segments.size() \
			and float(_segments[_cursor + 1]["t"]) <= t:
		_cursor += 1
	return str(_segments[_cursor]["kind"])


func set_enabled(on: bool) -> void:
	for emitter in _emitters:
		if on:
			emitter.play()
		else:
			emitter.stop()


func stats() -> Dictionary:
	return {"sets": sets, "kind": current_kind,
			"at": _video.stream_position if _video else 0.0}
