extends Node
## T8 contract proof: one authoritative weather clock, four production skies,
## bounded depth fog, deterministic layered rain, and building-owned exposure.

var _fails := 0


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
	if not ok:
		_fails += 1


func _ready() -> void:
	OS.set_environment("DAYNIGHT_FORCE", "night")
	OS.set_environment("WEATHER_SEED", "19280731")
	OS.set_environment("WEATHER_SIMULATE", "rain")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	var root: Node3D = load(
			"res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	await get_tree().create_timer(1.2).timeout

	var director: DayNightDirector = root.day_night_director
	var paths := director.state_texture_paths() if director else {}
	_check("the time owner exposes exactly four production sky states",
			paths.keys().size() == 4 and paths.has("morning")
			and paths.has("day") and paths.has("evening")
			and paths.has("night"))
	for state in ["morning", "day", "evening", "night"]:
		var resource_path: String = paths.get(state, "")
		_check("%s sky is a production 4K half-dome" % state,
				resource_path.get_basename().ends_with("_half_dome_4k")
				and resource_path.get_extension().to_lower() in ["png", "jpg"]
				and ResourceLoader.exists(resource_path))
		var source_path := ProjectSettings.globalize_path(resource_path)
		var image := Image.load_from_file(source_path)
		_check("%s sky source is 4096x2048 color" % state,
				image != null and image.get_width() == 4096
				and image.get_height() == 2048
				and image.get_format() in [Image.FORMAT_RGB8, Image.FORMAT_RGBA8])

	var world := root.get_node_or_null("WorldEnvironment") as WorldEnvironment
	var environment := world.environment if world else null
	var sky_key := root.get_node_or_null("ExteriorMoon") as DirectionalLight3D
	_check("DayNightDirector is the Environment absolute writer",
			environment != null and environment.get_meta("absolute_writer", "")
			== "DayNightDirector")
	_check("DayNightDirector is the exterior-key absolute writer",
			sky_key != null and sky_key.get_meta("absolute_writer", "")
			== "DayNightDirector")
	_check("the global storm uses bounded depth fog",
			environment != null and environment.fog_enabled
			and environment.fog_mode == Environment.FOG_MODE_DEPTH
			and environment.fog_depth_begin >= 12.0
			and environment.fog_depth_begin <= 16.0
			and environment.fog_depth_end >= 48.0
			and environment.fog_depth_end <= 58.0
			# 0.78-0.90 was the old band and it encoded a misunderstanding,
			# not a ruling. Godot depth fog is
			#   pow(smoothstep(begin, end, dist), curve) * density
			# so DENSITY IS THE ASYMPTOTIC CEILING, not a rate: at 0.86 every
			# surface in the world keeps 14% of its own contrast at infinite
			# distance, forever. That is why the pale backdrop slabs survived
			# a year of fog tuning -- no begin/end/curve triple can reach
			# extinction while the ceiling is below 1.0.
			#
			# Widened deliberately, owner-approved 2026-08-17, so rain can do
			# what it is for: hide the mid-ground. Near-field safety is
			# unaffected and still checked by begin, which stays in its band
			# -- the far kerb is 14 m from the near one and fogs 0.3%.
			and environment.fog_density >= 0.78
			and environment.fog_density <= 1.0)
	var directional := _descendants(root).filter(
			func(node): return node is DirectionalLight3D)
	_check("the whole world owns one directional exterior key",
			directional.size() == 1 and directional[0] == sky_key)
	_check("WeatherFX adds no realtime lights",
			_descendants(root.weather).all(func(node): return node is not Light3D))
	var period_weather: Dictionary = root.period_reality.diagnostic_snapshot()
	_check("distant 1928 life consumes weather without another visual owner",
			float(period_weather.aircraft_contrast) < 1.0
			and float(period_weather.air_filter_hz) < 14500.0
			and int(period_weather.aircraft_collision_bodies) == 0)
	var neighbour_masses := root.get_node_or_null("PersistentNeighbourMasses")
	var neighbour_facades := root.get_node_or_null("PersistentNeighbourFacades")
	_check("neighbour envelopes survive coarse storey streaming",
			neighbour_masses is MultiMeshInstance3D
			and neighbour_facades is MultiMeshInstance3D
			and neighbour_masses.get_parent() == root
			and neighbour_facades.get_parent() == root)
	_check("persistent skyline contains authored mass and facade instances",
			neighbour_masses.multimesh.instance_count > 0
			and neighbour_facades.multimesh.instance_count > 0)
	var facade_material := neighbour_facades.multimesh.mesh.material \
			as ShaderMaterial
	var facade_code := facade_material.shader.code if facade_material else ""
	_check("one facade calculation owns both window recess and occupancy light",
			facade_code.contains("float window")
			and facade_code.contains("EMISSION = warm_room * occupied * window")
			and facade_code.contains("instance_seed")
			and facade_code.contains("reveal")
			and not facade_code.contains("floor(world_position.xz"))
	_check("facade exposure follows daylight without inventing occupied rooms",
			director._neighbour_light_for_state("day")
					> director._neighbour_light_for_state("night")
			and director._neighbour_occupancy_for_state("day") == 0.0)
	var legacy_site_panes: Array[Node] = _descendants(root.window_glow).filter(
			func(node): return node.name.begins_with("SitePanes_"))
	_check("legacy site cards cannot independently overlight the facade",
			not legacy_site_panes.is_empty()
			and legacy_site_panes.all(func(node):
				var mat := node.material_override as StandardMaterial3D
				return not node.visible and mat != null \
						and mat.emission_energy_multiplier <= 0.02))

	var dome := root.get_node_or_null("NightSkyHalfDome") as MeshInstance3D
	var sky_material := dome.material_override as ShaderMaterial if dome else null
	var sky_code := sky_material.shader.code if sky_material else ""
	_check("one dome blends only two adjacent panoramas",
			dome != null and sky_code.count("uniform sampler2D panorama_") == 2)
	_check("the dynamic lower cloud deck lives in that same sky draw",
			sky_code.contains("lower_clouds")
			and sky_code.contains("lower_cloud_strength"))
	_check("the same sky draw projects the lunar terminator from the real Sun",
			sky_code.contains("moon_phase_enabled")
			and sky_code.contains("surface_normal")
			and sky_code.contains("dot(surface_normal, normalize(sun_direction))"))
	_check("the measured Milky Way shares the catalog stars' sidereal basis",
			sky_code.contains("equatorial_axis_x")
			and sky_code.contains("galactic_uv")
			and sky_code.contains("panorama_a_celestial"))
	_check("urban airglow grounds the skyline without reaching the zenith",
			sky_code.contains("urban_horizon_gain")
			and sky_code.contains("smoothstep(0.72, 1.0, v)")
			and sky_code.contains("lower_air")
			and director._urban_horizon_for_state("night")
					> director._urban_horizon_for_state("day"))
	_check("the projected Moon samples measured LROC near-side geography",
			sky_code.contains("moon_surface")
			and sky_code.contains("lunar_lon")
			and ResourceLoader.exists(
					"res://assets/environment/lroc_color_poles_1k.jpg"))
	_check("the dome, middle rain and roadway mist cast no shadows",
			dome.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			and root.weather.get_node("DrivingRainMiddle").cast_shadow
			== GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			and root.weather.get_node("RoadwayMist").cast_shadow
			== GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)

	_check("north pavement is rain-exposed",
			root.weather_exposure_at(Vector3(0.0, 0.05, 12.1)))
	_check("south pavement is rain-exposed",
			root.weather_exposure_at(Vector3(0.0, 0.05, 26.1)))
	_check("roadway is rain-exposed",
			root.weather_exposure_at(Vector3(0.0, 0.05, 19.322)))
	_check("the open roof is rain-exposed",
			root.weather_exposure_at(Vector3(0.0, 19.3, 0.0)))
	_check("the lobby and atrium are dry",
			not root.weather_exposure_at(Vector3(0.0, 0.05, 0.0)))
	_check("an upper apartment is dry",
			not root.weather_exposure_at(Vector3(0.0, 9.65, 0.0)))
	_check("the Vantry Arcade is dry",
			not root.weather_exposure_at(Vector3(14.0, 0.05, 45.0)))
	_check("the basement is dry",
			not root.weather_exposure_at(Vector3(0.0, -2.75, 0.0)))

	root.player.global_position = Vector3(0.0, 0.05, 19.322)
	root.weather._process(0.2)
	var weather_state: Dictionary = root.weather.diagnostic_snapshot()
	_check("the weather seed and counts are deterministic",
			weather_state.seed == 19280731
			and weather_state.near_rain_mode == "procedural_close_shell"
			and weather_state.spatter_count == 72
			and weather_state.leaf_count == 8)
	_check("near and middle rain share one visible batch outdoors",
			root.weather.get_node("DrivingRainSpatter").emitting
			and root.weather.get_node("DrivingRainMiddle").visible)
	root.player.global_position = Vector3(0.0, 0.05, 0.0)
	root.weather._process(0.2)
	_check("all player-following precipitation suppresses indoors",
			not root.weather.get_node("DrivingRainSpatter").emitting
			and not root.weather.get_node("DrivingRainMiddle").visible)

	_check("traffic's crossing promise remains eight seconds",
			StreetTraffic.MAX_WAIT == 8.0)
	_check("traffic's authored safe gap remains 3.4 seconds",
			StreetTraffic.GAP_SECONDS == 3.4)
	_check("both ruled street-end weather owners survive",
			get_tree().get_nodes_in_group("street_end_weather").size() == 2)

	print("[WEATHER SKY TEST] RESULT: %s (%d failures)" % [
			"PASS" if _fails == 0 else "FAIL", _fails])
	_stop_audio(root)
	root.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	PropAudio.clear_cache()
	get_tree().quit(_fails)


func _descendants(parent: Node) -> Array[Node]:
	var found: Array[Node] = []
	var stack: Array[Node] = [parent]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		found.append(node)
		stack.append_array(node.get_children())
	return found


func _stop_audio(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer3D:
		node.stop()
	for child in node.get_children():
		_stop_audio(child)
