extends Node3D
## Installed in the building's registered frame; the existing street owns the
## sidewalk beyond its mouth. Door interaction remains with DomesticDoors.
const ASSET := preload("res://assets/props/service_alley.glb")
const GROUNDWORKS := preload("res://assets/props/alley_groundworks.glb")
var finish_recipes: Dictionary

func _surface(role: String) -> StandardMaterial3D:
	var recipe: Dictionary = finish_recipes[role]
	var mat := MatLib.get_mat(str(recipe.catalog_key)).duplicate() as StandardMaterial3D
	var tint: Array = recipe.tint
	mat.albedo_color = Color(tint[0],tint[1],tint[2],tint[3])
	# Boundary source UVs predate the metric groundwork charts.
	mat.uv1_triplanar = role in ["Brick","Coping"]
	mat.normal_scale = float(recipe.normal)
	mat.roughness = float(recipe.roughness)
	mat.metallic = float(recipe.metallic)
	return mat

func _ready() -> void:
	finish_recipes = JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/service_alley_finish.json"))
	var model := ASSET.instantiate() as Node3D
	add_child(model)
	var finishes := {"Paving":"concrete", "Brick":"brick", "Coping":"limestone", "Iron":"cast_iron"}
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		# The fitted grade and open well replace these two original finish owners.
		if str(mesh.name) in ["Paving","Iron"]:
			mesh.free()
			continue
		mesh.set_meta("v2_alley_source", MatLib.get_mat(finishes[str(mesh.name)]))
		mesh.material_override = _surface(str(mesh.name))
		var body := StaticBody3D.new()
		body.name = str(mesh.name)+"Collision"
		var collision := CollisionShape3D.new()
		collision.shape = mesh.mesh.create_trimesh_shape()
		collision.transform = mesh.transform
		body.add_child(collision)
		model.add_child(body)
	var groundworks:=GROUNDWORKS.instantiate() as Node3D
	groundworks.name="Groundworks"
	add_child(groundworks)
	var concrete:=MatLib.get_mat("concrete").duplicate() as StandardMaterial3D
	var iron:=MatLib.get_mat("cast_iron").duplicate() as StandardMaterial3D
	concrete.uv1_triplanar=false;iron.uv1_triplanar=false
	var paving_finish := _surface("Paving")
	var iron_finish := _surface("Iron")
	for draw: MeshInstance3D in groundworks.find_children("*","MeshInstance3D",true,false):
		var is_iron := str(draw.name).contains("cast_iron")
		draw.set_meta("v2_alley_source",iron if is_iron else concrete)
		draw.material_override=iron_finish if is_iron else paving_finish
		var body:=StaticBody3D.new();body.name="GroundworksCollision";draw.add_child(body)
		var collision:=CollisionShape3D.new();collision.shape=_native_shape(draw.mesh);body.add_child(collision)
	for at: Vector3 in [Vector3(17.8,2.34,-9),Vector3(17.8,2.34,2),Vector3(17.8,2.34,12.5),Vector3(8,2.34,11)]:
		var lamp := LightFixtureProp.new()
		lamp.prop_type = "cage_bulb"
		lamp.position = at
		lamp.range_clamp = 5.0
		lamp.energy_scale = .65
		lamp.navigation_light = true
		lamp.standby_scale = .35
		add_child(lamp)

func _native_shape(mesh: Mesh) -> ConcavePolygonShape3D:
	var shape:=ConcavePolygonShape3D.new();shape.set_faces(preload("res://scripts/building/orison_v2_native_faces.gd").read(mesh));return shape
