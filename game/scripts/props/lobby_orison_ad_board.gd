class_name LobbyOrisonAdBoard
extends Node3D
## The title-screen artifact made physical. Only the broadside is sampled
## from the render; depth, frame, fasteners, damage and debris are geometry.

const SOURCE := preload("res://assets/ui/title/orison_original_advert_lobby_v1.png")

var _loose_corner: MeshInstance3D
var _chain: MeshInstance3D
var _inspection_boss: MeshInstance3D
var _inspection_boss_rest_z := 0.0
var _inspection_tap: AudioStreamPlayer3D
var _inspection_tween: Tween
var _elapsed := 0.0


func _ready() -> void:
	name = "OrisonOriginalSalesBoard"
	_build_board()
	_build_inspection_owner()


func _build_board() -> void:
	var wood := _material(Color(0.095, 0.052, 0.028), 0.02, 0.72)
	var wood_edge := _material(Color(0.038, 0.023, 0.016), 0.0, 0.84)
	var brass := _material(Color(0.31, 0.19, 0.065), 0.72, 0.48)
	var backing := _material(Color(0.075, 0.052, 0.035), 0.0, 0.91)
	var paper_edge := _material(Color(0.31, 0.24, 0.15), 0.0, 0.96)
	var dust := _material(Color(0.13, 0.105, 0.075), 0.0, 1.0)

	_box("WarpedBacking", Vector3(1.34, 1.76, 0.075), Vector3.ZERO, backing)
	for x in [-0.66, 0.66]:
		_box("OuterFrame", Vector3(0.105, 1.89, 0.105),
				Vector3(x, 0, 0.055), wood_edge)
		_box("CarvedFrame", Vector3(0.045, 1.73, 0.055),
				Vector3(x - signf(x) * 0.075, 0, 0.120), wood)
	for y in [-0.91, 0.91]:
		_box("OuterFrame", Vector3(1.42, 0.105, 0.105),
				Vector3(0, y, 0.055), wood_edge)
		_box("CarvedFrame", Vector3(1.25, 0.045, 0.055),
				Vector3(0, y - signf(y) * 0.075, 0.120), wood)
	for x in [-0.655, 0.655]:
		for y in [-0.905, 0.905]:
			var boss := _cylinder("FrameBoss", 0.062, 0.045,
					Vector3(x, y, 0.125), brass)
			if _inspection_boss == null:
				_inspection_boss = boss
				_inspection_boss_rest_z = boss.position.z

	# Isolated advertisement region: none of the title render's wall or frame
	# is baked onto the modeled object.
	var atlas := AtlasTexture.new()
	atlas.atlas = SOURCE
	atlas.region = Rect2(438, 126, 486, 650)
	var advert_mat := StandardMaterial3D.new()
	advert_mat.albedo_texture = atlas
	advert_mat.roughness = 0.88
	advert_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var face := MeshInstance3D.new()
	face.name = "Original1926Broadside"
	var quad := QuadMesh.new(); quad.size = Vector2(1.08, 1.45)
	face.mesh = quad
	face.material_override = advert_mat
	face.position = Vector3(0, 0, 0.142)
	face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(face)

	# Physical paper edges keep it from reading like a monitor.
	_box("PaperEdge", Vector3(1.10, 0.010, 0.012), Vector3(0, 0.73, 0.144), paper_edge)
	_box("PaperEdge", Vector3(1.10, 0.010, 0.012), Vector3(0, -0.73, 0.144), paper_edge)
	_box("PaperEdge", Vector3(0.010, 1.45, 0.012), Vector3(-0.55, 0, 0.144), paper_edge)
	_box("PaperEdge", Vector3(0.010, 1.45, 0.012), Vector3(0.55, 0, 0.144), paper_edge)

	_loose_corner = MeshInstance3D.new()
	_loose_corner.name = "LoosePaperCorner"
	var corner_mesh := QuadMesh.new(); corner_mesh.size = Vector2(0.22, 0.19)
	_loose_corner.mesh = corner_mesh
	_loose_corner.material_override = advert_mat
	_loose_corner.position = Vector3(0.43, -0.63, 0.153)
	_loose_corner.rotation.z = -0.035
	add_child(_loose_corner)

	# Later notices are actual sheets pinned over the frame.
	var notice := _material(Color(0.48, 0.43, 0.31), 0.0, 0.94)
	var old_notice := _material(Color(0.34, 0.29, 0.20), 0.0, 0.97)
	var ink := _material(Color(0.085, 0.070, 0.050), 0.0, 0.91)
	_box("InspectionNotice", Vector3(0.28, 0.34, 0.008), Vector3(-0.63, -0.35, 0.185), notice)
	_box("InspectionStamp", Vector3(0.19, 0.012, 0.004), Vector3(-0.63, -0.30, 0.192), ink)
	_box("ContractorCard", Vector3(0.30, 0.19, 0.008), Vector3(0.61, 0.31, 0.184), old_notice)
	for pin in [Vector3(-0.63, -0.19, 0.202), Vector3(0.61, 0.40, 0.202)]:
		_cylinder("BentBrassTack", 0.016, 0.020, pin, brass)

	# Dust, plaster chips and a dead moth collect on the real bottom ledge.
	_box("DustLedge", Vector3(1.47, 0.075, 0.20), Vector3(0, -0.99, 0.075), wood_edge)
	for spec in [[-0.51, 0.045, 0.035], [-0.25, 0.070, 0.022],
			[0.18, 0.038, 0.052], [0.46, 0.060, 0.030]]:
		_box("PlasterChip", Vector3(spec[1], spec[2], spec[1] * 0.65),
				Vector3(spec[0], -0.94, 0.20), dust)
	_box("DeadMothWing", Vector3(0.055, 0.008, 0.025), Vector3(0.05, -0.935, 0.214), paper_edge)

	_chain = _cylinder("DisobedientPullChain", 0.007, 0.62,
			Vector3(0.82, 0.47, 0.15), brass)
	_chain.rotation.z = 0.02


func _build_inspection_owner() -> void:
	var area := Area3D.new()
	area.name = "SalesBoardInspection"
	area.collision_layer = 1
	area.collision_mask = 0
	area.monitoring = false
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.58, 2.06, 0.28)
	shape_node.shape = shape
	area.add_child(shape_node)
	add_child(area)
	_inspection_tap = AudioStreamPlayer3D.new()
	_inspection_tap.stream = PropAudio.get_stream("tick")
	_inspection_tap.volume_db = -18.0
	_inspection_tap.max_distance = 3.5
	add_child(_inspection_tap)


func interact_prompt() -> String:
	return "[E]  Inspect original Orison broadside"


func interact(_player: Node = null) -> Dictionary:
	_inspection_tap.pitch_scale = 0.84
	_inspection_tap.play()
	if _inspection_tween and _inspection_tween.is_valid():
		_inspection_tween.kill()
	if _inspection_boss:
		_inspection_boss.position.z = _inspection_boss_rest_z
		_inspection_tween = create_tween()
		_inspection_tween.tween_property(_inspection_boss, "position:z",
				_inspection_boss_rest_z + 0.008, 0.08)
		_inspection_tween.tween_property(_inspection_boss, "position:z",
				_inspection_boss_rest_z, 0.18)
	return service_wire_card()


func service_wire_card() -> Dictionary:
	return PropServiceWire.card("notice_board", {
		"notice_state": "ORIGINAL BROADSIDE / TWO LATER SERVICE SLIPS",
		"board_state": "WARPED / FRAME FASTENED",
	})


func _process(delta: float) -> void:
	_elapsed += delta
	if _loose_corner:
		_loose_corner.rotation.x = -0.025 - (sin(_elapsed * 0.19) + 1.0) * 0.012
	if _chain:
		_chain.rotation.z = 0.02 + sin(_elapsed * 0.13) * 0.035


func _material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color; mat.metallic = metallic; mat.roughness = roughness
	return mat


func _box(node_name: String, size: Vector3, at: Vector3,
		material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new(); node.name = node_name
	var mesh := BoxMesh.new(); mesh.size = size
	node.mesh = mesh; node.position = at; node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(node)
	return node


func _cylinder(node_name: String, radius: float, height: float, at: Vector3,
		material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new(); node.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius; mesh.bottom_radius = radius
	mesh.height = height; mesh.radial_segments = 10
	node.mesh = mesh; node.position = at; node.rotation.x = PI * 0.5
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(node)
	return node
