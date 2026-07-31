class_name FoundArtPass
extends Node3D
## Places repurposed source art as framed pieces, loose print matter, and a
## rooftop billboard. All imagery comes from small shared 2x2 atlases.

const CATALOG := "res://data/found_art_catalog.json"
const TEXTURE_ROOT := "res://assets/building/textures/found_art/"


func build(layout: Dictionary, floor_nodes: Dictionary) -> Dictionary:
	var file := FileAccess.open(CATALOG, FileAccess.READ)
	if file == null:
		push_warning("found-art catalog missing")
		return {}
	var catalog: Dictionary = JSON.parse_string(file.get_as_text())
	var floors := {}
	for floor_data in layout.get("floors", []):
		floors[floor_data.id] = floor_data
	var counts := {"wall": 0, "print": 0, "billboard": 0}
	for spec in catalog.get("wall_pieces", []):
		if _place_wall_piece(spec, floors, floor_nodes):
			counts.wall += 1
	for spec in catalog.get("surface_prints", []):
		if _place_surface_print(spec, floor_nodes):
			counts.print += 1
	for spec in catalog.get("billboards", []):
		_place_billboard(spec)
		counts.billboard += 1
	print("[BUILDING] found art: %d walls, %d print props, %d billboards" %
			[counts.wall, counts.print, counts.billboard])
	return counts


func _place_wall_piece(spec: Dictionary, floors: Dictionary,
		floor_nodes: Dictionary) -> bool:
	var floor_id: String = spec.floor
	if not floors.has(floor_id) or not floor_nodes.has(floor_id):
		return false
	var floor_data: Dictionary = floors[floor_id]
	var room: Dictionary = {}
	for candidate in floor_data.rooms:
		if candidate.id == spec.room:
			room = candidate
			break
	if room.is_empty():
		return false
	var art := CharacterMemoryArt.new()
	var art_spec := spec.duplicate()
	art_spec["collection"] = "found_art"
	art.setup(art_spec)
	var rect: Array = room.rect
	var along := float(spec.get("along", 0.5))
	var x := lerpf(float(rect[0]), float(rect[2]), along)
	var y := lerpf(float(rect[1]), float(rect[3]), along)
	var yaw := 0.0
	var inset := float(spec.get("wall_offset", 0.055))
	match str(spec.get("wall", "north")):
		"north":
			y = float(rect[3]) - inset
		"south":
			y = float(rect[1]) + inset
			yaw = PI
		"east":
			x = float(rect[2]) - inset
			yaw = -PI * 0.5
		"west":
			x = float(rect[0]) + inset
			yaw = PI * 0.5
	art.position = GameBoot.b2g([
			x, y, float(floor_data.z) + float(spec.get("height", 1.55))])
	art.rotation.y = yaw
	floor_nodes[floor_id].add_child(art)
	return true


func _place_surface_print(spec: Dictionary, floor_nodes: Dictionary) -> bool:
	var floor_id: String = spec.floor
	if not floor_nodes.has(floor_id):
		return false
	var decal := StoryDecal.new()
	decal.name = "FoundPrint_" + str(spec.id)
	decal.setup(TEXTURE_ROOT + str(spec.atlas), int(spec.col), int(spec.row),
			Vector2(float(spec.get("width", 0.28)),
					float(spec.get("depth", 0.36))))
	decal.position = GameBoot.b2g(spec.position)
	decal.rotation = Vector3(-PI * 0.5, deg_to_rad(
			float(spec.get("yaw", 0.0))), 0.0)
	floor_nodes[floor_id].add_child(decal)
	return true


func _place_billboard(spec: Dictionary) -> void:
	var holder := Node3D.new()
	holder.name = "FoundBillboard_" + str(spec.id)
	holder.position = GameBoot.b2g(spec.position)
	holder.rotation.y = deg_to_rad(float(spec.get("yaw", 180.0)))
	add_child(holder)
	var size := Vector2(float(spec.get("width", 4.8)),
			float(spec.get("height", 2.4)))
	var backing_mesh := BoxMesh.new()
	backing_mesh.size = Vector3(size.x + 0.16, size.y + 0.16, 0.10)
	var backing_mat := StandardMaterial3D.new()
	backing_mat.albedo_color = Color(0.055, 0.05, 0.045)
	backing_mat.roughness = 0.82
	var backing := MeshInstance3D.new()
	backing.mesh = backing_mesh
	backing.material_override = backing_mat
	holder.add_child(backing)
	var image := StoryDecal.new()
	image.setup(TEXTURE_ROOT + str(spec.atlas), int(spec.col), int(spec.row),
			size)
	image.position.z = 0.056
	holder.add_child(image)
	for x in [-size.x * 0.33, size.x * 0.33]:
		var post_mesh := BoxMesh.new()
		post_mesh.size = Vector3(0.10, 1.55, 0.10)
		var post := MeshInstance3D.new()
		post.mesh = post_mesh
		post.material_override = backing_mat
		post.position = Vector3(x, -size.y * 0.5 - 0.76, -0.03)
		holder.add_child(post)
