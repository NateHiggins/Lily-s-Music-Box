extends ExteriorDetailPass
## V2 keeps the actual pavement works. Road-end weather cards, their framing
## gantries and their matching invisible road collision do not enter play.
const FRONTAGE_DATA := "res://data/orison_v2/exterior/city_frontage.json"

func _build_street_ends(parent: Node3D,open_east_north: bool=false) -> void:
	var frontage: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FRONTAGE_DATA))
	assert(int(frontage.schema)==1 and str(frontage.id)=="WestNorthWorks")
	var body:=StaticBody3D.new()
	body.name="StreetEndConstructionBoundary"
	body.collision_layer=1|STREET_END_PROBE_LAYER
	body.add_to_group("street_end_boundary")
	body.set_meta("visible_owner","construction_hoarding")
	parent.add_child(body)
	for side: Array in [["West",-20.10],["East",20.60]]:
		var label: String=side[0]
		var x: float=side[1]
		for walk: Array in [[-12.10,5.30,"north"],[-26.105,4.422,"south"]]:
			if open_east_north and label=="East" and walk[2]=="north":continue
			var center: float=walk[0]
			var depth: float=walk[1]
			if label=="West" and walk[2]=="north":
				assert(is_equal_approx(depth,float(frontage.width_m)) and is_equal_approx(float(frontage.height_m),float(frontage.collision_size_m[2])))
				_add_boundary_shape(body,str(frontage.id),frontage.collision_center_m,frontage.collision_size_m,"construction_hoarding")
				_mount_west_frontage(parent,frontage)
			else:
				_add_boundary_shape(body,label+str(walk[2]).capitalize()+"Works",[x,center,1.20],[.36,depth,2.40],"construction_hoarding")
				_box([x,center,1.20],[.36,depth,2.40],Color(.20,.145,.075))
				for i in 5:
					var along:=center-depth*.5+.24+(depth-.48)*float(i)/4.0
					_box([x-signf(x)*.22,along,1.30],[.10,.12,2.60],Color(.68,.43,.15))
			boundary_visible_spans.append({"side":label.to_lower(),"part":walk[2],"owner":"construction_hoarding","centre":center,"depth":depth})
	_build_street_end_hoarding_faces(parent,open_east_north)
	# Retire just the two proxy faces replaced by the native WestNorth body.
	# Keep the other two closed spans and their shader/material owner exact.
	var faces := parent.get_node("StreetEndHoardingFaces") as MultiMeshInstance3D
	var prior := faces.multimesh
	var retained := MultiMesh.new()
	retained.transform_format=MultiMesh.TRANSFORM_3D
	retained.mesh=prior.mesh
	retained.instance_count=prior.instance_count-2
	for index in range(2,prior.instance_count): retained.set_instance_transform(index-2,prior.get_instance_transform(index))
	faces.multimesh=retained
	_build_street_end_marker_lamps(parent,open_east_north)
	var beacons := parent.get_node("StreetEndWorkBeacons") as MultiMeshInstance3D
	beacons.multimesh.set_instance_transform(0,Transform3D(Basis.IDENTITY,GameBoot.b2g(frontage.beacon_center_m)))
	boundary_count=body.get_child_count()


func _mount_west_frontage(parent: Node3D, data: Dictionary) -> void:
	var model := (load(str(data.asset)) as PackedScene).instantiate() as Node3D
	model.name="WestFrontageNative"
	var materials: Dictionary = {}
	for key: String in data.material_keys:
		assert(MatLib.SETS.has(key))
		var stock := MatLib.get_mat(key).duplicate() as StandardMaterial3D
		stock.uv1_triplanar=false
		stock.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		materials[key]=stock
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		var key := str(draw.name).split("__")[-1]
		assert(materials.has(key))
		draw.material_override=materials[key]
	parent.add_child(model)
