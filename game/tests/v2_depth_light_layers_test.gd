extends Node3D
const Binding:=preload("res://scripts/lamp/lamp_optical_receivers.gd")
class FieldStub extends RefCounted:
 var ready:=false
 var failed: String=""
var failures: Array[String]=[]
var checks:=0
func check(ok: bool,label: String) -> void:
 checks+=1;print("DEPTH LIGHT LAYERS: ",label," = ",ok)
 if not ok:failures.append(label)
func _ready() -> void:_run.call_deferred()
func _run() -> void:
 var diagnostic:=load("res://tests/v2_depth_light_culling_probe.gd") as Script
 check(diagnostic!=null and diagnostic.can_instantiate(),"composed guard diagnostic compiles in initialized game context")
 var lamp:=SpotLight3D.new();add_child(lamp)
 var fixed:=DirectionalLight3D.new();fixed.light_energy=.52;fixed.shadow_enabled=true;add_child(fixed)
 var original_energy:=fixed.light_energy
 var special:=OmniLight3D.new();special.layers=2;add_child(special)
 var plain:=Binding.new();plain.setup(self,lamp,FieldStub.new())
 check(fixed.layers==1 and special.layers==2 and lamp.layers==1,"default shared binding preserves every light domain")
 plain.dispose()
 var binding:=Binding.new();binding.setup(self,lamp,FieldStub.new(),true)
 check(fixed.layers==Binding.DEPTH_LIGHT_LAYER,"V2 ordinary fixture has its exclusive depth-cull layer")
 check(lamp.layers==1 and special.layers==2,"active lamp and explicit render domains remain owned by their authors")
 check(fixed.light_energy==original_energy and fixed.shadow_enabled,"actual light output and shadow authority are unchanged")
 var late:=OmniLight3D.new();add_child(late)
 for frame in 3:await get_tree().process_frame
 check(late.layers==Binding.DEPTH_LIGHT_LAYER,"late fixture uses the existing node-added binding")
 fixed.layers=4
 binding.restore_depth_light_layers()
 check(not binding.isolate_depth_lights and late.layers==1 and fixed.layers==4,"camera fallback restores only owned layers and preserves another owner change")
 binding.dispose()
 check(late.layers==1 and fixed.layers==4,"disposal cannot reclaim released layer ownership")
 var second:=Binding.new();second.setup(self,lamp,FieldStub.new(),true)
 check(late.layers==Binding.DEPTH_LIGHT_LAYER,"fresh owner can bind restored fixtures")
 var physical:=MeshInstance3D.new();physical.mesh=BoxMesh.new();physical.layers=Binding.DEPTH_LIGHT_LAYER;add_child(physical)
 for frame in 3:await get_tree().process_frame
 check(not second.depth_geometry_clear,"physical geometry on a reserved layer requires conservative full-depth fallback")
 second.dispose()
 check(late.layers==1 and fixed.layers==4 and special.layers==2,"world retirement restores original ordinary fixtures without changing explicit domains")
 print("V2 DEPTH LIGHT LAYERS: ",checks," checks; ",failures.size()," failures")
 get_tree().quit(0 if failures.is_empty() else 1)
