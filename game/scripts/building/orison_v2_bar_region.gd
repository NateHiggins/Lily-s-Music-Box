class_name OrisonV2BarRegion
extends Node3D
## The retained Harukiya has its own street entrance and basement datum.
## It shares the imported city frame, never the arcade's shop roster.

const CELL := "res://assets/building/floor_01_cells/shop_bar.gltf"
const REGISTRY := "res://data/floor_01_cell_registry.json"
const LAYOUT := "res://data/building_layout.json"
const Surface := preload("res://scripts/building/surface_pass.gd")
const WCDoor := preload("res://scripts/building/orison_v2_bar_wc_door.gd")
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
	add_child(geometry)
	surface_pass = Surface.new()
	surface_pass.apply({"shop_bar": geometry})
	actors = Node3D.new()
	actors.name = "BarActors"
	add_child(actors)
	var seen := {}
	for floor: Dictionary in source_layout.floors:
		if floor.id != "F01": continue
		for marker: Dictionary in floor.markers:
			if marker.id not in owners: continue
			if seen.has(marker.id) or not _mount_marker(marker):
				_fail("duplicate or unsupported bar marker: " + str(marker.id))
				return
			seen[marker.id] = true
	if seen.size() != owners.size():
		_fail("registered bar marker missing from generated layout")
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
	floor_copy.furniture = floor_copy.furniture.filter(func(f): return str(f.id).begins_with("retail_bar"))
	var bar_layout := {"floors": [floor_copy]}
	var arcade := ArcadeRow.new()
	actors.add_child(arcade)
	arcade.install(bar_layout, {"F01": actors})
	for cabinet: ArcadeCabinetProp in arcade.cabinets:
		# The retained installer selects its graph node in source coordinates.
		# V2 has already registered the graph mouths in the shared world frame.
		cabinet.graph_node_id = arcade._nearest_graph_node(cabinet.global_position)
	add_to_group("orison_v2_bar_region")
	print("[V2 BAR] retained cell; ", seen.size(), " registered markers; ", doors.size(), " doors")

func _mount_marker(marker: Dictionary) -> bool:
	var prop: Node3D
	var kind := str(marker.kind)
	if kind == "door":
		var door: DoorProp = WCDoor.new() if marker.id == "F01_BAR_WC_DOOR" else DoorProp.new()
		door.width = float(marker.w)
		door.height = float(marker.h)
		door.leaf_state = str(marker.leaf)
		door.swing_out = str(marker.get("swing", "")) == "out"
		door.door_kind = str(marker.get("subtype", "storefront"))
		door.finish_variant = int(marker.get("finish_variant", 0))
		doors[str(marker.id)] = door
		prop = door
	elif kind in LightFixtureProp.TONE:
		var light := LightFixtureProp.new()
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
	return true

func shutdown() -> void:
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
