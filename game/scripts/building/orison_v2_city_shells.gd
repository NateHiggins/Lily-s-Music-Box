extends Node3D
## Closed source-derived city masses. Existing street, shop and alley owners
## retain their ground, openings and actors; this region adds none of those.
const ASSET := preload("res://assets/props/city_elevations.glb")
const FINISHES := "res://data/orison_v2/exterior/city_elevations.json"

func _ready() -> void:
	var section := preload("res://scripts/building/orison_v2_street_frame.gd").load_default()
	if section.is_empty(): return
	position.z = -float(section.source_threshold_z)
	var model := ASSET.instantiate() as Node3D
	add_child(model)
	var materials: Dictionary={}
	var profiles: Dictionary={}
	var finish_data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FINISHES))
	assert(int(finish_data.schema)==1)
	for profile: Dictionary in finish_data.buildings:profiles[str(profile.id)]=profile
	var roof_finishes := preload("res://scripts/building/orison_v2_owner_finishes.gd").new()
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		mesh.set_meta("retained_city_shell",true)
		var key := str(mesh.name).split("__")[-1]
		var building := str(mesh.name).split("__")[0]
		assert(profiles.has(building),"City elevation has no authored finish: "+building)
		var profile: Dictionary=profiles[building]
		var cache_key := building+"__"+key
		assert(MatLib.SETS.has(key),"City material must be catalogued: " + key)
		if not materials.has(cache_key):
			var material:=MatLib.get_mat(key).duplicate() as StandardMaterial3D
			material.uv1_triplanar=false
			material.normal_scale=.65
			if key==str(profile.wall_key):
				var tint: Array=profile.wall_tint
				material.albedo_color=Color(tint[0],tint[1],tint[2],tint[3])
			elif key=="door_paint":
				var tint: Array=profile.frame_tint
				material.albedo_color=Color(tint[0],tint[1],tint[2],tint[3])
			elif key=="mirror_aged":
				# A real closed pane in front of separately built curtains/backing.
				material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
				material.albedo_color=Color(.18,.23,.25,.28)
				material.metallic=0.0
				material.roughness=.45
				material.normal_scale=.12
			materials[cache_key]=material
		mesh.material_override=materials[cache_key]
		if key == "galvanized_roof":
			mesh.set_meta("v2_city_roof_source",materials[cache_key])
			mesh.material_override=roof_finishes.material_for(materials[cache_key],"roof")
		var body := StaticBody3D.new()
		body.set_meta("retained_city_shell",true)
		body.name = str(mesh.name)+"Collision"
		var collision := CollisionShape3D.new()
		collision.shape = mesh.mesh.create_trimesh_shape()
		collision.transform = mesh.transform
		body.add_child(collision)
		model.add_child(body)
	preload("res://scripts/building/orison_v2_city_masts.gd").mount(self)
	preload("res://scripts/building/orison_v2_city_aerials.gd").mount(self)
	preload("res://scripts/building/orison_v2_city_tanks.gd").mount(self)
	preload("res://scripts/building/orison_v2_city_beacons.gd").mount(self)
