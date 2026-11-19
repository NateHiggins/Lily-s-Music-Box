extends RefCounted
## The authored lobby centerpiece is passive stock in the blockout frame.

const ASSET := "res://assets/props/lobby_floating_sculpture.glb"
const SurfacePass := preload("res://scripts/building/surface_pass.gd")
const SITE := Vector3(-1.8, 0.0, -6.55)
const PARTS := {
	"Sculpture__DrapedBody": "WarmCarvedStone",
	"Sculpture__FloatingHead": "WarmCarvedStone",
	"Sculpture__OvalCastPlinth": "WarmCarvedStone",
	"Sculpture__LimestonePedestal": "PedestalLimestone",
	"Sculpture__FacePigment": "StarPigment",
}
const FINISHES := {
	"WarmCarvedStone": ["limestone", Color(1.0, 0.94, 0.85), 0.06, 0.82, 0.48, true],
	"PedestalLimestone": ["limestone", Color(0.84, 0.80, 0.72), 0.20, 1.0, 0.85, false],
	"StarPigment": ["indicator_enamel", Color(0.085, 0.07, 0.055), 0.012, 0.87, 0.30, false],
}


static func mount(root: Node3D) -> bool:
	var packed := load(ASSET) as PackedScene
	if packed == null:
		return false
	var stock := packed.instantiate() as Node3D
	var draws := stock.find_children("*", "MeshInstance3D", true, false)
	if draws.size() != PARTS.size() or stock.find_child("DATUM_Ground_Centre", true, false) == null:
		stock.free()
		return false
	var body := StaticBody3D.new()
	body.name = "LobbyFloatingSculpture"
	body.position = SITE
	body.rotation.y = PI
	body.collision_mask = 0
	stock.name = "NativeStock"
	body.add_child(stock)
	var seen := {}
	var materials := {}
	for draw: MeshInstance3D in draws:
		var name := str(draw.name)
		if not PARTS.has(name) or seen.has(name) or draw.mesh == null or draw.mesh.get_surface_count() != 1:
			body.free()
			return false
		seen[name] = true
		var finish: String = PARTS[name]
		var row: Array = FINISHES[finish]
		if not materials.has(finish):
			materials[finish] = _material(row)
		draw.material_override = materials[finish]
		draw.set_meta("material_key", row[0])
		# Four fitted bounds protect the solid stock without using the high-poly
		# render mesh for collision. Face pigment is part of the head finish.
		if finish != "StarPigment":
			_add_collider(body, draw)
	root.add_child(body)
	return true


static func _material(row: Array) -> ShaderMaterial:
	var key: String = row[0]
	var original := MatLib.get_mat(key, (row[1] as Color).linear_to_srgb()).duplicate() as StandardMaterial3D
	original.uv1_triplanar = false
	original.normal_scale = row[2]
	original.roughness = row[3]
	return SurfacePass.surface_for(original, {
		"uv_mode": 0,
		"relief_mul": 0.0,
		"pigment_variation": row[4],
		"painted_vertex_albedo": row[5],
	})


static func _add_collider(body: StaticBody3D, draw: MeshInstance3D) -> void:
	var pose := draw.transform
	var parent := draw.get_parent() as Node3D
	while parent != body:
		pose = parent.transform * pose
		parent = parent.get_parent() as Node3D
	var bounds := draw.mesh.get_aabb()
	var shape := BoxShape3D.new()
	shape.size = bounds.size
	var collision := CollisionShape3D.new()
	collision.name = str(draw.name) + "Bearing"
	collision.shape = shape
	collision.transform = pose.translated_local(bounds.get_center())
	body.add_child(collision)
