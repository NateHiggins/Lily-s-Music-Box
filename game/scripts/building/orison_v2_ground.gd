extends Node3D
## Bounded subgrade and retained-datum court surface in the registered V2 frame.
const ASSET:=preload("res://assets/props/orison_ground.glb")

func _ready() -> void:
	var model:=ASSET.instantiate() as Node3D
	add_child(model)
	var asphalt:=MatLib.get_mat("asphalt").duplicate() as StandardMaterial3D
	var original_asphalt := asphalt.duplicate() as StandardMaterial3D
	original_asphalt.uv1_triplanar=false
	var recipe: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/ground_finish.json"))
	var tint: Array=recipe.tint
	asphalt.albedo_color=Color(tint[0],tint[1],tint[2],tint[3])
	asphalt.normal_scale=float(recipe.normal)
	asphalt.roughness=float(recipe.roughness)
	var soil:=MatLib.get_mat("soil").duplicate() as StandardMaterial3D
	asphalt.uv1_triplanar=false;soil.uv1_triplanar=false
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		draw.material_override=asphalt if str(draw.name).contains("asphalt") else soil
		if str(draw.name).contains("asphalt"):draw.set_meta("v2_ground_source",original_asphalt)
		var body:=StaticBody3D.new();body.name="GroundCollision";draw.add_child(body)
		var collision:=CollisionShape3D.new()
		collision.shape=_native_shape(draw.mesh);body.add_child(collision)

func _native_shape(mesh: Mesh) -> ConcavePolygonShape3D:
	var shape:=ConcavePolygonShape3D.new();shape.set_faces(preload("res://scripts/building/orison_v2_native_faces.gd").read(mesh));return shape
