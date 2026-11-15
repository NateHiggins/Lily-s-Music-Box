extends Node
## DRAFT: actual native fixtures + production venue director, no world/clock writes.
const EntryLight = preload("res://scripts/building/orison_v2_bar_entry_light.gd")
const Sign = preload("res://scripts/props/harukiya_signage_prop.gd")
const Neon = preload("res://scripts/props/neon_sign_prop.gd")
var errors: Array[String] = []
var checks := 0
var lamps: Array[EntryLight] = []
var actors: Node3D
var director: HarukiyaStateDirector
var stair: LightFixtureProp

func _enter_tree() -> void:
	RealityState.persistence_enabled = false

func _ready() -> void:
	var saved_data: Dictionary = RealityState.data.duplicate(true)
	var spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/harukiya_entry.json"))
	actors = Node3D.new(); actors.name = "BarActors"; add_child(actors)
	for row: Dictionary in spec.fixtures:
		var lamp := EntryLight.new()
		lamp.name = str(row.id); lamp.fixture_record = row.duplicate(true)
		lamp.prop_type = "kitchen_linear"
		lamp.position = GameBoot.b2g(row.source_at)
		# Blender Z rotation maps to Godot Y with the SAME angle here.
		lamp.rotation.y = deg_to_rad(float(row.source_yaw_deg))
		actors.add_child(lamp); lamp.set_process(false)
		if not _check(not lamp.native_failed, str(row.id) + " native construction"):
			_finish(saved_data); return
		lamps.append(lamp)
		_check(lamp._tube_surfaces.size() == 1 and lamp._tubes.size() == 1, str(row.id) + " one tube")
		var emitter: Vector3 = GameBoot.b2g(row.emission_center_source)
		_check(lamp.light.global_position.distance_to(emitter) < .0001, str(row.id) + " real light world center")
		var tube: MeshInstance3D = lamp._tubes[0]
		_check((tube.global_transform * tube.mesh.get_aabb().get_center()).distance_to(emitter) < .0001, str(row.id) + " imported tube world center")
		_check(tube.material_override == null and tube.get_active_material(0) is ShaderMaterial, str(row.id) + " live custom surface")
		var material: ShaderMaterial = tube.get_active_material(0)
		_check(int(material.get_shader_parameter("uv_mode")) == 0, str(row.id) + " native UV mode")
		_check(float(material.get_shader_parameter("emission_energy")) == 0.0 and lamp.light.light_energy == 0.0, str(row.id) + " startup no flash")
		var selected := {}
		for node in lamp.find_children("*", "MeshInstance3D", true, false):
			if node.has_meta("harukiya_entry_fixture_part"): selected[str(node.get_meta("harukiya_entry_fixture_part"))] = true
		var expected := {}
		for part: Dictionary in spec.fixture_parts:
			if str(part.fixture_id) == str(row.id): expected[str(part.name)] = true
		_check(selected == expected, str(row.id) + " exact native fixture partition")
	if not _check(lamps.size() == 2, "two accents"): _finish(saved_data); return
	_check(lamps[0]._tube_surfaces[0] != lamps[1]._tube_surfaces[0], "independent shader resources")
	# Real retained stair actor, configured from the shipping marker.
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/building_layout.json"))
	var marker := {}
	for floor: Dictionary in layout.floors:
		if str(floor.id) != "F01": continue
		for row: Dictionary in floor.markers:
			if str(row.id) == "F01_BAR_LT_STAIR": marker = row
	if not _check(not marker.is_empty(), "shipping stair marker"): _finish(saved_data); return
	stair = LightFixtureProp.new(); stair.name = "F01_BAR_LT_STAIR"
	stair.prop_type = str(marker.kind); stair.position = GameBoot.b2g(marker.pos)
	stair.range_clamp = float(marker.get("range",0)); stair.energy_scale = float(marker.get("energy",1))
	stair.standby_scale = float(marker.get("standby",0)); stair.navigation_light = bool(marker.get("navigation",false))
	actors.add_child(stair); stair.set_process(false)
	var stair_tone := stair.light.light_color
	var stair_energy := stair._base_energy
	# Actual sign implementations satisfy director's typed dependencies.
	var sign := Sign.new(); sign.name = "F01_BAR_SIGNAGE"; sign.prop_type = "bar_signage"
	actors.add_child(sign); sign.set_process(false)
	var stage := Neon.new(); stage.name = "F01_BAR_STAGE_SIGN"; stage.prop_type = "neon_sign"
	actors.add_child(stage); stage.set_process(false)
	director = HarukiyaStateDirector.new(); actors.add_child(director)
	director.setup(actors); director.set_process(false)
	for lamp in lamps: _check(lamp.has_meta("vertical_zone"), str(lamp.name) + " vertical venue membership")
	_check(director._fixtures().size() == 3, "director discovers both accents and retained stair")
	# Exercise production classification AND application without writing the clock.
	for scenario: Array in [[1200.0,1.0,true],[180.0,.6,false],[720.0,.35,false]]:
		director._apply(HarukiyaStateDirector.state_for(scenario[0]))
		_check(is_equal_approx(stair._state_gain, scenario[1]), "retained stair gain at " + str(scenario[0]))
		_check(stair.powered and stair.light.light_color == stair_tone and stair._base_energy == stair_energy, "stair authority unchanged")
		for lamp in lamps: lamp.set_budget(1.0,false,false)
		_tick()
		for lamp in lamps:
			if scenario[2]:
				_check(lamp.light.visible and lamp.light.light_energy > 0.01, str(lamp.name) + " OPEN direct light")
				_check(_emission(lamp) > 0.01, str(lamp.name) + " OPEN tube emission")
				_check(lamp._tube_surfaces[0].get_shader_parameter("emission_color").is_equal_approx(lamp._bulb_mat.emission), "live color bridge")
			else: _dark(lamp,"hours " + str(scenario[0]))
			_check(lamp.bounce.light_energy == 0.0 and not lamp.bounce.visible, "no accent bounce")
	# Budget gate while business is OPEN; surge must not revive a budgeted-out tube.
	director._apply(HarukiyaStateDirector.state_for(1200.0))
	for lamp in lamps: lamp.set_budget(1.0,false,false)
	_tick()
	for lamp in lamps:
		lamp.set_budget(0.0,false,false); lamp._surge = 1.0; lamp._process(1.0/60.0)
		_check(_emission(lamp) == 0.0, "budget zero blocks surge immediately")
	_tick()
	for lamp in lamps: _dark(lamp,"budget zero")
	for lamp in lamps:
		lamp.set_powered(true); lamp.set_budget(1.0,false,false)
	_tick()
	for lamp in lamps:
		lamp.set_powered(false); lamp._surge = 1.0; lamp._process(1.0/60.0)
		_check(_emission(lamp) == 0.0, "powered false blocks surge immediately")
	_tick()
	for lamp in lamps: _dark(lamp,"powered false")
	director._apply(HarukiyaStateDirector.state_for(720.0))
	for lamp in lamps:
		lamp._surge = 1.0; lamp._process(1.0/60.0)
		_check(_emission(lamp) == 0.0, "CLOSED blocks surge immediately")
	_finish(saved_data)

func _tick() -> void:
	# Deterministic convergence through actual inherited implementation, no
	# elapsed-world time, duplicate process ticks or scheduler/clock mutation.
	for frame in 180:
		for lamp in lamps: lamp._process(1.0/60.0)

func _emission(lamp: EntryLight) -> float:
	return float(lamp._tube_surfaces[0].get_shader_parameter("emission_energy"))

func _dark(lamp: EntryLight, context: String) -> void:
	_check(_emission(lamp) == 0.0, str(lamp.name) + " dark shader " + context)
	_check(not lamp.light.visible and lamp.light.light_energy < .0001, str(lamp.name) + " direct light off/converged " + context)

func _check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok: errors.append(label); push_error(label)
	return ok

func _finish(saved_data: Dictionary) -> void:
	_check(RealityState.data == saved_data, "no campaign/clock/save data mutation")
	actors.free()
	print(JSON.stringify({"test":"harukiya_entry_light", "scope":"actual native fixture and production director, explicit budget API", "checks":checks,"failures":errors}))
	get_tree().quit(0 if errors.is_empty() else 1)
