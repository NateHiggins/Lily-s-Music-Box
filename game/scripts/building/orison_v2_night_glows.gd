extends Node3D
## Night glows in V2 (Lily, v1r_night_glows_20261109: "Import all four").
##
## V1's glows said one thing: somebody is awake behind this. V1 guessed who,
## from a seed. V2 has real lamps on real switches, so its glows take their
## truth from those and from the doors themselves.
##
##  - The awake authority. This was V1's window glow, whose own panes were
##    ruled off on 2026-08-05 ("the real fixtures inside light the reveals").
##    In V2 a room is awake when one of its own lamps is on.
##  - Door spill (V1's door glow): a bar of light on the hall floor and a
##    hairline round the leaf of a closed door with a lit room behind it. It
##    goes when the room's switch is thrown and while the door stands open.
##  - Moon fill: one cool fill that follows the player through rooms with a
##    window, scaled by the day-night director as V1's was.
##  - Vault lights wait for their pavement panels, which V2's walk does not
##    have yet (the Blender batch).
##
## The spill is an optical effect, not a surface: unshaded additive quads with
## the brightness in vertex colour, one mesh per hall so a whole corridor costs
## one draw. It is rebuilt only when a lamp or a door changes, and is drawn
## only while its hall is.

const SPILL_DEPTH := 0.24
const SPILL_STEPS := 6
const SEAM := 0.005
## The hairline is the faintest part: a gap, not a neon tube.
const SEAM_STRENGTH := 0.32
const FLOOR_CLEAR := 0.018
## From the door's own plane to just past the hall face of its wall and casing.
const CLEAR := 0.125
const CLOSED_ANGLE := 0.03
const TONE_WARM := Color(1.0, 0.79, 0.52)
const TONE_COOL := Color(0.76, 0.85, 0.97)
const COOL_ROOMS := ["KITCHEN", "BATH"]
const CIRCULATION := ["HALL", "VESTIBULE", "LANDING", "GALLERY", "CORE", "CROSSING",
	"RETURN", "APPROACH", "LOBBY", "PASSAGE"]
const POLL_SECONDS := 0.3

const MOON_ENERGY := 0.16
const MOON_TINT := Color(0.62, 0.70, 0.86)

var world: Node3D
var blockout: Node3D
var switches: SwitchSystem
var moon_fill: OmniLight3D
## door id -> {door, hall, room, side, width, height, tint, leaking}
var spills: Dictionary = {}
var skipped := {"no_hall_side": 0, "no_lamp": 0, "no_leaf": 0}

var _fixtures: Dictionary = {}     # room id -> Array of lamp nodes
var _by_room: Dictionary = {}      # room id -> Array of door ids
var _by_hall: Dictionary = {}      # hall id -> Array of door ids
var _batches: Dictionary = {}      # hall id -> MeshInstance3D
var _rects: Dictionary = {}        # space id -> rect
var _levels: Dictionary = {}       # level id -> y
var _space_level: Dictionary = {}  # space id -> level id
var _dirty: Dictionary = {}
var _poll := 0.0
var _material: StandardMaterial3D
var _windowed: Dictionary = {}
var _moon_poll := 0.0


class WindowMoon extends OmniLight3D:
	## Day/night: the director dims the fill toward daylight.
	var energy_scale := 1.0


func setup(root: Node3D, blockout_node: Node3D, layout: Dictionary, adapter: Variant) -> void:
	name = "NightGlows"
	world = root
	blockout = blockout_node
	switches = root.get_node_or_null("V2RoomSwitches") as SwitchSystem
	for level: Dictionary in layout.get("levels", []):
		_levels[str(level.id)] = float(level.y)
	for space: Dictionary in layout.get("spaces", []):
		_rects[str(space.id)] = space.rect
		_space_level[str(space.id)] = str(space.level)
	for window: Dictionary in layout.get("windows", []):
		if str(window.get("level", "")) != "B1":
			_windowed[str(window.get("space", ""))] = true
	_bind_lamps(adapter)
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.vertex_color_use_as_albedo = true
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.disable_receive_shadows = true
	for record: Dictionary in layout.get("doors", []):
		_bind_door(record, adapter)
	if switches != null:
		switches.room_toggled.connect(_on_room_toggled)
	for hall: String in _by_hall:
		_dirty[hall] = true
	_refresh()
	moon_fill = WindowMoon.new()
	moon_fill.name = "MoonFill"
	moon_fill.light_color = MOON_TINT
	moon_fill.light_energy = 0.0
	moon_fill.omni_range = 6.5
	moon_fill.shadow_enabled = false
	moon_fill.visible = false
	add_child(moon_fill)
	print("[NIGHT GLOWS] %d doors can spill, %d spilling; %d windowed rooms take the moon (skipped: %s)" % [
			spills.size(), leaking_count(), _windowed.size(), skipped])


## The lamps V2's switch system wires to each room, as nodes.
func _bind_lamps(adapter: Variant) -> void:
	if switches == null:
		return
	for room: String in switches._room_fixtures:
		var lamps: Array = []
		for identity: Variant in switches._room_fixtures[room]:
			var lamp: Node = adapter.resolve(str(identity))
			if lamp != null and "powered" in lamp:
				lamps.append(lamp)
		if not lamps.is_empty():
			_fixtures[room] = lamps


## A room is awake when one of its own lamps is on.
func is_lit(room_id: String) -> bool:
	for lamp: Variant in _fixtures.get(room_id, []):
		if is_instance_valid(lamp) and bool(lamp.powered):
			return true
	return false


func lit_rooms() -> Array[String]:
	var rooms: Array[String] = []
	for room: String in _fixtures:
		if is_lit(room):
			rooms.append(room)
	return rooms


func leaking(door_id: String) -> bool:
	return bool(spills.get(door_id, {}).get("leaking", false))


func leaking_count() -> int:
	var count := 0
	for door_id: String in spills:
		if bool(spills[door_id].leaking):
			count += 1
	return count


static func is_circulation(space_id: String) -> bool:
	for word: String in CIRCULATION:
		if space_id.contains(word):
			return true
	return false


## Which of a door's two spaces the light falls into, and which it comes from:
## [hall, room], or [] when the door is not a threshold between the two kinds.
## A dwelling's entry spills into the public hall; inside a dwelling, and among
## the public rooms, a room spills into the circulation beside it.
static func sides(a: String, b: String) -> Array:
	var unit_a := OrisonV2RuntimeRoot.unit_of_room(a)
	var unit_b := OrisonV2RuntimeRoot.unit_of_room(b)
	if unit_a == "" and unit_b != "":
		return [a, b]
	if unit_b == "" and unit_a != "":
		return [b, a]
	if is_circulation(a) and not is_circulation(b):
		return [a, b]
	if is_circulation(b) and not is_circulation(a):
		return [b, a]
	return []


func _bind_door(record: Dictionary, adapter: Variant) -> void:
	var connects: Array = record.get("connects", [])
	if connects.size() != 2:
		return
	var pair := sides(str(connects[0]), str(connects[1]))
	if pair.is_empty() or not _rects.has(pair[0]):
		skipped.no_hall_side += 1
		return
	if not _fixtures.has(pair[1]):
		skipped.no_lamp += 1
		return
	var anchor := adapter.resolve(str(record.id)) as Node3D
	var door: Node = null
	if anchor != null:
		for child in anchor.get_children():
			if child is DoorProp:
				door = child
	if door == null:
		skipped.no_leaf += 1
		return
	# Which way the hall lies along the door's own normal, by standing a point
	# on each side and asking which one is inside the hall's footprint.
	var to_plan := blockout.global_transform.affine_inverse() * anchor.global_transform
	var side := 0.0
	for candidate: float in [1.0, -1.0]:
		var probe := to_plan * Vector3(0.0, 1.0, candidate * 0.6)
		var rect: Array = _rects[pair[0]]
		if probe.x >= float(rect[0]) and probe.x <= float(rect[2]) \
				and probe.z >= float(rect[1]) and probe.z <= float(rect[3]):
			side = candidate
	if side == 0.0:
		skipped.no_hall_side += 1
		return
	var door_id := str(record.id)
	var room := str(pair[1])
	# Steady per door, and dimmer than a window: this is a gap under a door.
	var strength := 0.46 + 0.26 * (float(hash(room + "spill") % 100) / 100.0)
	var tone := TONE_WARM
	for word: String in COOL_ROOMS:
		if room.contains(word):
			tone = TONE_COOL
	spills[door_id] = {"door": door, "anchor": anchor, "hall": str(pair[0]), "room": room,
		"side": side, "width": float(record.get("width", 0.81)),
		"height": float(record.get("height", 2.03)),
		"tint": Color(tone.r * strength, tone.g * strength, tone.b * strength, 1.0),
		"leaking": false}
	_by_room[room] = _by_room.get(room, []) + [door_id]
	_by_hall[pair[0]] = _by_hall.get(pair[0], []) + [door_id]


func _on_room_toggled(room_id: String, _now_on: bool) -> void:
	for door_id: String in _by_room.get(room_id, []):
		_dirty[spills[door_id].hall] = true


func _process(delta: float) -> void:
	_poll -= delta
	if _poll <= 0.0:
		_poll = POLL_SECONDS
		_refresh()
	_moon_poll -= delta
	if _moon_poll <= 0.0:
		_moon_poll = POLL_SECONDS
		_follow_moon()
	if moon_fill != null and moon_fill.visible:
		moon_fill.global_position = _eye_position() + Vector3(0.0, 1.6, 0.0)


## Works out which doors leak now and rebuilds the halls whose answer changed.
func _refresh() -> void:
	for door_id: String in spills:
		var spill: Dictionary = spills[door_id]
		var now := false
		if is_instance_valid(spill.door) and is_lit(str(spill.room)):
			now = absf(float(spill.door.mechanism_snapshot().get("angle", 0.0))) < CLOSED_ANGLE
		if now != bool(spill.leaking):
			spill.leaking = now
			_dirty[spill.hall] = true
	for hall: String in _dirty:
		_rebuild(hall)
	_dirty.clear()
	# A hall the building has put away takes its spill with it.
	for hall: String in _batches:
		var batch: MeshInstance3D = _batches[hall]
		if batch.mesh != null:
			var room_node := blockout.get_node_or_null(hall) as Node3D
			batch.visible = room_node == null or room_node.is_visible_in_tree()


func _rebuild(hall: String) -> void:
	var batch: MeshInstance3D = _batches.get(hall)
	var here := global_transform.affine_inverse()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any := false
	for door_id: String in _by_hall.get(hall, []):
		var spill: Dictionary = spills[door_id]
		if not bool(spill.leaking) or not is_instance_valid(spill.anchor):
			continue
		_door(st, here * (spill.anchor as Node3D).global_transform, spill)
		any = true
	if not any:
		if batch != null:
			batch.mesh = null
			batch.visible = false
		return
	if batch == null:
		batch = MeshInstance3D.new()
		batch.name = "DoorSpill_" + hall
		batch.material_override = _material
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		batch.set_meta("surface_role", "door_light_spill")
		add_child(batch)
		_batches[hall] = batch
	batch.mesh = st.commit()
	batch.visible = true


## One door, in the door's own frame: x along the leaf, y up from the floor,
## `side` the way to the hall.
func _door(st: SurfaceTool, frame: Transform3D, spill: Dictionary) -> void:
	var side: float = spill.side
	var half := float(spill.width) * 0.5
	var height: float = spill.height
	var tint: Color = spill.tint
	var face := side * CLEAR
	# The bar on the floor fades with distance from the threshold: a hard-edged
	# rectangle reads as a decal, and this has to read as a gap.
	for step in SPILL_STEPS:
		var t0 := float(step) / float(SPILL_STEPS)
		var t1 := float(step + 1) / float(SPILL_STEPS)
		var z0 := face + side * SPILL_DEPTH * t0
		var z1 := face + side * SPILL_DEPTH * t1
		_strip(st, frame, Vector3(-half, FLOOR_CLEAR, z0), Vector3(half, FLOOR_CLEAR, z0),
				Vector3(half, FLOOR_CLEAR, z1), Vector3(-half, FLOOR_CLEAR, z1),
				tint * pow(1.0 - t0, 2.2), tint * pow(1.0 - t1, 2.2), Vector3.UP)
	# Hairline down both jambs and across the head: the leaf never quite meets
	# its frame, and that outline is what makes a closed door read as closed.
	var seam := Color(tint.r * SEAM_STRENGTH, tint.g * SEAM_STRENGTH, tint.b * SEAM_STRENGTH, 1.0)
	var normal := Vector3(0.0, 0.0, side)
	for edge: float in [-1.0, 1.0]:
		var x := half * edge
		_strip(st, frame, Vector3(x, 0.02, face), Vector3(x + SEAM * edge, 0.02, face),
				Vector3(x + SEAM * edge, height, face), Vector3(x, height, face), seam, seam, normal)
	_strip(st, frame, Vector3(-half, height, face), Vector3(half, height, face),
			Vector3(half, height + SEAM, face), Vector3(-half, height + SEAM, face), seam, seam, normal)


func _strip(st: SurfaceTool, frame: Transform3D, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		near: Color, far: Color, normal: Vector3) -> void:
	var facing := (frame.basis * normal).normalized()
	for corner: Array in [[a, near], [c, far], [b, near], [a, near], [d, far], [c, far]]:
		var tone: Color = corner[1]
		st.set_color(Color(tone.r, tone.g, tone.b, 1.0))
		st.set_normal(facing)
		st.add_vertex(frame * (corner[0] as Vector3))


func _eye_position() -> Vector3:
	var override: Variant = world.get("view_override")
	if override is Camera3D and is_instance_valid(override):
		return (override as Camera3D).global_position
	var player: Variant = world.get("player")
	if player is Node3D and is_instance_valid(player):
		return (player as Node3D).global_position
	return global_position


## The fill exists only in rooms the moon can reach through a window.
func _follow_moon() -> void:
	if moon_fill == null:
		return
	# The day-night director dims the fill toward daylight, as it did V1's.
	var director: Variant = world.get("day_night_director")
	if director != null and is_instance_valid(director):
		moon_fill.set("energy_scale", float(director.resolved_profile().get("fill", 1.0)))
	var room := str(world.room_at_world(_eye_position()))
	var want := MOON_ENERGY * float(moon_fill.get("energy_scale")) if _windowed.has(room) else 0.0
	moon_fill.light_energy = lerpf(moon_fill.light_energy, want, 0.25)
	moon_fill.visible = moon_fill.light_energy > 0.01
	if moon_fill.visible:
		moon_fill.global_position = _eye_position() + Vector3(0.0, 1.6, 0.0)


func stats() -> Dictionary:
	return {"doors": spills.size(), "leaking": leaking_count(), "halls": _batches.size(),
			"lit_rooms": lit_rooms().size(), "windowed_rooms": _windowed.size()}
