extends ProjectorProp
## V2 uses the authored machine/reel renderer with a fitted body, local decoder
## state and a projection that must fit a continuous physical surface.
var _running := false
var _on_lens: StandardMaterial3D
var _body_materials: Dictionary = {}

func setup_v2(unit_id: String, clip: String) -> void:
	super.setup(null, unit_id, null)
	# The shared ancestor supplies a television control skin. The machine
	# instead has one fitted interaction/collision envelope on its own stand.
	for child in get_children():
		if child is CollisionShape3D: child.free()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(.29,.51,.40)
	shape.shape = box
	shape.position = Vector3(0,.255,.02)
	add_child(shape)
	glass.position = Vector3(0,.205,-.165)
	_beam.position = Vector3(0,.205,-.18)
	_beam.shadow_enabled = true
	_off_mat = MatLib.get_mat("milk_glass")
	_on_lens = _off_mat.duplicate() as StandardMaterial3D
	_on_lens.emission_enabled = true
	_on_lens.emission = Color(1,.83,.53)
	_on_lens.emission_energy_multiplier = .7
	glass.material_override = _off_mat
	_voice.position = Vector3(0,.25,0)
	_voice.max_distance = 5.0
	load_reel(clip)

func _part(size: Vector3, at: Vector3, tint: Color, rough: float) -> MeshInstance3D:
	var mesh := super._part(size, at, tint, rough)
	mesh.material_override = _body_material(tint, rough)
	return mesh

func _barrel(radius: float, height: float, at: Vector3, tint: Color,
		rough: float, axis := AXIS_Y, spins := false) -> MeshInstance3D:
	var mesh := super._barrel(radius, height, at, tint, rough, axis, spins)
	mesh.material_override = _body_material(tint, rough)
	return mesh

func _body_material(tint: Color, rough: float) -> StandardMaterial3D:
	var key := "cast_iron"
	if tint.r > .4: key = "brass"
	elif tint.r > tint.b * 1.2: key = "bakelite_black"
	elif tint.r < .06: key = "rubber_aged"
	var cache_key := key + "/" + str(rough)
	if _body_materials.has(cache_key): return _body_materials[cache_key]
	var material := MatLib.get_mat(key).duplicate() as StandardMaterial3D
	material.roughness = rough
	_body_materials[cache_key] = material
	return material

func load_reel(clip_id: String) -> void:
	# Stop/release the previous decoder even for an invalid or empty new reel.
	_stop_projection()
	_video.stream = null
	reel = ""
	if not clip_id.is_empty() and clip_id.is_valid_filename():
		var path := "res://assets/video/clips/%s.ogv" % clip_id
		if ResourceLoader.exists(path):
			_video.stream = load(path)
			reel = clip_id
	if is_inside_tree(): _refresh()

func _refresh() -> void:
	powered = player_on or npc_on or possessed
	if not powered or reel.is_empty():
		_stop_projection()
		return
	# Repeated NPC/player/possession latch notifications must not restart film.
	if _running: return
	_aim()
	if not _screen.visible:
		_stop_projection()
		return
	_running = true
	_feed.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# Clear the exposure history once whenever a new run starts; subsequent
	# frames retain the authored photographic accumulation.
	_accum.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE
	_accum.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_video.play()
	glass.material_override = _on_lens
	_beam.light_energy = .55
	# The spill is already covered by the beam, so avoid a second room light.
	glow.visible = false

func _stop_projection() -> void:
	_running = false
	if _video != null: _video.stop()
	if _feed != null: _feed.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if _accum != null: _accum.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if _screen != null: _screen.visible = false
	if _beam != null: _beam.light_energy = 0
	if glass != null: glass.material_override = _off_mat
	if glow != null:
		glow.visible = false
		glow.light_energy = 0

func _aim() -> void:
	_screen.visible = false
	if not is_inside_tree(): return
	var origin := to_global(Vector3(0,.205,-.18))
	var direction := -global_basis.z
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * THROW_MAX, 1, [get_rid()])
	var hit := space.intersect_ray(query)
	if hit.is_empty(): return
	var normal: Vector3 = hit.normal
	if normal.dot(-direction) < .98: return
	var distance := origin.distance_to(hit.position)
	if distance < .25: return
	var height := clampf(distance * THROW_RATIO, .5, 2.4)
	var right := global_basis.x
	# The centre alone can hit a jamb while most of the image crosses a door
	# or window. Require all eight surrounding samples on the same plane.
	for x in [-1.0, 0.0, 1.0]:
		for y in [-1.0, 0.0, 1.0]:
			if x == 0 and y == 0: continue
			var target: Vector3 = hit.position + right * x * height * .34 + Vector3.UP * y * height * .5
			var ray := PhysicsRayQueryParameters3D.create(origin, target + direction * .04, 1, [get_rid()])
			var edge := space.intersect_ray(ray)
			if edge.is_empty(): return
			var edge_normal: Vector3 = edge.normal
			var edge_point: Vector3 = edge.position
			if edge_normal.dot(normal) < .98 or absf((edge_point - target).dot(normal)) > .025: return
	(_screen.mesh as QuadMesh).size = Vector2(height * .68,height)
	_beam.spot_range = minf(THROW_MAX,distance + .2)
	_beam.spot_angle = clampf(rad_to_deg(atan2(height * .605,distance)),1,60)
	_screen.global_position = hit.position + normal * .02
	_screen.global_basis = Basis.looking_at(-normal,Vector3.UP)
	_screen.visible = true

func _process(delta: float) -> void:
	if _running: super._process(delta)

func set_possessed(on: bool) -> void:
	if possessed == on: return
	super.set_possessed(on)
	if not on: _release_voice()

func _release_voice() -> void:
	if _voice == null: return
	var stream := _voice.stream
	_voice.stop()
	_voice.stream = null
	if stream != null: PropAudio.release_stream("agitate_loop",stream)

func _exit_tree() -> void:
	_stop_projection()
	if _video != null: _video.stream = null
	_release_voice()
