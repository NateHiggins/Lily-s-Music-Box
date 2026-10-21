extends RefCounted
## Diagnostic-only exact triangle buckets. No weld, hull, cap, vertex transform,
## simplification, topology repair or obstruction exclusion. Open faces stay open.
static func build(source: ConcavePolygonShape3D) -> Array[Shape3D]:
 var result: Array[Shape3D]=[]
 var faces: PackedVector3Array=source.get_faces()
 if faces.size()<1536:return [source]
 var bounds:=AABB(faces[0],Vector3.ZERO)
 for point: Vector3 in faces:bounds=bounds.expand(point)
 var groups: Array=[]
 for index in 64:groups.append([])
 for index in range(0,faces.size(),3):
  var center: Vector3=(faces[index]+faces[index+1]+faces[index+2])/3.
  var cell:=Vector3i.ZERO
  for axis in 3:cell[axis]=clampi(int(floor((center[axis]-bounds.position[axis])/maxf(bounds.size[axis],.0000001)*4.)),0,3)
  groups[cell.x+4*cell.y+16*cell.z].append(index)
 for group: Array in groups:
  if group.is_empty():continue
  var retained:=PackedVector3Array();retained.resize(group.size()*3)
  for index in group.size():
   for corner in 3:retained[index*3+corner]=faces[int(group[index])+corner]
  var shape:=ConcavePolygonShape3D.new()
  shape.margin=source.margin;shape.backface_collision=source.backface_collision;shape.set_faces(retained)
  result.append(shape)
 return result
