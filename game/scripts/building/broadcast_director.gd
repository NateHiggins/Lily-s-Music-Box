class_name BroadcastDirector
extends Node
## The station. Replaces the pre-baked reel with a live programme director:
## thirty-seven clean clips it shuffles at will, a card break every third
## programme, and a hand it can put on the transmission whenever it — or a
## poltergeist — wants to.
##
## One decode for the whole building: the feed renders into a shared
## SubViewport whose texture every lit set's glass samples through the
## tv_screen shader. When no set in the building is on, the video pauses
## and the viewport stops updating — a station with no audience costs
## nothing.
##
## Cards are live Controls drawn over the feed, not encoded video: an
## advertisement (the residents' own portal rules, sold back to them), a
## station identification, or a piece of hotel trivia. Live text means
## infinite variety at zero megabytes, and the poltergeist can misspell
## things later.
##
## Interference is the shader, not the file (tv_screen.gdshader, nine
## composable faults). Clips are stored clean; disturb() drives the
## uniforms for a few seconds, so the same clip can play pristine one night
## and possessed the next. The director's hand is also editorial — it can
## hop channels, freeze the frame, cut the sound, force a card — and under
## possession it seizes every set, breathes the glass, and surfs.

const CLIP_DIR := "res://assets/video/clips/"
const MANIFEST := "res://assets/video/clips/clips.json"
const SIZE := Vector2i(320, 576)
const CARD_EVERY := 3
const CARD_SECONDS := 3.6

const IDENTS := [
	["ORISON", "CHANNEL 4"], ["STAY TUNED", ""],
	["WE'LL BE", "RIGHT BACK"], ["DO NOT ADJUST", "YOUR SET"],
]
const ADVERTS := [
	["PLEASE REMAIN", "ON THE LINE"],
	["SILENCE DOES NOT", "REQUIRE ANNOTATION"],
	["SOME THINGS ARE", "NOT REPAIRABLE"],
	["GOOD ENOUGH", "CAN HOLD"],
	["NOT EVERY ALARM", "IS YOURS"],
	["DEPARTURE", "IS A DECISION"],
	["CONTRADICTION", "IS SURVIVABLE"],
]
const TRIVIA := [
	["THE ORISON'S BOILER HAS BURNED", "CONTINUOUSLY SINCE 1927"],
	["THE LIGHT COURT RISES", "SEVEN STOREYS UNBROKEN"],
	["OUR SWITCHBOARD ANSWERS", "AT EVERY HOUR"],
	["THE BRASS TREE WAS COMMISSIONED", "FOR THE OPENING"],
	["EIGHTEEN HOMES", "ONE ADDRESS"],
	["THE ELEVATOR HAS NEVER", "ONCE BEEN LATE"],
]

var clips: Array = []
var sets: Array[TVProp] = []
var programmes_since_card := 0
var possessed := false

var _viewport: SubViewport
var _video: VideoStreamPlayer
var _card: Control
var _card_left := 0.0
var _shared: ShaderMaterial
var _queue: Array = []
var _rng := RandomNumberGenerator.new()
var _sample := 0.0
var _ambient := 0.0
var _fx_left := 0.0
var _fx := ""
var _surf := 0.0


func build(layout: Dictionary, floor_nodes: Dictionary) -> int:
	_rng.randomize()
	var file := FileAccess.open(MANIFEST, FileAccess.READ)
	if file:
		clips = JSON.parse_string(file.get_as_text()).get("clips", [])
	_viewport = SubViewport.new()
	_viewport.size = SIZE
	# One coordinate system, explicitly. A logical 2D override on the
	# canvas makes anchored children lay out against a DIFFERENT size than
	# the render target, which is exactly how a video ends up occupying one
	# quadrant while text overlays look fine. Zero disables the override.
	_viewport.size_2d_override = Vector2i.ZERO
	_viewport.size_2d_override_stretch = false
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	_video = VideoStreamPlayer.new()
	_video.expand = true
	# Anchors AND offsets in one call, and no manual size assignment
	# afterwards — a pixel size imposed on a full-rect-anchored control
	# leaves stale offsets that survive the next layout pass.
	_video.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_video.finished.connect(_next_programme)
	_viewport.add_child(_video)
	_card = Control.new()
	_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card.visible = false
	_viewport.add_child(_card)
	_shared = ShaderMaterial.new()
	_shared.shader = load("res://shaders/tv_screen.gdshader")
	_shared.set_shader_parameter("feed", _viewport.get_texture())
	# One prop per television the layout owns, parented to its floor so
	# streaming still hides it with the room around it.
	for fl in layout["floors"]:
		var fid := str(fl["id"])
		if not floor_nodes.has(fid):
			continue
		for fu in fl.get("furniture", []):
			if str(fu.get("asm", "")) != "tv":
				continue
			# PROJECTORS, not sets (ORISON_PROJECTOR_BRIEF). ProjectorProp
			# extends TVProp, so `sets`, set_glow(), the resident routines that
			# switch one on like a person and the poltergeist that takes them
			# all keep working untouched - none of that vocabulary ever cared
			# whether the picture lands on glass or on plaster.
			var tv := ProjectorProp.new()
			tv.setup(self, str(fu.get("id", "tv")).split("_")[0],
					_shared)
			# Each machine arrives with one reel already in the gate, so nine
			# machines seed nine clips and the system teaches itself without a
			# tutorial. Deterministic per unit: a household's reel is theirs.
			if clips.size() > 0:
				var pick: int = abs(hash(tv.unit)) % clips.size()
				tv.load_reel(str(clips[pick].get("id", "")))
			var at: Array = fu["at"]
			# z0 matters now: the Harukiya's karaoke set lives in a
			# basement 2.8 m below its floor entry in the layout, and
			# ignoring z0 spawned it at street level inside solid infill.
			tv.position = GameBoot.b2g([float(at[0]), float(at[1]),
					float(fl["z"]) + float(fu.get("z0", 0.0))])
			# +PI: the cabinet's authored yaw faces its BACK into the room
			# (confirmed by standing in front of one), so every set turns
			# half a circle to meet its sofa.
			tv.rotation.y = deg_to_rad(float(fu.get("yaw", 0))) + PI
			floor_nodes[fid].add_child(tv)
			sets.append(tv)
	print("[STATION] %d clips, %d sets, all dark" % [clips.size(),
			sets.size()])
	return sets.size()


# ------------------------------------------------------------ programming

func _shuffle() -> void:
	_queue = clips.duplicate()
	_queue.shuffle()


func _next_programme() -> void:
	programmes_since_card += 1
	if programmes_since_card >= CARD_EVERY:
		programmes_since_card = 0
		_show_card()
		return
	_play_next_clip()


func _play_next_clip() -> void:
	if _queue.is_empty():
		_shuffle()
	if _queue.is_empty():
		return
	var pick: Dictionary = _queue.pop_back()
	_video.stream = load(CLIP_DIR + str(pick.id) + ".ogv")
	_video.play()


## A live card: ident, advert or trivia, weighted toward the strange ones.
func _show_card() -> void:
	for child in _card.get_children():
		child.queue_free()
	var roll := _rng.randf()
	var pool: Array = ADVERTS if roll < 0.45 else \
			(TRIVIA if roll < 0.8 else IDENTS)
	var lines: Array = pool[_rng.randi() % pool.size()]
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.07, 0.11) if roll >= 0.45 \
			else Color(0.10, 0.07, 0.03)
	_card.add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(-140, -40)
	box.custom_minimum_size = Vector2(280, 0)
	_card.add_child(box)
	for line in lines:
		if str(line) == "":
			continue
		var label := Label.new()
		label.text = str(line)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 22)
		label.modulate = Color(0.93, 0.85, 0.62)
		box.add_child(label)
	_video.paused = true
	_card.visible = true
	_card_left = CARD_SECONDS


# ------------------------------------------------------------ the hand

## The variety of ways. Deliberately a grab-bag so the sanity director has a
## vocabulary rather than one knob — picture faults, and editorial ones.
func disturb(kind: String, seconds := 2.5) -> void:
	_fx_left = maxf(_fx_left, seconds)
	match kind:
		"static": _shared.set_shader_parameter("static_amount", 0.85)
		"roll": _shared.set_shader_parameter("roll_speed", 1.4)
		"ghost": _shared.set_shader_parameter("ghost_offset", 0.05)
		"dropout": _shared.set_shader_parameter("dropout", 0.9)
		"chroma": _shared.set_shader_parameter("chroma", 0.8)
		"tear": _shared.set_shader_parameter("tear", 0.8)
		"flicker": _shared.set_shader_parameter("flicker", 0.8)
		"warp": _shared.set_shader_parameter("warp", 0.7)
		"freeze": _video.paused = true
		"mute": _video.volume_db = -60.0
		"card": _show_card()
		"hop":
			_shared.set_shader_parameter("static_amount", 0.7)
			_play_next_clip()


## A poltergeist takes every set in the building at once.
func possess(seconds := 12.0) -> void:
	if possessed:
		return
	possessed = true
	for tv in sets:
		tv.set_possessed(true)
	disturb("static", seconds)
	disturb("ghost", seconds)
	disturb("warp", seconds)
	disturb("flicker", seconds)
	print("[STATION] possessed for %.0f s" % seconds)
	await get_tree().create_timer(seconds).timeout
	possessed = false
	for tv in sets:
		tv.set_possessed(false)
	_clear_fx()


func _clear_fx() -> void:
	for p in ["static_amount", "roll_speed", "ghost_offset", "dropout",
			"chroma", "tear", "flicker", "warp"]:
		_shared.set_shader_parameter(p, 0.0)
	if not _card.visible:
		_video.paused = false


# ------------------------------------------------------------ power

func any_powered() -> bool:
	for tv in sets:
		if tv.powered:
			return true
	return false


func tv_power_changed() -> void:
	var live := any_powered()
	if live and _viewport.render_target_update_mode \
			== SubViewport.UPDATE_DISABLED:
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		if _video.stream == null:
			_play_next_clip()
		else:
			_video.paused = false
		print("[STATION] on air")
	elif not live:
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_video.paused = true
		print("[STATION] off air")


func _process(delta: float) -> void:
	if not any_powered():
		return
	# Watchdog: whatever path left the station silent — a stream that
	# failed to load, a finished signal lost across a pause/possess/card
	# transition — a powered set showing nothing gets the next programme.
	# Self-healing beats diagnosing every possible stall.
	if not _card.visible and not _video.paused \
			and not _video.is_playing():
		_play_next_clip()
	# card timer
	if _card.visible:
		_card_left -= delta
		if _card_left <= 0.0:
			_card.visible = false
			_video.paused = false
			_play_next_clip()
	# interference decays back to a clean signal
	if _fx_left > 0.0:
		_fx_left -= delta
		if _fx_left <= 0.0 and not possessed:
			_clear_fx()
	# the odd ambient blip, so a long evening is never quite stable
	_ambient -= delta
	if _ambient <= 0.0:
		_ambient = _rng.randf_range(50.0, 130.0)
		disturb(["static", "roll", "ghost"][_rng.randi() % 3],
				_rng.randf_range(0.4, 1.1))
	# the glow: average what is actually on screen and hand it to the sets
	_sample -= delta
	if _sample <= 0.0:
		_sample = 0.45
		var img := _viewport.get_texture().get_image()
		if img:
			img.resize(8, 8, Image.INTERPOLATE_BILINEAR)
			var sum := Vector3.ZERO
			for x in 8:
				for y in 8:
					var c := img.get_pixel(x, y)
					sum += Vector3(c.r, c.g, c.b)
			sum /= 64.0
			var tint := Color(sum.x, sum.y, sum.z)
			var lum := sum.dot(Vector3(0.33, 0.5, 0.17))
			for tv in sets:
				tv.set_glow(tint, lum)
	# the programme's own sound follows the nearest lit set
	var cam := get_viewport().get_camera_3d()
	if cam:
		var near := 99.0
		for tv in sets:
			if tv.powered:
				near = minf(near, tv.global_position.distance_to(
						cam.global_position))
		_video.volume_db = clampf(-6.0 - 46.0 * clampf(near / 13.0,
				0.0, 1.0), -60.0, -6.0)


func stats() -> Dictionary:
	var on := 0
	for tv in sets:
		if tv.powered:
			on += 1
	return {"clips": clips.size(), "sets": sets.size(), "on": on,
			"possessed": possessed, "card": _card.visible}
