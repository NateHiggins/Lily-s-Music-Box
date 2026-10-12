extends RefCounted
## Original receiver controls own power; batteries are passive native fittings.
const PATH := "res://data/orison_v2/media_battery_supply.json"
var errors: Array[String] = []

func mount(adapter: OrisonV2AnchorAdapter) -> bool:
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if data.get("schema_version")!=1: return false
	var packed := load(str(data.asset)) as PackedScene
	if packed==null: errors.append("battery stock absent"); return false
	var model := packed.instantiate()
	var materials := {}
	for row: Dictionary in data.installations:
		var radio := adapter.resolve(str(row.id)) as DomesticRadioProp
		var support := adapter.resolve(str(row.support)) as Node3D
		if radio==null or support==null:
			errors.append("battery source owner absent: "+str(row.id)); continue
		if not radio.family in ["three_dial_battery","marconiphone_v2","crosley_pup","homebrew_regenerative"]:
			errors.append("battery supply on incompatible receiver: "+str(row.id)); continue
		var root := Node3D.new(); root.name="MediaBattery_"+str(row.id); support.add_child(root)
		var parts: Array=data.shared.duplicate(); parts.append_array(row.parts)
		for part: Dictionary in parts:
			var native := model.find_child(str(part.name),true,false) as MeshInstance3D
			if native==null: errors.append("battery part absent: "+str(part.name)); continue
			var key := str(part.material)
			if not materials.has(key):
				var mat := MatLib.get_mat(key).duplicate() as StandardMaterial3D
				mat.uv1_triplanar=false; mat.normal_scale=.08
				mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
				if key=="linen": mat.albedo_color=Color(.40,.32,.23)
				if key=="paper": mat.albedo_color=Color(.53,.36,.17)
				materials[key]=mat
			var draw := MeshInstance3D.new(); draw.name=str(part.name); draw.mesh=native.mesh
			draw.transform=native.transform; draw.material_override=materials[key]; root.add_child(draw)
		for spec in [["A",Vector3(-.105,.105,-.091)],["B",Vector3(.085,.090,-.091)]]:
			var label := Label3D.new(); label.text=spec[0]; label.position=spec[1]
			label.rotation.y=PI; label.font_size=32; label.pixel_size=.00065
			label.modulate=Color(.18,.13,.07) if spec[0]=="B" else Color(.73,.67,.52)
			root.add_child(label)
		radio.set_meta("v2_media_battery_supply",weakref(root))
	model.free()
	return errors.is_empty()
