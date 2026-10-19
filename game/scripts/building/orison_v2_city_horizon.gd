extends Node3D
## Passive distant stock in the retained building/grade frame. No new play area.
const ASSETS := [preload("res://assets/props/city_horizon_near.glb"), preload("res://assets/props/city_horizon_far.glb")]
const FINISHES := "res://data/orison_v2/exterior/city_horizon.json"

func _ready() -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FINISHES))
	assert(int(source.schema) == 1 and str(source.frame) == "ORISON_V2_BUILDING_FRAME")
	var profiles: Dictionary = {}
	for row: Dictionary in source.buildings: profiles[str(row.id)] = row
	var materials: Dictionary = {}
	var roof_finishes := preload("res://scripts/building/orison_v2_owner_finishes.gd").new()
	for asset: PackedScene in ASSETS:
		var model := asset.instantiate() as Node3D
		add_child(model)
		for draw: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			var pieces := str(draw.name).split("__")
			var identity: String = pieces[0]
			var key: String = pieces[-1]
			assert(profiles.has(identity) and MatLib.SETS.has(key))
			var profile: Dictionary = profiles[identity]
			var tint: Array = profile.wall_tint if key == str(profile.wall_key) else [.16,.20,.23,1] if key == "mirror_aged" else [1,1,1,1]
			var cache_key := key + "|" + str(tint)
			if not materials.has(cache_key):
				var stock := MatLib.get_mat(key).duplicate() as StandardMaterial3D
				stock.uv1_triplanar = false
				stock.albedo_color = Color(tint[0],tint[1],tint[2],tint[3])
				stock.normal_scale = .12 if key == "mirror_aged" else .55
				if key == "mirror_aged":
					stock.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
					stock.metallic = 0.0
					stock.roughness = .45
				materials[cache_key] = stock
			draw.material_override = materials[cache_key]
			if key == "galvanized_roof":
				draw.set_meta("v2_city_roof_source",materials[cache_key])
				draw.material_override = roof_finishes.material_for(materials[cache_key],"roof")
			draw.set_meta("v2_city_horizon_building",identity)
			var body := StaticBody3D.new()
			body.name = "HorizonCollision"
			draw.add_child(body)
			var shape := CollisionShape3D.new()
			var native := ConcavePolygonShape3D.new()
			native.set_faces(preload("res://scripts/building/orison_v2_native_faces.gd").read(draw.mesh))
			shape.shape = native
			body.add_child(shape)
