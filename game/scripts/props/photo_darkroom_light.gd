extends LightFixtureProp
## V2 visual adaptation of the existing Photo electrical actor. V1 keeps its body.
## The original fixture owns every light, envelope, circuit and hours transition.
var native_parts: Dictionary = {}
var native_source_frame := Transform3D.IDENTITY
var has_native_source_frame := false

func rebase_from_source_marker(marker: Dictionary) -> void:
	assert(not is_node_ready() and marker.get("id") == "SITE_SHOP_DARKROOM_PHOTO_SUPPLIES")
	native_source_frame = Transform3D(Basis(Vector3.UP, deg_to_rad(-float(marker.yaw_deg))), GameBoot.b2g(marker.pos))
	assert(native_source_frame.is_finite())
	has_native_source_frame = true

func _author_personality(base_tone: Color) -> void:
	super._author_personality(base_tone)
	_individual_tone = Color(1.0, 0.018, 0.009)

func _build_body(parent: Node3D) -> Vector3:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/photo_radio_fittings.json"))
	var packed := ResourceLoader.load(str(data.asset), "PackedScene", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene
	var model := packed.instantiate() as Node3D
	# Native mesh/emitter coordinates belong to the authored actor frame. A
	# projected actor must not inverse its new pose and cancel its own move.
	# Without an explicit rebase, keep the ordinary source-mount behavior exact.
	var local_from_source := (native_source_frame if has_native_source_frame else transform).affine_inverse()
	var records: Dictionary = {}
	for row: Dictionary in data.actor_parts: records[str(row.name)] = row
	for draw: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if not records.has(str(draw.name)): continue
		var row: Dictionary = records[str(draw.name)]
		var part := str(draw.name)
		var pose := local_from_source * draw.transform
		draw.owner = null
		draw.get_parent().remove_child(draw)
		parent.add_child(draw)
		draw.transform = pose
		var material := MatLib.get_mat(str(row.catalog_key)).duplicate() as StandardMaterial3D
		material.uv1_triplanar = false
		material.uv1_scale = Vector3.ONE / float(row.tile)
		if row.has("tint"):
			var tint: Array = row.tint
			material.albedo_color = Color(tint[0], tint[1], tint[2], tint[3])
		draw.mesh.surface_set_material(0, material)
		draw.set_meta("photo_radio_fittings_part", part)
		draw.set_meta("material_key", str(row.key))
		if str(row.key) == "milk_glass": draw.name = "bulb_darkroom"
		# Build runtime collision without propagating the imported scene owner
		# after this draw has moved beneath the persistent electrical actor.
		var body := StaticBody3D.new()
		var collision := CollisionShape3D.new()
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(draw.mesh.get_faces())
		collision.shape = shape
		draw.add_child(body)
		body.add_child(collision)
		native_parts[part] = draw
	model.free()
	return local_from_source * Vector3(data.emitter[0], data.emitter[1], data.emitter[2])

func _build_visual() -> void:
	super._build_visual()
	# Opal glass stays physically red when the existing dimmer turns it off.
	var glass := MatLib.get_mat("milk_glass")
	var diffuser: MeshInstance3D = _swing_node.get_node("bulb_darkroom")
	_bulb_mat.albedo_color = (diffuser.mesh.surface_get_material(0) as StandardMaterial3D).albedo_color
	_bulb_mat.albedo_texture = glass.albedo_texture
	_bulb_mat.roughness_texture = glass.roughness_texture
	_bulb_mat.normal_texture = glass.normal_texture
	_bulb_mat.normal_scale = glass.normal_scale
	_bulb_mat.roughness = glass.roughness
	_bulb_mat.uv1_scale = Vector3.ONE / float(MatLib.SETS["milk_glass"][3])
	bounce.light_color = _individual_tone * 0.65

func _process(delta: float) -> void:
	super._process(delta)
	# A bolted wall fitting cannot inherit the cage family's pendulum motion.
	_swing_node.rotation = Vector3.ZERO
	# The inherited first-bounce approximation must obey this lamp's hours dimmer.
	if _state_gain == 0.0: bounce.light_energy = 0.0
