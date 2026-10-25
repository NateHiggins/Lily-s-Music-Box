extends Node3D
## Optical review bench for the sky spectacle; no completion claim. It walks the
## year's schedule (data/weather/phenomena.json): for each phenomenon the campaign
## clock jumps to its first dated occurrence, the production WeatherManager picks
## it up and forces its weather, the V2 director lights the sky from the real
## ephemeris, and the lens is aimed by the bearing or the sun. One frame each,
## over the real V2 city horizon (St. Elmo's fire sits on its chimney caps).
##
##   SHOT_DIR=<abs> [SPECTACLE_ONLY=id,id] godot --path game res://tests/V2SkySpectacleBench.tscn

const Manager := preload("res://scripts/building/WeatherManager.gd")
const Phenomena := preload("res://scripts/building/sky_phenomena.gd")
const EYE := Vector3(0.0, 22.0, 0.0)
## id -> [aim, pitch degrees, fov, yaw offset]. aim: bearing | sun | sun_az | anti | anti_az | tip
const SHOTS := {
	"mammatus": ["bearing", 28.0, 80.0, 0.0], "shelf_cloud": ["bearing", 6.0, 85.0, 0.0],
	"wall_cloud": ["bearing", 7.0, 70.0, 0.0], "lenticular": ["bearing", 13.0, 60.0, 0.0],
	"morning_glory": ["bearing", 8.0, 85.0, 0.0], "virga": ["bearing", 12.0, 75.0, 0.0],
	"microburst": ["bearing", 7.0, 75.0, 0.0], "haboob": ["bearing", 6.0, 85.0, 0.0],
	"asperitas": ["bearing", 55.0, 90.0, 0.0], "kelvin_helmholtz": ["bearing", 15.0, 70.0, 0.0],
	"fallstreak_hole": ["bearing", 18.0, 75.0, 0.0], "striated_supercell": ["bearing", 10.0, 85.0, 0.0],
	"anvil_cumulonimbus": ["bearing", 14.0, 75.0, 0.0], "overshooting_top": ["bearing", 22.0, 50.0, 0.0],
	"pileus": ["bearing", 16.0, 60.0, 0.0], "pyrocumulonimbus": ["bearing", 15.0, 75.0, 0.0],
	"tornado": ["bearing", 6.0, 60.0, 0.0], "waterspout": ["bearing", 5.0, 55.0, 0.0],
	"nacreous": ["sun_az", 10.0, 80.0, 0.0], "noctilucent": ["sun_az", 12.0, 85.0, 0.0],
	"aurora": ["bearing", 18.0, 90.0, 0.0], "steve": ["bearing", 58.0, 95.0, 0.0],
	"spider_lightning": ["bearing", 35.0, 90.0, 0.0], "red_sprite": ["bearing", 8.0, 45.0, 0.0],
	"blue_jet": ["bearing", 6.0, 40.0, 0.0], "gigantic_jet": ["bearing", 10.0, 50.0, 0.0],
	"elves": ["bearing", 10.0, 60.0, 0.0], "st_elmos_fire": ["tip", 0.0, 9.0, 0.0],
	"volcanic_lightning": ["bearing", 15.0, 75.0, 0.0], "rainbow": ["anti_az", 20.0, 100.0, 0.0],
	"halo_22": ["sun", 0.0, 75.0, 0.0], "sun_dogs": ["sun", 0.0, 75.0, 0.0],
	"circumhorizontal_arc": ["sun_az", 26.0, 85.0, 0.0], "circumzenithal_arc": ["sun_az", 68.0, 85.0, 0.0],
	"light_pillars": ["sun_az", 6.0, 40.0, 0.0], "crepuscular_rays": ["sun_az", 12.0, 95.0, 0.0],
	"anticrepuscular_rays": ["anti_az", 10.0, 95.0, 0.0], "glory": ["anti", 0.0, 30.0, 0.0],
	"iridescence": ["sun", 0.0, 60.0, 0.0], "green_flash": ["sun", 0.0, 6.0, 0.0],
	"fata_morgana": ["bearing", 3.5, 28.0, 0.0],
}
var sky_material: ShaderMaterial
var manager: Node
var director: DayNightDirector
var clock: CampaignClock
var camera: Camera3D
var horizon: Node3D
var environment: Environment
var flashing := false


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	clock = CampaignClock.new()
	clock.configure_date(1928, 11, 10, 720)
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.volumetric_fog_enabled = true
	environment.volumetric_fog_density = .0001
	environment.volumetric_fog_length = 24.0
	sky_material = ShaderMaterial.new()
	sky_material.shader = preload("res://shaders/v2_seasonal_sky.gdshader")
	sky_material.set_shader_parameter("moon_surface", load("res://assets/environment/lroc_color_poles_1k.jpg"))
	environment.sky = Sky.new()
	environment.sky.sky_material = sky_material
	environment.sky.radiance_size = Sky.RADIANCE_SIZE_128
	environment.sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)
	var key := DirectionalLight3D.new()
	add_child(key)
	horizon = preload("res://scripts/building/orison_v2_city_horizon.gd").new()
	add_child(horizon)
	director = preload("res://scripts/building/v2_city_day_night_director.gd").new()
	add_child(director)
	director.setup(self, environment, key, sky_material)
	var observer := Node3D.new()
	add_child(observer)
	observer.global_position = EYE - Vector3(0, 1.6, 0)
	var effects := preload("res://scripts/building/v2_weather_fx.gd").new()
	effects.setup(observer, Callable(effects, "exposed"), Callable(effects, "covered"))
	add_child(effects)
	director.bind_weather(effects)
	manager = Manager.new()
	manager.configure(clock, director, sky_material, effects)
	add_child(manager)
	camera = Camera3D.new()
	add_child(camera)
	camera.make_current()
	camera.global_position = EYE
	get_viewport().use_taa = true
	await get_tree().process_frame
	var only := OS.get_environment("SPECTACLE_ONLY").split(",", false)
	var saved := 0
	for slot in Phenomena.SLOTS:
		var id: String = manager.schedule.ids_by_slot[slot]
		if not only.is_empty() and id not in only: continue
		var entry: Dictionary = {}
		for candidate: Dictionary in manager.schedule.occurrences:
			if candidate.id == id: entry = candidate; break
		if id == "haboob":
			# The wall approaching, then the street inside it.
			await _shoot(id, entry, .1, "%02d_%s_approach" % [slot, id])
			saved += 1
		await _shoot(id, entry, .5, "%02d_%s" % [slot, id])
		saved += 1
	print("V2 SKY SPECTACLE BENCH: %d frames" % saved)
	get_tree().quit(0)


func _shoot(id: String, entry: Dictionary, fraction: float, label: String) -> void:
	var minute := float(entry.start) + (float(entry.end) - float(entry.start)) * fraction
	var date := CampaignClock._date_from_ordinal(int(floor(minute / 1440.0)))
	clock.configure_date(int(date.year), int(date.month), int(date.day_of_month), int(fposmod(minute, 1440.0)))
	# The schedule decides; then settle the weather transition and the sky at once.
	manager._process(.016)
	manager.origin = manager.target.duplicate(true)
	manager.elapsed = Manager.TRANSITION_SECONDS
	manager._phenomena_left = 0.0
	manager._process(.016)
	manager._publish()
	director._apply(clock.minute_of_day())
	var row: Dictionary = manager.schedule.phenomena[id]
	flashing = bool(row.get("flash", false))
	_aim(id, entry)
	for frame in 40:
		if flashing: manager.trigger_flash()
		sky_material.set_shader_parameter("temporal_phase", float(frame))
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var active: Array = manager.active_phenomena.map(func(e): return e.id)
	print("  %s at %s %s, sun %.1f deg, active %s, levels %s, dust %.2f" % [label, entry.date,
			"%02d:%02d" % [int(fposmod(minute, 1440.0)) / 60, int(fposmod(minute, 60.0))],
			Phenomena.sun_elevation(minute), active,
			manager.active_phenomena.map(func(e): return snappedf(e.level, .01)),
			float(manager.current.get("dust", 0.0))])
	if id == "st_elmos_fire":
		var corona := horizon.find_child("StElmoCorona", true, false) as MultiMeshInstance3D
		print("  corona: visible %s, tips %d, first %s, aim %s, level %s" % [corona.visible,
				corona.multimesh.instance_count, corona.multimesh.get_instance_transform(0).origin,
				_nearest_corona_tip(), (corona.material_override as ShaderMaterial).get_shader_parameter("corona")])
	var directory := OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(directory)
	get_viewport().get_texture().get_image().save_png(directory.path_join(label + ".png"))


func _aim(id: String, entry: Dictionary) -> void:
	var shot: Array = SHOTS[id]
	camera.fov = float(shot[2])
	var sun: Vector3 = (sky_material.get_shader_parameter("sun_direction") as Vector3).normalized()
	var target: Vector3
	match str(shot[0]):
		"sun": target = sun
		"anti": target = -sun
		"sun_az", "anti_az":
			var flat := Vector3(sun.x, 0, sun.z).normalized() * (1.0 if str(shot[0]) == "sun_az" else -1.0)
			target = flat * cos(deg_to_rad(float(shot[1]))) + Vector3.UP * sin(deg_to_rad(float(shot[1])))
		"tip":
			target = _nearest_corona_tip() - EYE
		_:
			var bearing := float(entry.bearing) + deg_to_rad(float(shot[3]))
			var flat := Vector3(sin(bearing), 0, -cos(bearing))
			target = flat * cos(deg_to_rad(float(shot[1]))) + Vector3.UP * sin(deg_to_rad(float(shot[1])))
	camera.look_at(EYE + target.normalized() * 100.0, Vector3.UP if absf(target.normalized().y) < .98 else Vector3.FORWARD)


func _nearest_corona_tip() -> Vector3:
	var corona := horizon.find_child("StElmoCorona", true, false) as MultiMeshInstance3D
	var best := Vector3(0, 30, -200)
	var best_distance := INF
	for index in corona.multimesh.instance_count:
		var tip := corona.global_transform * corona.multimesh.get_instance_transform(index).origin
		var distance := tip.distance_to(EYE)
		if distance < best_distance and tip.y > EYE.y - 4.0:
			best = tip
			best_distance = distance
	return best
