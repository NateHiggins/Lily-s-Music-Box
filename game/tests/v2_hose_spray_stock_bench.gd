extends "res://tests/v2_hose_production_hand_bench.gd"
## Existing actual-input programme plus exact loaded water-map chain checks.
var _water_maps_checked:=false

func check(ok: bool,label: String) -> bool:
	var passed: bool=super.check(ok,label)
	if not ok or _water_maps_checked or label!="water spray retains the registered UV-based custom water finish":return passed
	_water_maps_checked=true
	var rows: Array=[]
	for node: GPUParticles3D in get_tree().root.find_children("*","GPUParticles3D",true,false):
		if node.name!="NozzleWater" or not node.emitting:continue
		var finish: StandardMaterial3D=node.draw_pass_1.surface_get_material(0)
		var stock:=MatLib.get_mat("water_clear")
		var textures: Array[Texture2D]=[finish.albedo_texture,finish.roughness_texture,finish.normal_texture]
		var originals: Array[Texture2D]=[stock.albedo_texture,stock.roughness_texture,stock.normal_texture]
		for index in textures.size():
			var texture:=textures[index]
			var image:=texture.get_image()
			var expected:=int(floor(log(float(maxi(image.get_width(),image.get_height())))/log(2.)))
			super.check(texture==originals[index] and image.get_mipmap_count()==expected,"loaded registered water map has every expected mip level: "+str(index))
			rows.append({"path":texture.resource_path,"width":image.get_width(),"height":image.get_height(),"mipmaps":image.get_mipmap_count(),"expected":expected})
		super.check(node.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and node.gi_mode==GeometryInstance3D.GI_MODE_DISABLED,"optical water fill adds neither opaque shadows nor scene GI emission")
	super.check(rows.size()==3,"one active nozzle exposes exactly its three registered water maps")
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("water_maps.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Loaded map identity and complete mip chains during actual fixture spray input. No installed-area or human acceptance.","maps":rows},"\t"))
	return passed
