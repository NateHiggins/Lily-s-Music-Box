"""Source-owned Orison roof/drainage construction.

Retained gameplay authorities remain; geometry and material validation are
independent of this source recipe. No drainage capacity acceptance.
"""
import bisect,collections
import bpy,bmesh
from mathutils import Vector

def build_closed_ground(rectangles,collection,expected_volume):
 def line_key(axis,p):return (axis,)+tuple(p[i] for i in range(3) if i!=axis)
 lines=collections.defaultdict(set)
 for face in rectangles:
  for p in face:
   for axis in range(3):lines[line_key(axis,p)].add(p[axis])
 lines={key:sorted(values) for key,values in lines.items()}
 points=[];point_index={};faces=[]
 for rectangle in rectangles:
  polygon=[]
  for a,b in zip(rectangle,rectangle[1:]+rectangle[:1]):
   axis=next(i for i in range(3) if a[i]!=b[i]);values=lines[line_key(axis,a)];low=min(a[axis],b[axis]);high=max(a[axis],b[axis])
   values=values[bisect.bisect_left(values,low):bisect.bisect_right(values,high)]
   if a[axis]>b[axis]:values=list(reversed(values))
   for value in values[:-1]:
    p=list(a);p[axis]=value;p=tuple(p)
    if p not in point_index:point_index[p]=len(points);points.append((p[0],-p[2],p[1]))
    polygon.append(point_index[p])
  assert len(set(polygon))==len(polygon)
  faces.append(polygon)
 mesh=bpy.data.meshes.new('OrisonGroundClosedUnion');mesh.from_pydata(points,[],faces);mesh.update()
 bm=bmesh.new();bm.from_mesh(mesh);bm.normal_update();tag=bm.faces.layers.int.new('SourceRectangle')
 for index,face in enumerate(bm.faces):face[tag]=index
 bad=[edge for edge in bm.edges if not edge.is_manifold];assert all(len(edge.link_faces)==4 for edge in bad)
 replacements={};affected=set();split_fans=0
 def owner(edge,face):
  a,b=edge.verts;mid=(a.co+b.co)*.5;axis=max(range(3),key=lambda i:abs(a.co[i]-b.co[i]));center=face.calc_center_bounds()
  return tuple((-1 if -face.normal[i]<0 else 1) if abs(face.normal[i])>.5 else (-1 if center[i]<mid[i] else 1) for i in range(3) if i!=axis)
 for vertex in set(v for edge in bad for v in edge.verts):
  linked=list(vertex.link_faces);parent={face[tag]:face[tag] for face in linked}
  def find(index):
   while parent[index]!=index:parent[index]=parent[parent[index]];index=parent[index]
   return index
  def join(a,b):parent[find(a)]=find(b)
  for edge in vertex.link_edges:
   fs=list(edge.link_faces)
   if len(fs)==2:join(fs[0][tag],fs[1][tag])
   else:
    assert len(fs)==4;groups=collections.defaultdict(list)
    for face in fs:groups[owner(edge,face)].append(face)
    assert len(groups)==2 and all(len(pair)==2 for pair in groups.values()),[(owner(edge,f),f.normal[:]) for f in fs]
    for pair in groups.values():join(pair[0][tag],pair[1][tag])
  fans=collections.defaultdict(list)
  for face in linked:fans[find(face[tag])].append(face)
  for index,fan in enumerate(fans.values()):
   target=vertex if index==0 else bm.verts.new(vertex.co.copy())
   split_fans+=bool(index)
   for face in fan:replacements[(vertex,face[tag])]=target;affected.add(face)
 templates=[(face[tag],[replacements.get((v,face[tag]),v) for v in face.verts]) for face in affected]
 for face in affected:bm.faces.remove(face)
 for index,vertices in templates:bm.faces.new(vertices)[tag]=index
 loose=[edge for edge in bm.edges if not edge.link_faces]
 if loose:bmesh.ops.delete(bm,geom=loose,context='EDGES')
 loose=[v for v in bm.verts if not v.link_faces]
 if loose:bmesh.ops.delete(bm,geom=loose,context='VERTS')
 bm.normal_update();assert all(edge.is_manifold for edge in bm.edges)
 volume=bm.calc_volume(signed=True);assert abs(volume-expected_volume)<.00001,(volume,expected_volume)
 area=sum(face.calc_area() for face in bm.faces);bm.to_mesh(mesh);bm.free()
 obj=bpy.data.objects.new('OrisonGroundClosedUnion',mesh);collection.objects.link(obj)
 print('CONFORMING EXACT SOIL UNION',len(rectangles),'rectangles;',len(points),'represented vertices;',len(bad),'edge contacts;',split_fans,'split fans; volume error',abs(volume-expected_volume),flush=True)
 return mesh,area,len(bad),split_fans
