extends Node
## Authored mechanical shorts. No world state, video decoder, new draw calls or
## idle processing. Tile motion retains the display's own bounded work budget.
const DATA := "res://data/device/companion_face_reactions.json"
var clips: Dictionary = {}
var failures: Array[String] = []
var current := ""
var frame := 0
var completed := 0
var _face: Node3D
var _clock: Callable
var _last: Dictionary = {}
var _hold := 0.0

func _ready() -> void:
	set_process(false)

func configure(face: Node3D, clock: Callable) -> bool:
	if _face != null or face == null or not clock.is_valid(): return false
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if data is not Dictionary or data.get("schema_version") != 1 or data.get("width") != 32 or data.get("height") != 12 or data.get("reactions") is not Array: return false
	if data.reactions.is_empty() or data.reactions.size() > 16: return false
	var checked: Dictionary = {}
	for clip: Variant in data.reactions:
		if clip is not Dictionary or clip.get("id") is not String or clip.id.is_empty() or clip.id.length() > 64 or checked.has(clip.id): return false
		if not _integer(clip.get("cooldown_ms"), 0, 60000) or clip.get("frames") is not Array or clip.frames.is_empty() or clip.frames.size() > 16: return false
		var frames: Array[Dictionary] = []
		for pose: Variant in clip.frames:
			if pose is not Dictionary or not _integer(pose.get("hold_ms"), 250, 2000) or pose.get("rows") is not Array or pose.rows.size() != 12: return false
			var pixels := PackedByteArray()
			for row: Variant in pose.rows:
				if row is not String or row.length() != 32: return false
				for glyph in row:
					if glyph not in [".", "#"]: return false
					pixels.append(1 if glyph == "#" else 0)
			frames.append({"pixels":pixels, "hold":float(pose.hold_ms) / 1000.0})
		checked[clip.id] = {"frames":frames, "cooldown":float(clip.cooldown_ms) / 1000.0}
	clips = checked; _face = face; _clock = clock
	return true

func request(id: String) -> bool:
	if _face == null or not current.is_empty() or not clips.has(id): return false
	var now: float = _clock.call()
	if not is_finite(now) or now < float(_last.get(id, -1000000.0)) + float(clips[id].cooldown): return false
	if not _face.set_pixels(clips[id].frames[0].pixels): return false
	_last[id] = now; current = id; frame = 0; _hold = 0.0
	set_process(true)
	return true

func cancel(restore_face := true) -> void:
	if current.is_empty(): return
	current = ""; _hold = 0.0
	set_process(false)
	if restore_face: _face.set_expression("content")
	else: _face.illustration_active = false

func _process(delta: float) -> void:
	if current.is_empty() or _face == null: set_process(false); return
	# Hold the final image AFTER the physical squares have reached it.
	if not _face.settled(): return
	_hold += maxf(0.0, delta)
	if _hold < float(clips[current].frames[frame].hold): return
	_hold = 0.0; frame += 1
	if frame >= clips[current].frames.size():
		completed += 1
		cancel()
		return
	_face.set_pixels(clips[current].frames[frame].pixels)

static func _integer(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and float(value) >= low and float(value) <= high
