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
	"neon_sign": preload("res://scripts/props/neon_sign_prop.gd"),
	"street_lamp": preload("res://scripts/props/light_fixture_prop.gd"),
}
const NPC_RESIDENTS := [
	{"unit": "1A", "name": "Evelyn Marsh", "sprite": "evelyn_marsh"},
	{"unit": "1D", "name": "Teresa Vale", "sprite": "teresa_vale"},
	{"unit": "2A", "name": "Mina Vale", "sprite": "mina_vale"},
	{"unit": "2B", "name": "Lena Ortiz", "sprite": "lena_ortiz"},
	{"unit": "2C", "name": "Juno Kells", "sprite": "juno_kells"},
	{"unit": "3A", "name": "Malcolm Reed", "sprite": "malcolm_reed"},
	{"unit": "3B", "name": "Omar Bell", "sprite": "omar_bell"},
	{"unit": "3D", "name": "Rhea Sato", "sprite": "rhea_sato"},
	{"unit": "4A", "name": "Peter Wren", "sprite": "peter_wren"},
	{"unit": "4C", "name": "Cam Ortiz", "sprite": "cam_ortiz", "slot": -1},
	{"unit": "4C", "name": "Noel Price", "sprite": "noel_price", "slot": 1},
	{"unit": "4D", "name": "Transient Guests", "sprite": "transient_guests"},
	{"unit": "5A", "name": "Nadia Quell", "sprite": "nadia_quell"},
	{"unit": "5B", "name": "Cal Dwyer", "sprite": "cal_dwyer"},
	{"unit": "5C", "name": "Iris Bell", "sprite": "iris_bell"},
	{"unit": "6A", "name": "Sacha Reed", "sprite": "sacha_reed"},
	{"unit": "6B", "name": "Jonah Price", "sprite": "jonah_price"},
	{"unit": "6C", "name": "Mae Kessler", "sprite": "mae_kessler"},
]

var layout: Dictionary = {}
var player: PlayerController
var elevator: OrisonElevator
var call_interface: CallInterface
var light_rig: LightRig
var virus_director: VirusSoundDirector
var floor_nodes: Dictionary = {}
var occluders: OrisonOccluders
var window_glow: OrisonWindowGlow
var touch: TouchControls
var mina_manifestation: MinaCaptionManifestation
var mina_gameplay: MinaCaseGameplay
var objective_tracker: ObjectiveTracker
var map_distortion_lab: MapDistortionLab
var affected_prop_count := 0
var reality_controllers: Dictionary = {}
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
	occluders = OrisonOccluders.new()
	occluders.name = "Occluders"
	add_child(occluders)
	var n_occ := occluders.build(layout)
	window_glow = OrisonWindowGlow.new()
	window_glow.name = "WindowGlow"
	add_child(window_glow)
	var n_lit := window_glow.build(layout)
	call_interface = CallInterface.new()
	add_child(call_interface)
	_spawn_props()
	_spawn_npc_placeholders()
	_spawn_reality_controllers()
	_spawn_reality_affected_props()
	objective_tracker = ObjectiveTracker.new()
	objective_tracker.name = "ObjectiveTracker"
	add_child(objective_tracker)
	mina_manifestation = MinaCaptionManifestation.new()
	mina_manifestation.name = "MinaCaptionManifestation"
	mina_manifestation.setup(self)
	add_child(mina_manifestation)
	mina_gameplay = MinaCaseGameplay.new()
	mina_gameplay.name = "MinaCaseGameplay"
	mina_gameplay.setup(objective_tracker)
	add_child(mina_gameplay)
	map_distortion_lab = MapDistortionLab.new()
	map_distortion_lab.name = "MapDistortionLab"
	map_distortion_lab.setup(self)
	add_child(map_distortion_lab)
	light_rig = LightRig.new()
	add_child(light_rig)
	elevator = OrisonElevator.new()
	add_child(elevator)
	elevator.setup(layout["elevator"])
	player = PlayerController.new()
	player.position = GameBoot.b2g([0.0, -9.0, 0.1])  # vestibule
	add_child(player)
	virus_director = VirusSoundDirector.new()
	add_child(virus_director)
	virus_director.setup(self)
	var room0 := Room0.new()
	add_child(room0)
	var anomaly: DoorAnomalyProp = get_node_or_null("F04_B_DOOR_ANOMALY")
	if anomaly:
		anomaly.room0 = room0
	touch = TouchControls.new()
	touch.name = "TouchControls"
	add_child(touch)
	touch.look_delta.connect(player.apply_look)
	player.touch_input = touch.enabled
	var debug := preload("res://scripts/ui/building_debug.gd").new()
	debug.setup(self)
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	layer.add_child(debug)
	print("[BUILDING] Orison assembled: %d floors, %d occluders, "
			% [floor_nodes.size(), n_occ] +
			"%d windows lit, player in lobby" % n_lit)


func _build_environment() -> void:
	## Tuned for the fixture pools: lower flat ambient so tungsten pools
	## own the rooms, gentle depth fog for aerial perspective down long
	## corridors and the atrium eye, soft glow so emissive envelopes and
	## halos bloom the way bright sources do to a dark-adapted eye.
	var env := Environment.new()
	var panorama := load(
			"res://assets/building/textures/sky/" +
			"orison_half_dome_night_4k.png") as Texture2D
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.015, 0.02, 0.035)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.18, 0.21, 0.28)
	env.ambient_light_energy = 0.055
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
	moon.light_energy = 0.10
	moon.rotation_degrees = Vector3(-38, 30, 0)
	moon.shadow_enabled = true
	moon.shadow_bias = 0.035
	moon.shadow_normal_bias = 0.55
	moon.directional_shadow_max_distance = 48.0
	moon.directional_shadow_fade_start = 0.80
	add_child(moon)


func _build_sky_dome(panorama: Texture2D) -> void:
	## PanoramaSkyMaterial is unreliable on the Compatibility backend used
	## by this project. This camera-centered upper-hemisphere projection
	## keeps the horizon stable from street to roof and never samples a
	## lower hemisphere. Its quiet zenith band hides polar convergence.
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, fog_disabled,
		shadows_disabled;
uniform sampler2D panorama : source_color, filter_linear_mipmap,
		repeat_enable;
void fragment() {
	vec3 direction = normalize(
			(INV_VIEW_MATRIX * vec4(-VIEW, 0.0)).xyz);
	float u = atan(direction.z, direction.x) / (2.0 * PI) + 0.5;
	// Half-dome source: top edge is zenith; bottom edge is horizon.
	// Views below the horizon hold on that final skyline texel instead of
	// exposing the dome's lower half. Fade that edge into distance haze
	// immediately so skyline pixels never stretch into vertical bars.
	float elevation = asin(clamp(direction.y, 0.0, 1.0));
	float v = 1.0 - elevation / (0.5 * PI);
	vec3 color = texture(panorama, vec2(u, v)).rgb;
	if (direction.y < 0.0) {
		float haze = smoothstep(0.0, 0.025, -direction.y);
		color = mix(color, vec3(0.018, 0.025, 0.040), haze);
	}
	ALBEDO = color;
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
	dome.name = "NightSkyHalfDome"
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
			if m.has("energy") and prop is LightFixtureProp:
				prop.energy_scale = float(m["energy"])
			if m.has("standby"):
				prop.set("standby_scale", float(m["standby"]))
			if m.get("navigation", false):
				prop.set("navigation_light", true)
			if prop is NeonSignProp:
				prop.sign_text = String(m.get("text", "ORISON"))
				prop.vertical = bool(m.get("vertical", true))
				var t: Array = m.get("tint", [1.0, 0.3, 0.42])
				prop.tint = Color(float(t[0]), float(t[1]), float(t[2]))
			if AcousticGraphData.nodes.has(m["id"]):
				prop.graph_node_id = m["id"]  # bound to the shared graph
			# Compatibility renderer light transforms must be authored before
			# _ready() creates the Light3D children. Moving the prop afterward
			# moved its mesh but left the rendered light pool at the origin.
			prop.position = GameBoot.b2g(m["pos"])
			prop.rotation.y = deg_to_rad(-float(m.get("yaw_deg", 0)))
			add_child(prop)
			count += 1
	print("[BUILDING] %d functional props spawned" % count)


func _spawn_npc_placeholders() -> void:
	var count := 0
	for spec in NPC_RESIDENTS:
		var unit: String = spec.unit
		var floor_id := "F0" + unit.left(1)
		var floor_data: Dictionary = {}
		for candidate in layout["floors"]:
			if candidate.id == floor_id:
				floor_data = candidate
				break
		if floor_data.is_empty():
			continue
		var room: Dictionary = {}
		for candidate in floor_data["rooms"]:
			if candidate.get("unit", "") != unit:
				continue
			if candidate.get("kind", "") == "living" \
					or str(candidate.id).ends_with("_MAIN"):
				room = candidate
				break
		if room.is_empty():
			# Studios without a MAIN tag still receive the largest unit room.
			var best_area := -1.0
			for candidate in floor_data["rooms"]:
				if candidate.get("unit", "") != unit:
					continue
				var rect: Array = candidate.rect
				var area := (float(rect[2]) - float(rect[0])) \
						* (float(rect[3]) - float(rect[1]))
				if area > best_area:
					best_area = area
					room = candidate
		if room.is_empty():
			continue
		var rect: Array = room.rect
		var slot: float = float(spec.get("slot", 0))
		var x := lerpf(float(rect[0]), float(rect[2]), 0.52) + slot * 0.48
		var y := lerpf(float(rect[1]), float(rect[3]), 0.58)
		var npc := NPCPlaceholder.new()
		npc.setup(spec.name, "res://assets/npcs/%s.png" % spec.sprite,
				spec.sprite, unit)
		npc.position = GameBoot.b2g([x, y, float(floor_data.z) + 0.03])
		var parent: Node = floor_nodes.get(floor_id, self)
		parent.add_child(npc)
		count += 1
	print("[BUILDING] %d resident placeholders spawned" % count)


func _spawn_reality_affected_props() -> void:
	var file := FileAccess.open(
			"res://data/reality_affected_props.json", FileAccess.READ)
	if file == null:
		push_warning("reality affected-prop catalog missing")
		return
	var catalog: Dictionary = JSON.parse_string(file.get_as_text())
	affected_prop_count = 0
	var catalog_ids := {}
	for cluster in catalog.get("case_clusters", []):
		var unit: String = cluster.unit
		var floor_id := "F0" + unit.left(1)
		var floor_data: Dictionary = {}
		for candidate in layout["floors"]:
			if candidate.id == floor_id:
				floor_data = candidate
				break
		if floor_data.is_empty():
			continue
		var room: Dictionary = {}
		for candidate in floor_data["rooms"]:
			if candidate.get("unit", "") == unit \
					and candidate.get("kind", "") == "living":
				room = candidate
				break
		if room.is_empty():
			for candidate in floor_data["rooms"]:
				if candidate.get("unit", "") == unit \
						and str(candidate.id).ends_with("_MAIN"):
					room = candidate
					break
		if room.is_empty():
			continue
		var rect: Array = room.rect
		for spec in cluster.props:
			if catalog_ids.has(spec.id):
				push_error("duplicate reality-affected prop id: " + spec.id)
				continue
			catalog_ids[spec.id] = true
			var prop := RealityAffectedProp.new()
			prop.setup(spec.id, spec.name, spec.kind, cluster.case_id)
			var x := lerpf(float(rect[0]), float(rect[2]), float(spec.u))
			var y := lerpf(float(rect[1]), float(rect[3]), float(spec.v))
			var height := 0.80 if spec.get("surface", "floor") == "table" \
					else 0.04
			prop.position = GameBoot.b2g(
					[x, y, float(floor_data.z) + height])
			floor_nodes[floor_id].add_child(prop)
			if reality_controllers.has(cluster.case_id):
				reality_controllers[cluster.case_id].register_node(prop)
			affected_prop_count += 1
	for spec in catalog.get("shared_props", []):
		if catalog_ids.has(spec.id):
			push_error("duplicate reality-affected prop id: " + spec.id)
			continue
		catalog_ids[spec.id] = true
		var prop := RealityAffectedProp.new()
		prop.setup(spec.id, spec.name, spec.kind)
		prop.position = GameBoot.b2g(spec.position)
		var floor_id: String = spec.get("floor", "F01")
		floor_nodes.get(floor_id, self).add_child(prop)
		affected_prop_count += 1
	var expected_count := int(catalog.get("expected_prop_count",
			affected_prop_count))
	if affected_prop_count != expected_count:
		push_error("reality-affected prop placement mismatch: expected %d, placed %d"
				% [expected_count, affected_prop_count])
	print("[BUILDING] %d reality-affected props placed" %
			affected_prop_count)


func _spawn_reality_controllers() -> void:
	for case_id in RealityCases.definitions:
		var definition: Dictionary = RealityCases.definition(case_id)
		var unit: String = definition.get("unit", "")
		if unit.length() < 2:
			continue
		var floor_id := "F0" + unit.left(1)
		var floor_data: Dictionary = {}
		for candidate in layout["floors"]:
			if candidate.id == floor_id:
				floor_data = candidate
				break
		if floor_data.is_empty():
			continue
		var room: Dictionary = {}
		for candidate in floor_data["rooms"]:
			if candidate.get("unit", "") == unit \
					and candidate.get("kind", "") == "living":
				room = candidate
				break
		if room.is_empty():
			for candidate in floor_data["rooms"]:
				if candidate.get("unit", "") == unit \
						and str(candidate.id).ends_with("_MAIN"):
					room = candidate
					break
		if room.is_empty():
			continue
		var rect: Array = room.rect
		var corner_a := GameBoot.b2g(
				[float(rect[0]), float(rect[1]), float(floor_data.z)])
		var corner_b := GameBoot.b2g(
				[float(rect[2]), float(rect[3]), float(floor_data.z) + 3.0])
		var bounds_min := Vector3(
				minf(corner_a.x, corner_b.x),
				minf(corner_a.y, corner_b.y),
				minf(corner_a.z, corner_b.z))
		var bounds_max := Vector3(
				maxf(corner_a.x, corner_b.x),
				maxf(corner_a.y, corner_b.y),
				maxf(corner_a.z, corner_b.z))
		var controller := ApartmentRealityController.new()
		controller.setup(case_id, unit, bounds_min, bounds_max)
		floor_nodes[floor_id].add_child(controller)
		reality_controllers[case_id] = controller
	print("[BUILDING] %d apartment reality controllers ready" %
			reality_controllers.size())


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
