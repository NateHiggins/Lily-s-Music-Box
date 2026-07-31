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
## False for the whole game until something takes the sets.
var infected := false

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
	if _video == null or _emitters.is_empty():
		return
	# NORMAL: the programme's own soundtrack, carried in the reel. A
	# VideoStreamPlayer cannot be positioned in 3D, so its level tracks the
	# distance to the nearest set instead — which is indistinguishable from
	# spatialisation while you are in a room with one, and silent two floors
	# away, which is all that is actually required.
	var near := _nearest_set()
	if not infected:
		_video.volume_db = clampf(
				-6.0 - 46.0 * clampf(near / 14.0, 0.0, 1.0), -60.0, -6.0)
		return
	# INFECTED: the sets stop carrying the broadcast and start carrying
	# whatever has taken them. The programme ducks under it rather than
	# stopping, so you can still hear what it is drowning.
	_video.volume_db = -34.0
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


func _nearest_set() -> float:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return 99.0
	var best := 99.0
	for emitter in _emitters:
		best = minf(best, emitter.global_position.distance_to(
				camera.global_position))
	return best


## A poltergeist taking the televisions. Reuses the procedural voice this
## project already synthesises — the one that sounded wrong as a programme
## and is exactly right as a possession.
func set_infected(on: bool, seconds := 12.0) -> void:
	if infected == on:
		return
	infected = on
	current_kind = ""
	if on:
		print("[BROADCAST] the sets have been taken")
		for emitter in _emitters:
			emitter.stream = PropAudio.get_stream("agitate_loop")
			emitter.volume_db = -14.0
			emitter.play()
		if seconds > 0.0:
			await get_tree().create_timer(seconds).timeout
			set_infected(false)
	else:
		for emitter in _emitters:
			emitter.stop()


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
