extends "res://tests/v2_street_optics_probe.gd"
## INERT controlled light/roughness diagnosis. All production settings restore.
func _shot(label: String) -> void:
 await super._shot(label)
 if label!="approach_original":return
 var lamp := world.get_node("StreetBoundaries/ShedEntryWorkLamp") as LightFixtureProp
 var specular := lamp.light.light_specular
 var size := lamp.light.light_size
 lamp.light.light_specular=0
 await super._shot("glazing_entry_specular_off")
 lamp.light.light_specular=specular
 for amount: float in [.045,.02,0.0]:
  lamp.light.light_size=amount
  await super._shot("glazing_entry_size_"+str(amount).replace(".","_"))
 lamp.light.light_size=size
 var rows: Array=[]
 for fixture: Node in world.find_children("*","Node3D",true,false):
  if not fixture is LightFixtureProp or not fixture.has_meta("v2_native_work_light"):continue
  var bulbs: Array=[]
  for draw: MeshInstance3D in fixture._swing_node.find_children("*","MeshInstance3D",true,false):
   if draw.material_override==fixture._bulb_mat:
    var bounds: AABB=draw.global_transform*draw.mesh.get_aabb()
    bulbs.append({"node":str(draw.get_path()),"center":[bounds.get_center().x,bounds.get_center().y,bounds.get_center().z],"size":[bounds.size.x,bounds.size.y,bounds.size.z]})
  rows.append({"path":str(world.get_path_to(fixture)),"source":[fixture.light.global_position.x,fixture.light.global_position.y,fixture.light.global_position.z],"source_size":fixture.light.light_size,"bulbs":bulbs})
 var file := FileAccess.open(directory.path_join("glazing_light_diagnosis.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"evidence_class":"INERT","scope":"Only the entry lamp specular and finite-source size change in temporary controls, then restore. Exact loaded native bulb extents are recorded. No production change or acceptance.","lights":rows},"\t"));file.close()
