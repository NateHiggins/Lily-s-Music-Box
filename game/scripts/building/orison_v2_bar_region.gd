class_name OrisonV2BarRegion
extends Node3D
## The retained Harukiya has its own street entrance and basement datum.
## It shares the imported city frame, never the arcade's shop roster.

const CELL := "res://assets/building/floor_01_cells/shop_bar.gltf"
const REGISTRY := "res://data/floor_01_cell_registry.json"
const LAYOUT := "res://data/building_layout.json"
const Surface := preload("res://scripts/building/surface_pass.gd")
const WCDoor := preload("res://scripts/building/orison_v2_bar_wc_door.gd")
const Entry := preload("res://scripts/building/orison_v2_bar_entry.gd")
const ENTRY_DATA := "res://data/orison_v2/harukiya_entry.json"
const EntryDoor := preload("res://scripts/building/orison_v2_bar_entry_door.gd")
const EntryLight := preload("res://scripts/building/orison_v2_bar_entry_light.gd")
const PROP_SCRIPTS := {
	"bar_signage": preload("res://scripts/props/harukiya_signage_prop.gd"),
	"neon_sign": preload("res://scripts/props/neon_sign_prop.gd"),
	"songbook_terminal": preload("res://scripts/props/songbook_terminal_prop.gd"),
	"darts": preload("res://scripts/props/darts_prop.gd"),
	"point_ball": preload("res://scripts/props/point_ball_prop.gd"),
	"sink": preload("res://scripts/building/orison_v2_bar_sink.gd"),
	"speaker": preload("res://scripts/props/speaker_prop.gd"),
}

var startup_failed := false
var doors: Dictionary = {}
var actors: Node3D
var source_layout: Dictionary
var surface_pass: RefCounted
var hours: HarukiyaStateDirector
var resident_places: Node3D
var wall_occlusion: Node3D
var destination: Node3D
var _acoustic_originals: Dictionary = {}

func _ready() -> void:
	var section := preload("res://scripts/building/orison_v2_street_frame.gd").load_default()
	var registry: Variant = JSON.parse_string(FileAccess.get_file_as_string(REGISTRY))
	var layout: Variant = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT))
	if section.is_empty() or registry is not Dictionary or layout is not Dictionary:
		_fail("missing authored city frame, registry or layout")
		return
	position.z = -float(section.source_threshold_z)
	source_layout = layout
	var owners: Array = []
	for record: Dictionary in registry.get("cells", []):
		if record.id == "CELL_SHOP_BAR" and record.resource_path == CELL:
			if not owners.is_empty():
				_fail("ambiguous registered bar cell")
				return
			owners = record.semantic_owners
	if owners.is_empty():
		_fail("bar cell has no registered actor roster")
		return
	var scene := load(CELL) as PackedScene
	if scene == null:
		_fail("missing imported bar cell")
		return
	var geometry := scene.instantiate() as Node3D
	geometry.name = "RetainedBarGeometry"
	if not preload("res://scripts/building/orison_v2_bar_pool.gd").mount_cell(geometry, source_layout):
		geometry.free()
		_fail("native pool table does not fit its retained source boundaries")
		return
	if not preload("res://scripts/building/orison_v2_bar_fixture_mounts.gd").mount_cell(geometry):
		geometry.free()
		_fail("native fixture mounts are missing or have invalid catalogue charts")
		return
	if not preload("res://scripts/building/orison_v2_bar_pipe_supports.gd").mount_cell(geometry):
		geometry.free()
		_fail("native pipe supports are missing or have invalid catalogue charts")
		return
	if not preload("res://scripts/building/orison_v2_bar_ceiling_finish.gd").apply(geometry, source_layout):
		geometry.free()
		_fail("native ceiling finish differs from its retained source faces")
		return
	if not preload("res://scripts/building/orison_v2_bar_gallery.gd").mount_cell(geometry, source_layout):
		geometry.free()
		_fail("native gallery does not match its retained source frames and shared picture law")
		return
	if not preload("res://scripts/building/orison_v2_bar_stage.gd").mount_cell(geometry, source_layout):
		geometry.free()
		_fail("native stage curtains do not fit their retained source boundaries")
		return
	if not preload("res://scripts/building/orison_v2_bar_furniture.gd").mount_cell(geometry, source_layout):
		geometry.free()
		_fail("native stage furniture and target differ from their exact source triangles")
		return
	if not preload("res://scripts/building/orison_v2_bar_receiving.gd").mount_cell(geometry, source_layout, false):
		geometry.free()
		_fail("native receiving cases differ from their source cases and shared hull")
		return
	destination = preload("res://scripts/building/orison_v2_bar_destination.gd").new()
	if not destination.mount(geometry, source_layout):
		if destination.get_parent() == null: destination.free()
		geometry.free()
		_fail("destination architecture does not match its source retirement and native layout")
		return
	if not Entry.mount_cell(geometry, source_layout):
		geometry.free()
		_fail("native entrance differs from its retained source stocks")
		return
	add_child(geometry)
	surface_pass = Surface.new()
	surface_pass.apply({"shop_bar": geometry})
	preload("res://scripts/building/orison_v2_bar_furniture.gd").calibrate(geometry)
	preload("res://scripts/building/orison_v2_bar_receiving.gd").calibrate(geometry)
	destination.calibrate()
	Entry.calibrate(geometry)
	actors = Node3D.new()
	actors.name = "BarActors"
	add_child(actors)
	var seen := {}
	for floor: Dictionary in source_layout.floors:
		if floor.id != "F01": continue
		for marker: Dictionary in floor.markers:
			if marker.id not in owners: continue
			var fitted: Dictionary = destination.marker_record(marker)
			if fitted.is_empty() or seen.has(marker.id) or not _mount_marker(fitted):
				_fail("duplicate or unsupported bar marker: " + str(marker.id))
				return
			seen[marker.id] = true
	if seen.size() != owners.size():
		_fail("registered bar marker missing from generated layout")
		return
	if not _mount_entry_lights():
		_fail("native entrance fixtures have invalid placement or construction")
		return
	hours = HarukiyaStateDirector.new()
	actors.add_child(hours)
	hours.setup(actors)
	# This retained helper writes source coordinates to global positions.
	# Reinterpret only its newly created sockets in the registered local frame.
	var before := actors.get_children()
	var hands := HarukiyaInteractables.new()
	actors.add_child(hands)
	hands.build(actors)
	for child in actors.get_children():
		if child is Node3D and child not in before and child != hands:
			child.position = child.global_position
	if not preload("res://scripts/building/orison_v2_bar_gallery.gd").fit_inspections(geometry,actors):
		_fail("native gallery lost an original picture inspection target")
		return
	var floor_copy: Dictionary = source_layout.floors.filter(func(f): return f.id == "F01")[0].duplicate(true)
	# The retained helper predates the pool table's move to the west bay.
	# Fit its inspection volume to the actual authored body, keeping its text.
	var pools: Array = floor_copy.furniture.filter(func(f): return f.id == "retail_bar_pool_body")
	if pools.size() != 1:
		_fail("retained pool table has no unique physical body")
		return
	var pool: Dictionary = pools[0]
	var rect: Array = pool.rect
	actors.get_node("BAR_POOL_TABLE").position = GameBoot.b2g([
		(rect[0] + rect[2]) * .5, (rect[1] + rect[3]) * .5, float(pool.z0) + .85])
	if not preload("res://scripts/building/orison_v2_bar_pool.gd").fit_inspection(actors.get_node("BAR_POOL_TABLE")):
		_fail("native pool inspection target is missing or invalid")
		return
	if not destination.fit_actors(self):
		_fail("destination interactions lost their retained owners")
		return
	resident_places = preload("res://scripts/building/orison_v2_bar_resident_places.gd").new()
	resident_places.name = "ResidentPlaces"
	add_child(resident_places)
	if not resident_places.setup(self):
		_fail("resident places do not match their physical furniture")
		return
	wall_occlusion = preload("res://scripts/building/orison_v2_bar_occlusion.gd").new()
	wall_occlusion.name = "OpaqueWallOcclusion"
	add_child(wall_occlusion)
	if wall_occlusion.setup(self):
		wall_occlusion.set_enabled(true)
	else:
		push_warning("V2 BAR: wall occlusion skipped: "+str(wall_occlusion.errors))
		wall_occlusion.shutdown(); wall_occlusion.free(); wall_occlusion = null
	# Cabinets are retired from play. Their native/baked bodies were removed
	# above; do not construct game screens, interaction targets or audio actors.
	add_to_group("orison_v2_bar_region")
	print("[V2 BAR] retained cell; ", seen.size(), " registered markers; ", doors.size(), " doors")

func _mount_marker(marker: Dictionary) -> bool:
	var prop: Node3D
	var kind := str(marker.kind)
	if kind == "door":
		var door: DoorProp = WCDoor.new() if marker.id == "F01_BAR_WC_DOOR" else DoorProp.new()
		if marker.id == "F01_BAR_RED_DOOR":
			door.free()
			door = EntryDoor.new()
		door.width = float(marker.w)
		door.height = float(marker.h)
		door.leaf_state = str(marker.leaf)
		door.swing_out = str(marker.get("swing", "")) == "out"
		door.door_kind = str(marker.get("subtype", "storefront"))
		door.finish_variant = int(marker.get("finish_variant", 0))
		doors[str(marker.id)] = door
		prop = door
	elif kind in LightFixtureProp.TONE:
		var light := preload("res://scripts/building/harukiya_light_fixture.gd").new()
		light.optics = destination.lighting_profile(str(marker.id))
		light.prop_type = kind
		light.range_clamp = float(marker.get("range", 0.0))
		light.energy_scale = float(marker.get("energy", 1.0))
		light.standby_scale = float(marker.get("standby", 0.0))
		light.navigation_light = bool(marker.get("navigation", false))
		prop = light
	elif PROP_SCRIPTS.has(kind):
		prop = PROP_SCRIPTS[kind].new()
		prop.prop_type = kind
		if prop is TapProp:
			prop.unit = str(marker.get("unit", ""))
			prop.fixture = str(marker.get("fixture", "bath_sink"))
		if prop is NeonSignProp:
			prop.sign_text = str(marker.text)
			prop.vertical = bool(marker.get("vertical", false))
			var tint: Array = marker.get("tint", [1, .3, .42])
			prop.tint = Color(tint[0], tint[1], tint[2])
	else:
		return false
	prop.name = str(marker.id)
	prop.position = GameBoot.b2g(marker.pos)
	# The sconce's back plate is local -Z. Positive source yaw seats it
	# toward the original east/west wall and lets its globe face the room.
	var yaw_sign:=1 if prop is TapProp or kind=="sconce_globe" else -1
	prop.rotation.y = deg_to_rad(float(marker.get("yaw_deg", 0)) * yaw_sign)
	if prop is FunctionalProp and AcousticGraphData.nodes.has(marker.id):
		prop.graph_node_id = str(marker.id)
		_acoustic_originals[str(marker.id)] = AcousticGraphData.nodes[marker.id].duplicate(true)
		var record: Dictionary = AcousticGraphData.nodes[marker.id].duplicate(true)
		var point := to_global(prop.position)
		record.pos = [point.x, -point.z, point.y]
		AcousticGraphData.nodes[marker.id] = record
	actors.add_child(prop)
	if prop is EntryDoor and prop.native_failed:
		doors.erase(str(marker.id))
		prop.free()
		return false
	return true

func _mount_entry_lights() -> bool:
	var spec := Entry.read_spec(ENTRY_DATA)
	var rows: Variant = spec.get("fixtures")
	if rows is not Array or rows.size() != 2: return false
	var expected := {"F01_BAR_LT_ENTRY_CYAN": false, "F01_BAR_LT_ENTRY_MAGENTA": false}
	# Validate the complete placement set before attaching any live actor.
	for value: Variant in rows:
		if value is not Dictionary: return false
		var row: Dictionary = value
		var identity := str(row.get("id", ""))
		if not expected.has(identity) or expected[identity] or actors.has_node(NodePath(identity)):
			return false
		if not EntryLight._finite_components(row.get("source_at"), 3, 3) \
				or not EntryLight._finite_components(row.get("emission_center_source"), 3, 3):
			return false
		var yaw: Variant = row.get("source_yaw_deg")
		if not (yaw is float or yaw is int) or not is_finite(float(yaw)): return false
		expected[identity] = true
	var mounted: Array[Node3D] = []
	for row: Dictionary in rows:
		var lamp := EntryLight.new()
		lamp.name = str(row.id)
		lamp.fixture_record = row.duplicate(true)
		lamp.prop_type = "kitchen_linear"
		lamp.position = GameBoot.b2g(row.source_at)
		# Authored Blender Z rotation maps directly to Godot Y, unlike door markers.
		lamp.rotation.y = deg_to_rad(float(row.source_yaw_deg))
		actors.add_child(lamp)
		mounted.append(lamp)
		if lamp.native_failed or lamp.light == null \
				or lamp.light.global_position.distance_to(actors.to_global(GameBoot.b2g(row.emission_center_source))) > .0001:
			for added: Node3D in mounted: added.free()
			return false
	return true

func shutdown() -> void:
	if is_instance_valid(actors):
		var cast_owner:=actors.get_node_or_null("HarukiyaCast")
		if cast_owner!=null and cast_owner.has_method("shutdown"):cast_owner.call("shutdown")
	if is_instance_valid(wall_occlusion): wall_occlusion.shutdown()
	for identity: String in _acoustic_originals:
		AcousticGraphData.nodes[identity] = _acoustic_originals[identity]
	_acoustic_originals.clear()
	for identity: String in doors: AudioPolicy.release_source(StringName(identity))
	doors.clear()

func _exit_tree() -> void:
	shutdown()

func _fail(reason: String) -> void:
	startup_failed = true
	push_error("V2 BAR: " + reason)
