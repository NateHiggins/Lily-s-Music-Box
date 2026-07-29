extends Node3D
## Assembles Orison Apartments: instances per-floor glTF scenes, spawns
## functional props from the shared layout markers, places the player and
## elevator, and manages coarse level-of-interest floor visibility (a
## streaming stand-in until real occluder/HLOD passes land).

const FLOOR_SCENES := {
	"B1": "res://assets/building/floor_b1.glb",
	"F01": "res://assets/building/floor_01.glb",
	"F02": "res://assets/building/floor_02.glb",
	"F03": "res://assets/building/floor_03.glb",
	"F04": "res://assets/building/floor_04.glb",
	"F05": "res://assets/building/floor_05.glb",
	"F06": "res://assets/building/floor_06.glb",
	"ROOF": "res://assets/building/roof.glb",
}
const PROP_SCRIPTS := {
	"radiator": preload("res://scripts/props/radiator_prop.gd"),
	"lamp": preload("res://scripts/props/lamp_prop.gd"),
	"corridor_light": preload("res://scripts/props/corridor_light_prop.gd"),
	"washer": preload("res://scripts/props/washer_prop.gd"),
	"dryer": preload("res://scripts/props/washer_prop.gd"),
	"boiler": preload("res://scripts/props/boiler_prop.gd"),
	"toaster": preload("res://scripts/props/toaster_prop.gd"),
	"fridge": preload("res://scripts/props/fridge_prop.gd"),
	"monitor": preload("res://scripts/props/monitor_prop.gd"),
	"boxfan": preload("res://scripts/props/boxfan_prop.gd"),
	"door_anomaly": preload("res://scripts/props/door_anomaly_prop.gd"),
	"speaker": preload("res://scripts/props/speaker_prop.gd"),
	"flue_breast": preload("res://scripts/props/flue_breast_prop.gd"),
	"porch_deck": preload("res://scripts/props/porch_deck_prop.gd"),
	"kettle": preload("res://scripts/props/kettle_prop.gd"),
	"wall_clock": preload("res://scripts/props/clock_prop.gd"),
	"smoke_detector": preload("res://scripts/props/smoke_detector_prop.gd"),
	"exhaust_fan": preload("res://scripts/props/exhaust_fan_prop.gd"),
	"ceiling_light": preload("res://scripts/props/ceiling_light_prop.gd"),
}

var layout: Dictionary = {}
var player: PlayerController
var elevator: OrisonElevator
var call_interface: CallInterface
var walkthrough: ArchitecturalWalkthrough
var floor_nodes: Dictionary = {}
var show_all_floors := false


func _ready() -> void:
	var f := FileAccess.open("res://data/building_layout.json", FileAccess.READ)
	layout = JSON.parse_string(f.get_as_text())
	_build_environment()
	for fid in FLOOR_SCENES:
		var scene := load(FLOOR_SCENES[fid]) as PackedScene
		if scene == null:
			push_warning("missing floor scene %s" % fid)
			continue
		var node := scene.instantiate()
		node.name = fid
		add_child(node)
		floor_nodes[fid] = node
	call_interface = CallInterface.new()
	add_child(call_interface)
	_spawn_props()
	elevator = OrisonElevator.new()
	add_child(elevator)
	elevator.setup(layout["elevator"])
	player = PlayerController.new()
	add_child(player)
	player.global_position = GameBoot.b2g([0.0, -9.0, 0.1])  # vestibule
	walkthrough = ArchitecturalWalkthrough.new()
	add_child(walkthrough)
	walkthrough.setup(self)
	var room0 := Room0.new()
	add_child(room0)
	var anomaly: DoorAnomalyProp = get_node_or_null("F04_B_DOOR_ANOMALY")
	if anomaly:
		anomaly.room0 = room0
	var debug := preload("res://scripts/ui/building_debug.gd").new()
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	layer.add_child(debug)
	debug.setup(self)
	print("[BUILDING] Orison assembled: %d floors, player in lobby" %
			floor_nodes.size())


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.015, 0.02, 0.035)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.38, 0.48)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.65, 0.7, 0.9)
	moon.light_energy = 0.35
	moon.rotation_degrees = Vector3(-38, 30, 0)
	add_child(moon)


func _spawn_props() -> void:
	var count := 0
	for fl in layout["floors"]:
		for m in fl["markers"]:
			if m["kind"] == "desk_zone":
				var desk := DeskZone.new()
				desk.call_interface = call_interface
				add_child(desk)
				desk.global_position = GameBoot.b2g(m["pos"])
				continue
			if m["kind"] == "door":
				var door := DoorProp.new()
				door.width = float(m["w"])
				door.height = float(m["h"])
				door.leaf_state = m["leaf"]
				door.name = m["id"]
				# transform BEFORE add_child: a sync_to_physics leaf keeps
				# its global transform if the parent moves after entry
				door.position = GameBoot.b2g(m["pos"])
				door.rotation.y = deg_to_rad(-float(m.get("yaw_deg", 0)))
				add_child(door)
				continue
			var script: GDScript = PROP_SCRIPTS.get(m["kind"])
			if script == null:
				continue
			var prop: FunctionalProp = script.new()
			prop.prop_type = m["kind"]
			prop.name = m["id"]
			if AcousticGraphData.nodes.has(m["id"]):
				prop.graph_node_id = m["id"]  # bound to the shared graph
			add_child(prop)
			prop.global_position = GameBoot.b2g(m["pos"])
			prop.rotation.y = deg_to_rad(-float(m.get("yaw_deg", 0)))
			count += 1
	print("[BUILDING] %d functional props spawned" % count)


func teleport_player(fid: String) -> void:
	var z: float = layout["meta"]["levels"][fid]
	if fid == "ROOF":
		player.global_position = GameBoot.b2g([0.0, -8.0, z + 0.1])
	else:
		player.global_position = GameBoot.b2g([4.3, 0.0, z + 0.1])
	player.velocity = Vector3.ZERO


func _physics_process(_delta: float) -> void:
	_update_floor_visibility()


## Coarse streaming: only the player's level and its vertical neighbors
## render. Closed apartments culling properly is a later occluder pass.
func _update_floor_visibility() -> void:
	if player == null:
		return
	var py := player.global_position.y
	for fid in floor_nodes:
		var z: float = layout["meta"]["levels"][fid]
		floor_nodes[fid].visible = show_all_floors \
				or absf(py - z) < 4.9 or (fid == "ROOF" and py > 15.0)
