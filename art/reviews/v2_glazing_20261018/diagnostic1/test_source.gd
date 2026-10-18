extends "res://tests/v2_street_optics_probe.gd"
## INERT controlled light/roughness diagnosis. All production settings restore.
func _shot(label: String) -> void:
 await super._shot(label)
 if label!="approach_original":return
 var lights: Array=[]
 var rows: Array=[]
 for light: Light3D in world.find_children("*","Light3D",true,false):
  lights.append({"node":light,"specular":light.light_specular})
  rows.append({"path":str(world.get_path_to(light)),"type":light.get_class(),"position":[light.global_position.x,light.global_position.y,light.global_position.z],"size":light.light_size,"specular":light.light_specular,"energy":light.light_energy,"visible":light.is_visible_in_tree()})
  light.light_specular=0
 await super._shot("glazing_all_direct_specular_off")
 for row: Dictionary in lights:(row.node as Light3D).light_specular=row.specular
 var pane := preload("res://scripts/building/orison_v2_bodega_frontage.gd").authored_mesh(world.exterior_cell.instance_node("SHOP_BODEGA"),"right_store_glass")
 var material := pane.material_override as ShaderMaterial
 var roughness: Variant=material.get_shader_parameter("surface_roughness")
 var normal: Variant=material.get_shader_parameter("normal_strength")
 for amount: float in [.12,.24,.4]:
  material.set_shader_parameter("surface_roughness",amount)
  await super._shot("glazing_rough_"+str(amount).replace(".","_"))
 material.set_shader_parameter("surface_roughness",roughness)
 material.set_shader_parameter("normal_strength",0.0)
 await super._shot("glazing_optical_normals_off")
 material.set_shader_parameter("normal_strength",normal)
 var file := FileAccess.open(directory.path_join("glazing_light_diagnosis.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"evidence_class":"INERT","scope":"All direct-specular lights disabled only for one control, then restored. Three temporary architectural-glass roughness controls and normal-off control; no production changes or acceptance.","lights":rows},"\t"));file.close()
