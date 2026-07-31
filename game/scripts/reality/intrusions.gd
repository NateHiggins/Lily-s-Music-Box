class_name Intrusions
extends Node
## The acts a poltergeist can perform inside the building.
##
## Everything here obeys one rule: the building is borrowed, not damaged.
## Every prop touched is snapshotted before it moves and restored when the
## intrusion ends, and the restore is unconditional — it runs on a timer that
## does not care whether the poltergeist, the director or the case is still
## alive. A haunting the player can permanently break by walking away is a
## save-corrupting bug, and this system already tells enough lies without
## telling that one.
##
## The acts are deliberately small. A chair that has turned to face you is
## worse than a chair thrown across the room, because the thrown chair is an
## event you survive and the turned chair is a fact you now have to live
## with. Scale comes from repetition and from the player realising the
## building is making a point, not from amplitude.

const RESTORE_AFTER := 26.0
## Beyond this the player cannot tell an intrusion happened "near" them, and
## haunting an empty floor is just physics.
const REACH := 9.0

var world: Node3D
var player: Node3D
var fourth_wall: FourthWallLayer
## What the last act actually touched. The director watches these to find out
## whether the player ever noticed — an intrusion nobody sees is an intrusion
## that has to be made again, louder.
var last_targets: Array[Node3D] = []

var _held: Array = []          # [{node, transform, at}]
var _rng := RandomNumberGenerator.new()
var _captions: Array[Label3D] = []
var _light_holds: Array = []   # [{fixture, energy, at}]


func setup(building: Node3D, body: Node3D, meta: FourthWallLayer) -> void:
	world = building
	player = body
	fourth_wall = meta
	_rng.randomize()


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for entry in _held.duplicate():
		if now >= entry.at:
			if is_instance_valid(entry.node):
				entry.node.transform = entry.transform
				entry.node.visible = entry.get("visible", true)
			_held.erase(entry)
	for entry in _light_holds.duplicate():
		if now >= entry.at:
			if is_instance_valid(entry.fixture) and entry.fixture.light:
				entry.fixture.light.light_energy = entry.energy
			_light_holds.erase(entry)
	for caption in _captions.duplicate():
		if not is_instance_valid(caption):
			_captions.erase(caption)
		elif now >= caption.get_meta("expires", 0.0):
			_captions.erase(caption)
			caption.queue_free()


## Run one act. `arg` is an int count for prop/light acts and a string for
## sound, whisper and meta acts.
func perform(kind: String, arg) -> bool:
	last_targets.clear()
	match kind:
		"prop_turn": return _prop_turn(int(arg))
		"prop_vanish": return _prop_vanish(int(arg))
		"prop_drift": return _prop_move(int(arg), 0.16, false)
		"prop_scatter": return _prop_move(int(arg), 0.42, true)
		"prop_tremble": return _prop_tremble(int(arg))
		"prop_fall": return _prop_fall(int(arg))
		"prop_fault": return _prop_fault(int(arg))
		"light_flicker": return _light_flicker(str(arg))
		"light_follow": return _light_follow()
		"sound": return _sound(str(arg))
		"whisper": return _whisper(str(arg))
		"caption_room": return _caption_room(int(arg))
		"caption_player": return _caption_player(int(arg))
		"museum_label": return _museum_label(int(arg))
		"word_loss": return _word_loss(int(arg))
		"motif_mutate": return _motif_mutate(int(arg))
		"distort": return _distort(str(arg))
		"fourth_wall":
			return fourth_wall != null and fourth_wall.play(str(arg))
	return false


# --------------------------------------------------------------- targets

## Is this point inside what the player can currently see? The single most
## useful question in the system: a chair that turns while you are watching
## is a special effect, and a chair that has turned when you look back is a
## fact about the room you are standing in.
func _in_view(point: Vector3) -> bool:
	var cam: Camera3D = _camera()
	if cam == null:
		return false
	if not cam.is_position_in_frustum(point):
		return false
	# In the frustum is not the same as visible — a wall between you and it
	# means you are not watching it, whatever the projection says.
	var space := cam.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(cam.global_position, point)
	if player is CollisionObject3D:
		query.exclude = [player.get_rid()]
	var hit := space.intersect_ray(query)
	return hit.is_empty() or hit.position.distance_to(point) < 0.6


func _camera() -> Camera3D:
	if player == null:
		return null
	var cam = player.get("camera")
	return cam if cam is Camera3D else null


## Props within reach. `unseen_first` is the default because the strongest
## version of nearly every act here is the one the player did not watch
## happen — they turn around and the room has already changed its mind.
func _nearby_props(limit: int, unseen_first := true) -> Array:
	if player == null or world == null:
		return []
	var here := player.global_position
	var found: Array = []
	for child in world.get_children():
		if not (child is FunctionalProp) or child is LightFixtureProp:
			continue
		var prop: Node3D = child
		var d: float = prop.global_position.distance_to(here)
		if d > REACH:
			continue
		# Sorting key: unseen props sort ahead of visible ones by a margin
		# wider than the reach, so proximity still orders within each group.
		var key := d
		if unseen_first and _in_view(prop.global_position):
			key += 1000.0
		found.append([key, prop])
	found.sort_custom(func(a, b): return a[0] < b[0])
	var out: Array = []
	for entry in found.slice(0, limit):
		out.append(entry[1])
	return out


func _nearby_lights(limit: int) -> Array:
	if player == null:
		return []
	var here := player.global_position
	var found: Array = []
	for fixture in player.get_tree().get_nodes_in_group("light_fixtures"):
		if fixture.light == null or not fixture.light.visible:
			continue
		var d: float = fixture.global_position.distance_to(here)
		if d <= REACH:
			found.append([d, fixture])
	found.sort_custom(func(a, b): return a[0] < b[0])
	var out: Array = []
	for entry in found.slice(0, limit):
		out.append(entry[1])
	return out


## Record that an act pointed at this prop. Separate from _hold() because
## annotation acts do not move anything — a label hung over a chair leaves
## the chair exactly where it was — but a player who looks at the labelled
## chair has still noticed, and notice is what the director is measuring.
func _mark(node: Node3D) -> void:
	if not last_targets.has(node):
		last_targets.append(node)


## Snapshot before touching. Taking the snapshot at possession time rather
## than at spawn means a prop legitimately moved by gameplay is restored to
## where gameplay left it, not to where the level generator put it.
func _hold(node: Node3D) -> void:
	_mark(node)
	for entry in _held:
		if entry.node == node:
			entry.at = Time.get_ticks_msec() / 1000.0 + RESTORE_AFTER
			return
	_held.append({"node": node, "transform": node.transform,
			"visible": node.visible,
			"at": Time.get_ticks_msec() / 1000.0 + RESTORE_AFTER})


## Something that was there is not there. Only ever performed on props the
## player cannot currently see, because the horror is the absence discovered
## later — watching an object blink out is a glitch, finding the shelf empty
## is a memory you now distrust.
func _prop_vanish(count: int) -> bool:
	var props := _nearby_props(count + 3)
	var taken := 0
	for entry in props:
		var prop: Node3D = entry
		if _in_view(prop.global_position):
			continue
		_hold(prop)
		prop.visible = false
		taken += 1
		if taken >= count:
			break
	return taken > 0


# ------------------------------------------------------------ prop acts

## The signature act. Nothing moves position; things are simply facing you
## now, and were not before.
func _prop_turn(count: int) -> bool:
	var props := _nearby_props(count)
	for entry in props:
		var prop: Node3D = entry
		_hold(prop)
		var to: Vector3 = player.global_position - prop.global_position
		to.y = 0.0
		if to.length_squared() < 0.01:
			continue
		prop.rotation.y = atan2(to.x, to.z)
	return not props.is_empty()


func _prop_move(count: int, distance: float, chaotic: bool) -> bool:
	var props := _nearby_props(count)
	for entry in props:
		var prop: Node3D = entry
		_hold(prop)
		var dir := Vector3(_rng.randfn(0.0, 1.0), 0.0, _rng.randfn(0.0, 1.0))
		if not chaotic:
			# Drift is TOWARD the player: the room closing in by a
			# centimetre at a time is the note, not random tidying.
			dir = (player.global_position - prop.global_position)
			dir.y = 0.0
		if dir.length_squared() < 0.001:
			continue
		prop.global_position += dir.normalized() * distance
	return not props.is_empty()


func _prop_tremble(count: int) -> bool:
	var props := _nearby_props(count)
	for entry in props:
		var prop: Node3D = entry
		_hold(prop)
		var start: Vector3 = prop.position
		var tween: Tween = prop.create_tween()
		for i in 6:
			tween.tween_property(prop, "position", start + Vector3(
					_rng.randf_range(-0.012, 0.012), 0.0,
					_rng.randf_range(-0.012, 0.012)), 0.05)
		tween.tween_property(prop, "position", start, 0.06)
	return not props.is_empty()


func _prop_fall(count: int) -> bool:
	var props := _nearby_props(count + 2)
	var did := false
	for entry in props:
		var prop: Node3D = entry
		# Only things with somewhere to fall from.
		if prop.global_position.y < 0.4:
			continue
		_hold(prop)
		var tween: Tween = prop.create_tween()
		tween.tween_property(prop, "position:y",
				prop.position.y - 0.35, 0.22).set_ease(Tween.EASE_IN)
		did = true
		if did and count <= 1:
			break
	return did


## Omar's: the thing you just watched work stops working, in a new way.
func _prop_fault(count: int) -> bool:
	var props := _nearby_props(count)
	for entry in props:
		var prop: FunctionalProp = entry
		_mark(prop)
		prop.state = FunctionalProp.PState.FAULT
	return not props.is_empty()


# ----------------------------------------------------------- light acts

func _light_flicker(pattern: String) -> bool:
	var lights := _nearby_lights(4)
	for entry in lights:
		var fixture: Node3D = entry
		var source: Light3D = fixture.light
		var base: float = source.light_energy
		_light_holds.append({"fixture": fixture, "energy": base,
				"at": Time.get_ticks_msec() / 1000.0 + 8.0})
		var tween: Tween = fixture.create_tween()
		match pattern:
			"stutter":
				for i in 5:
					tween.tween_property(source, "light_energy", 0.02, 0.04)
					tween.tween_property(source, "light_energy", base, 0.09)
			"beat":
				# Juno's: the room flickers ON the motif, in time, like a
				# room that has been sampled.
				for i in 4:
					tween.tween_property(source, "light_energy",
							base * 1.7, 0.06)
					tween.tween_property(source, "light_energy",
							base * 0.4, 0.42)
			"swell":
				tween.tween_property(source, "light_energy", base * 2.2, 1.4)
				tween.tween_property(source, "light_energy", base, 1.1)
			_:
				tween.tween_property(source, "light_energy", base * 0.15, 0.9)
				tween.tween_property(source, "light_energy", base, 0.7)
	return not lights.is_empty()


## Everything goes out except the one nearest the player, which brightens.
## Being spotlit is worse than being in the dark.
func _light_follow() -> bool:
	var lights := _nearby_lights(6)
	if lights.is_empty():
		return false
	var now := Time.get_ticks_msec() / 1000.0
	for i in lights.size():
		var fixture = lights[i]
		var source: Light3D = fixture.light
		_light_holds.append({"fixture": fixture, "energy": source.light_energy,
				"at": now + 7.0})
		var target: float = source.light_energy * (2.0 if i == 0 else 0.04)
		fixture.create_tween().tween_property(source, "light_energy",
				target, 0.5)
	return true


# ------------------------------------------------------------ sound acts

func _sound(key: String) -> bool:
	if player == null:
		return false
	var stream := PropAudio.get_stream(_stream_for(key))
	if stream == null:
		return false
	var emitter := AudioStreamPlayer3D.new()
	emitter.stream = stream
	emitter.unit_size = 6.0
	emitter.volume_db = -6.0
	# Behind and slightly to one side. Never in front — a sound you can look
	# at is a sound you have dealt with.
	var back := -player.global_transform.basis.z
	emitter.position = player.global_position - back * 2.2 \
			+ Vector3(_rng.randf_range(-1.2, 1.2), 0.1, 0.0)
	world.add_child(emitter)
	emitter.play()
	emitter.finished.connect(emitter.queue_free)
	return true


## The building's own sound library, reused. A poltergeist that ships its own
## audio would sound like a different game; one that speaks in radiator
## knocks and boiler hum sounds like the building meant it.
func _stream_for(key: String) -> String:
	match key:
		"knock": return "knock"
		"hum": return "hum_loop"
		"breath": return "breath"
		"bell": return "bell"
		"static": return "buzz_loop"
		"leaves": return "creak"
		"skitter": return "tick"
		"shutter": return "pop"
	return "murmur_loop"


## Text, close to the player's ear, held for a few seconds. Rendered in the
## world rather than on the HUD so it belongs to the room.
func _whisper(text: String) -> bool:
	if player == null or world == null:
		return false
	var label := Label3D.new()
	label.text = text
	label.font_size = 26
	label.pixel_size = 0.0021
	label.modulate = Color(0.78, 0.82, 0.80, 0.85)
	label.outline_size = 6
	label.outline_modulate = Color(0.01, 0.02, 0.02, 0.9)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	var back := -player.global_transform.basis.z
	label.position = player.global_position + back * 1.6 + Vector3(0, 0.1, 0)
	world.add_child(label)
	label.set_meta("expires", Time.get_ticks_msec() / 1000.0 + 4.5)
	_captions.append(label)
	return true


# ------------------------------------------------- annotation acts (Mina)

const ROOM_CAPTIONS := [
	"[DOOR, CLOSED]", "[CHAIR, UNOCCUPIED]", "[RADIATOR, TICKING]",
	"[LAMP, ON]", "[SILENCE]", "[FLOOR, BEARING WEIGHT]",
	"[WINDOW, FACING THE STREET]", "[SILENCE, CONTINUED]",
]

## Mina's ladder rungs one to three: the room gets labelled. Accurate,
## literal, harmless — which is exactly how it starts for her.
func _caption_room(count: int) -> bool:
	var props := _nearby_props(count)
	for i in props.size():
		var prop = props[i]
		_mark(prop)
		var label := Label3D.new()
		label.text = ROOM_CAPTIONS[i % ROOM_CAPTIONS.size()]
		label.font_size = 20
		label.pixel_size = 0.0018
		label.modulate = Color(0.68, 0.86, 0.84, 0.8)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = prop.global_position + Vector3(0, 0.55, 0)
		world.add_child(label)
		label.set_meta("expires", Time.get_ticks_msec() / 1000.0 + 6.0)
		_captions.append(label)
	return not props.is_empty()


const PLAYER_CAPTIONS := [
	"[SUBJECT CHECKS BEHIND HIM AGAIN]",
	"[SUBJECT IS DECIDING WHETHER THIS COUNTS AS REAL]",
	"[SUBJECT DECLINES TO STATE WHAT HE IS FEELING]",
	"[SUBJECT WOULD LIKE THIS TO BE A BUG]",
	"[SUBJECT HAS NOT LOOKED AWAY FROM THIS TEXT]",
]

## Rung four. The captions stop describing the room and start describing the
## player's interior life, which is the exact escalation her case documents:
## "from nouns to false claims about thoughts and intentions". The player is
## now standing where Mina lives.
func _caption_player(count: int) -> bool:
	if player == null:
		return false
	for i in mini(count, PLAYER_CAPTIONS.size()):
		var label := Label3D.new()
		label.text = PLAYER_CAPTIONS[i]
		label.font_size = 22
		label.pixel_size = 0.0016
		label.modulate = Color(0.92, 0.86, 0.68, 0.92)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		var forward := -player.global_transform.basis.z
		label.position = player.global_position + forward * (2.0 + i * 0.35) \
				+ Vector3(0, 0.5 - i * 0.24, 0)
		world.add_child(label)
		label.set_meta("expires", Time.get_ticks_msec() / 1000.0 + 7.0)
		_captions.append(label)
	return true


const MUSEUM_LABELS := [
	"ACCESSION 1927.1 — CHAIR, DOMESTIC, UNUSED",
	"ACCESSION 1927.2 — LAMP, ELECTRIC, NEVER REPAIRED",
	"ACCESSION 1927.3 — TABLE, DINING, NO EVIDENCE OF USE",
	"PROVENANCE DISPUTED — TWO ACCOUNTS ON FILE",
	"DO NOT HANDLE",
	"ON LOAN FROM A FAMILY THAT NO LONGER EXISTS",
]

func _museum_label(count: int) -> bool:
	var props := _nearby_props(count)
	for i in props.size():
		var prop = props[i]
		_mark(prop)
		var label := Label3D.new()
		label.text = MUSEUM_LABELS[i % MUSEUM_LABELS.size()]
		label.font_size = 16
		label.pixel_size = 0.0016
		label.modulate = Color(0.86, 0.82, 0.7, 0.85)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = prop.global_position + Vector3(0, 0.42, 0)
		world.add_child(label)
		label.set_meta("expires", Time.get_ticks_msec() / 1000.0 + 7.0)
		_captions.append(label)
	return not props.is_empty()


## Jonah's: a sentence appears and loses its own ending as you read it.
func _word_loss(count: int) -> bool:
	if player == null:
		return false
	var label := Label3D.new()
	label.text = "he meant to finish it before the end of the"
	label.font_size = 24
	label.pixel_size = 0.0019
	label.modulate = Color(0.84, 0.8, 0.72, 0.9)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	var forward := -player.global_transform.basis.z
	label.position = player.global_position + forward * 2.2 + Vector3(0, 0.35, 0)
	world.add_child(label)
	label.set_meta("expires", Time.get_ticks_msec() / 1000.0 + 6.0)
	_captions.append(label)
	var words: PackedStringArray = label.text.split(" ")
	var tween := label.create_tween()
	for i in range(mini(count, words.size() - 1)):
		tween.tween_callback(func():
			if is_instance_valid(label):
				var kept := Array(words).slice(0, words.size() - 1 - i)
				label.text = " ".join(kept)).set_delay(0.8)
	return true


# ---------------------------------------------------------- system acts

func _motif_mutate(times: int) -> bool:
	for i in maxi(1, times):
		Conductor.mutate_motif()
	return true


## Borrowed from the distortion lab rather than reimplemented. It already
## captures and restores canonical transforms, and it is already the thing
## chaos mode drives, so a poltergeist bending a floor uses the same code
## path the debug tooling has been proving out.
func _distort(mode: String) -> bool:
	if world == null:
		return false
	var lab = world.get("map_distortion_lab")
	if lab == null or not lab.has_method("set_mode"):
		return false
	lab.set_mode(mode)
	# Always comes back. A poltergeist gets to bend a floor for a few
	# seconds; it does not get to keep it.
	var timer := get_tree().create_timer(6.0)
	timer.timeout.connect(func():
		if is_instance_valid(lab) and not lab.chaos_enabled:
			lab.set_mode("none"))
	return true


## Put everything back right now, whatever its timer says. Used when the
## director stands down and by the tests.
func restore_all() -> void:
	for entry in _held:
		if is_instance_valid(entry.node):
			entry.node.transform = entry.transform
			entry.node.visible = entry.get("visible", true)
	_held.clear()
	for entry in _light_holds:
		if is_instance_valid(entry.fixture) and entry.fixture.light:
			entry.fixture.light.light_energy = entry.energy
	_light_holds.clear()
	for caption in _captions:
		if is_instance_valid(caption):
			caption.queue_free()
	_captions.clear()


func held_count() -> int:
	return _held.size() + _light_holds.size()
