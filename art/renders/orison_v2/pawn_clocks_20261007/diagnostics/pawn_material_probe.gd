extends SceneTree
func _initialize():
 var cell=load("res://assets/building/floor_01_cells/shop_pawnbroker.gltf").instantiate()
 for draw in cell.find_children("*","MeshInstance3D",true,false):
  if "glassish" in str(draw.name):
   print("GLAZING ",draw.name," surfaces=",draw.mesh.get_surface_count()," shapes=",draw.find_children("*","CollisionShape3D",true,false).size())
   var mat=draw.mesh.surface_get_material(0)
   print("MAPS ",mat.roughness_texture.resource_path," ",mat.normal_texture.resource_path)
 cell.free();quit()
