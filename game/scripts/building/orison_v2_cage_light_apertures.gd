extends RefCounted
## Fit V2 native cage-source angular size to its actual emitting envelope.
## LightRig still owns tuning; this creates no lamp or gameplay authority.
var records: Dictionary={}
var errors: Array[String]=[]

func setup(world: Node3D,rig: LightRig) -> bool:
 var prepared: Array=[]
 for node: Node in world.find_children("*","Node3D",true,false):
  if not node is LightFixtureProp:continue
  var lamp := node as LightFixtureProp
  if lamp.prop_type!="cage_bulb":continue
  if not lamp.has_meta("v2_native_fixed_light_variant") and not lamp.has_meta("v2_native_work_light"):continue
  var bulbs: Array[MeshInstance3D]=[]
  for draw: MeshInstance3D in lamp._swing_node.find_children("*","MeshInstance3D",true,false):
   if draw.material_override==lamp._bulb_mat:bulbs.append(draw)
  if bulbs.size()!=1:
   errors.append("one native emitting envelope required: "+str(lamp.name));return false
  var scale := bulbs[0].global_basis.get_scale().abs()
  if not scale.is_equal_approx(Vector3.ONE):
   errors.append("native light aperture needs metre-scale stock: "+str(lamp.name));return false
  var envelope: AABB=bulbs[0].transform*bulbs[0].mesh.get_aabb()
  # Godot's finite-source shader uses size/distance as angular radius.
  # The native pear is about 90 mm wide; its cage is not an emitter.
  var radius := maxf(envelope.size.x,envelope.size.z)*.5
  if not is_finite(radius) or radius<.02 or radius>.5:
   errors.append("native emitting radius exceeds the existing tuning API: "+str(lamp.name));return false
  prepared.append({"lamp":weakref(lamp),"bulb":weakref(bulbs[0]),"radius":radius})
 if prepared.is_empty():errors.append("native cage-light family is missing");return false
 # Finish geometry preflight before changing a live setting. The existing
 # public setter keeps maintenance tuning and the source in agreement.
 for row: Dictionary in prepared:
  var lamp: LightFixtureProp=row.lamp.get_ref()
  row["tuning_before"]=rig.fixture_tuning(lamp)
  row["light_id"]=lamp.light.get_instance_id()
  row["light_pose"]=lamp.light.transform
  row["specular"]=lamp.light.light_specular
  rig.set_fixture_tuning(lamp,"source_size",row.radius)
  var after := rig.fixture_tuning(lamp)
  var before: Dictionary=row.tuning_before.duplicate(true)
  after.erase("source_size");before.erase("source_size")
  if before!=after or not is_equal_approx(lamp.light.light_size,row.radius):
   errors.append("native aperture changed unrelated tuning: "+str(lamp.name));return false
  records[lamp.get_instance_id()]=row
 return errors.is_empty()

func for_fixture(lamp: LightFixtureProp) -> Dictionary:
 return records.get(lamp.get_instance_id(),{})
