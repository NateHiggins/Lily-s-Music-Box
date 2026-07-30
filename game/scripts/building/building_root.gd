extends Node3D
## Assembles Orison Apartments: instances per-floor glTF scenes, spawns
## functional props from the shared layout markers, places the player and
## elevator, and manages coarse level-of-interest floor visibility (a
## streaming stand-in until real occluder/HLOD passes land).

const FLOOR_SCENES := {
	"B1": "res://assets/building/floor_b1.gltf",
	"F01": "res://assets/building/floor_01.gltf",
	"F02": "res://assets/building/floor_02.gltf",
	"F03": "res://assets/building/floor_03.gltf",
	"F04": "res://assets/building/floor_04.gltf",
	"F05": "res://assets/building/floor_05.gltf",
	"F06": "res://assets/building/floor_06.gltf",
	"ROOF": "res://assets/building/roof.gltf",
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
	"pendant_shade": preload("res://scripts/props/light_fixture_prop.gd"),
	"flush_dome": preload("res://scripts/props/light_fixture_prop.gd"),
	"sconce_globe": preload("res://scripts/props/light_fixture_prop.gd"),
	"kitchen_linear": preload("res://scripts/props/light_fixture_prop.gd"),
	"cage_bulb": preload("res://scripts/props/light_fixture_prop.gd"),
	"chandelier": preload("res://scripts/props/light_fixture_prop.gd"),
	"eye_pendant": preload("res://scripts/props/light_fixture_prop.gd"),
}

var layout: Dictionary = {}
var player: PlayerController
var elevator: OrisonElevator
var call_interface: CallInterface
var walkthrough: ArchitecturalWalkthrough
var light_rig: LightRig
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
	light_rig = LightRig.new()
	add_child(light_rig)
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
	## Tuned for the fixture pools: lower flat ambient so tungsten pools
	## own the rooms, gentle depth fog for aerial perspective down long
	## corridors and the atrium eye, soft glow so emissive envelopes and
	## halos bloom the way bright sources do to a dark-adapted eye.
	var env := Environment.new()
	var panorama := load(
			"res://assets/building/textures/sky/" +
			"orison_hyperreal_night_panorama_4k.png") as Texture2D
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.015, 0.02, 0.035)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.30, 0.33, 0.44)
	env.ambient_light_energy = 0.30
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.06, 0.10)
	env.fog_density = 0.010
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 1.15
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	_build_sky_dome(panorama)
	_build_atrium_atmosphere()
	var moon := DirectionalLight3D.new()
	moon.name = "ExteriorMoon"
	moon.light_color = Color(0.65, 0.7, 0.9)
	moon.light_energy = 0.35
	moon.rotation_degrees = Vector3(-38, 30, 0)
	moon.shadow_enabled = true
	moon.shadow_bias = 0.035
	moon.shadow_normal_bias = 0.55
	moon.directional_shadow_max_distance = 48.0
	moon.directional_shadow_fade_start = 0.80
	add_child(moon)


func _build_sky_dome(panorama: Texture2D) -> void:
	## PanoramaSkyMaterial is unreliable on the Compatibility backend used
	## by this project. An inward-facing unlit sphere preserves the same
	## equirectangular projection and leaves environment lighting separate.
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, fog_disabled,
		shadows_disabled;
uniform sampler2D panorama : source_color, filter_linear_mipmap,
		repeat_enable;
varying vec3 local_direction;
void vertex() {
	local_direction = VERTEX;
}
void fragment() {
	vec3 direction = normalize(local_direction);
	float u = atan(direction.z, direction.x) / (2.0 * PI) + 0.5;
	// The square double-height source uses its midpoint as eye level:
	// upper hemisphere is sky, lower hemisphere is the surrounding city.
	float v = acos(clamp(direction.y, -1.0, 1.0)) / PI;
	ALBEDO = texture(panorama, vec2(u, v)).rgb;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("panorama", panorama)
	var sphere := SphereMesh.new()
	sphere.radius = 120.0
	sphere.height = 240.0
	sphere.radial_segments = 96
	sphere.rings = 48
	var dome := MeshInstance3D.new()
	dome.name = "NightSkyDome"
	dome.mesh = sphere
	dome.material_override = material
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(dome)


## The atrium eye under its skylight earns the money atmosphere: a faked
## volumetric shaft (additive gradient cone, no volumetrics on the
## Compatibility backend), slow dust motes riding it, and a soft
## vignette that pulls every frame toward the lens.
func _build_atrium_atmosphere() -> void:
	var shaft := MeshInstance3D.new()
	shaft.name = "AtriumShaft"
	var cone := CylinderMesh.new()
	cone.top_radius = 1.9
	cone.bottom_radius = 2.65
	cone.height = 20.6
	cone.radial_segments = 24
	shaft.mesh = cone
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	sm.cull_mode = BaseMaterial3D.CULL_DISABLED
	sm.no_depth_test = false
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	grad.colors = PackedColorArray([
			Color(0.72, 0.78, 0.95, 0.0),
			Color(0.72, 0.78, 0.95, 0.020),
			Color(0.80, 0.85, 1.0, 0.055)])
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0.5, 1.0)   # bright toward the skylight
	gt.fill_to = Vector2(0.5, 0.0)
	sm.albedo_texture = gt
	shaft.material_override = sm
	shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shaft.position = Vector3(0.0, 10.4, 0.0)
	add_child(shaft)
	var dust := CPUParticles3D.new()
	dust.name = "AtriumDust"
	dust.amount = 110
	dust.lifetime = 14.0
	dust.preprocess = 14.0
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(2.4, 10.2, 2.4)
	dust.gravity = Vector3(0, -0.015, 0)
	dust.initial_velocity_min = 0.01
	dust.initial_velocity_max = 0.06
	dust.direction = Vector3(0, -1, 0)
	dust.spread = 180.0
	var dq := QuadMesh.new()
	dq.size = Vector2(0.02, 0.02)
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	dm.albedo_color = Color(0.95, 0.92, 0.85, 0.30)
	dq.material = dm
	dust.mesh = dq
	dust.position = Vector3(0.0, 10.4, 0.0)
	add_child(dust)
	var vg_layer := CanvasLayer.new()
	vg_layer.layer = 6
	add_child(vg_layer)
	var vg := TextureRect.new()
	vg.name = "Vignette"
	vg.set_anchors_preset(Control.PRESET_FULL_RECT)
	vg.stretch_mode = TextureRect.STRETCH_SCALE
	vg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vgrad := Gradient.new()
	vgrad.offsets = PackedFloat32Array([0.0, 0.72, 1.0])
	vgrad.colors = PackedColorArray([
			Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.0),
			Color(0, 0, 0, 0.26)])
	var vt := GradientTexture2D.new()
	vt.gradient = vgrad
	vt.fill = GradientTexture2D.FILL_RADIAL
	vt.fill_from = Vector2(0.5, 0.5)
	vt.fill_to = Vector2(0.5, 0.0)
	vt.width = 512
	vt.height = 512
	vg.texture = vt
	vg_layer.add_child(vg)


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
				door.swing_out = String(m.get("swing", "")) == "out"
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
			if m.has("range") and prop is LightFixtureProp:
				prop.range_clamp = float(m["range"])
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
## render — EXCEPT in the atrium, where the open eye is a sightline
## through every storey (lobby runner to skylight), so the whole stack
## renders there. The zone spans the stair volume plus the elevator
## hall, whose archway frames the same view. F01 stays always-on for
## glimpses down through the court windows.
func _update_floor_visibility() -> void:
	if player == null:
		return
	var p := player.global_position
	var in_eye := absf(p.x) < 3.7 and p.z > -3.7 and p.z < 6.9
	for fid in floor_nodes:
		var z: float = layout["meta"]["levels"][fid]
		floor_nodes[fid].visible = show_all_floors or in_eye \
				or fid == "F01" \
				or absf(p.y - z) < 4.9 or (fid == "ROOF" and p.y > 15.0)
