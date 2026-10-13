extends Node
func _ready() -> void:
 var model:Node=(load("res://assets/props/washer_controls.glb") as PackedScene).instantiate()
 var triangles:=0;var collapsed:=0
 for draw:MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
  for surface in draw.mesh.get_surface_count():
   var a:Array=draw.mesh.surface_get_arrays(surface)
   var uv:PackedVector2Array=a[Mesh.ARRAY_TEX_UV];var idx:PackedInt32Array=a[Mesh.ARRAY_INDEX]
   for t in range(0,idx.size(),3):
    triangles+=1
    if absf((uv[idx[t+1]]-uv[idx[t]]).cross(uv[idx[t+2]]-uv[idx[t]]))<.00000000001:collapsed+=1
 print("WASHER UV triangles=",triangles," collapsed=",collapsed)
 var bad_mips:=0
 for key in ["washer_zinc","washer_enamel","washer_brass","washer_rubber"]:
  for suffix in ["albedo","rough","normal"]:
   var texture:Texture2D=load("res://assets/building/textures/T_ai_materials_"+key+"_"+suffix+".png")
   if texture.get_image().get_mipmap_count()==0:bad_mips+=1
 print("WASHER MAPS unmipped=",bad_mips)
 model.free();get_tree().quit(1 if collapsed or bad_mips else 0)
