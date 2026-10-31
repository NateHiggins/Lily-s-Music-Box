"""Source-owned Orison roof/drainage construction.

Retained gameplay authorities remain; geometry and material validation are
independent of this source recipe. No drainage capacity acceptance.
"""
import bisect,collections,math
import bpy,bmesh
from mathutils import Vector

def apply_soil_cuts(obj,collection,specifications,expected_removed):
 """Cut the closed native soil, and return only genuinely new cavity faces.

 Existing render faces are clipped independently in float64 by the shared
 geometry helper. They never round-trip through this global float32 proof mesh.
 """
 from city_ground_apron_geometry import soil_cut_prisms,convex_union_boundaries
 from city_street_geometry import overlap
 bpy.context.view_layer.update()
 points=[obj.matrix_world@Vector(p) for p in obj.bound_box]
 box=[min(p.x for p in points),-max(p.y for p in points),max(p.x for p in points),-min(p.y for p in points)]
 prisms=[p for p in soil_cut_prisms(specifications) if overlap(box,p['bounds'])]
 if not prisms:
  assert abs(expected_removed)<.00001
  return [],{'expected_removed_m3':expected_removed,'actual_removed_m3':0.,'new_triangles':0}
 # The source LOD stocks intentionally overlap. Feeding their entire interior
 # arrangement to EXACT with use_self exhausted physical RAM on the full site.
 # Keep only the actual directed union boundary per affine floor. Five compact
 # closed cutters replace hundreds of overlapping solids without filling gaps.
 source_prisms=len(prisms);groups=collections.defaultdict(list)
 for prism in prisms:groups[(prism['slope'],prism['intercept'])].append(prism['polygon'])
 prisms=[{'polygon':polygon,'slope':slope,'intercept':intercept}
         for (slope,intercept),polygons in groups.items()
         for polygon in convex_union_boundaries(polygons)]
 print('NATIVE STREET CUT BOUNDARIES:',source_prisms,'overlapping source prisms ->',len(prisms),'closed union-outline cutters',flush=True)
 def volume():
  bm=bmesh.new();bm.from_mesh(obj.data);bm.normal_update()
  assert all(e.is_manifold for e in bm.edges),'Native soil Boolean opened a boundary'
  result=bm.calc_volume(signed=True);bm.free();return result
 before=volume()
 mats=[]
 for i in range(5):
  name='NativeSoilCut'+str(i);mat=bpy.data.materials.get(name) or bpy.data.materials.new(name)
  mats.append(mat)
 obj.data.materials.clear()
 for mat in mats:obj.data.materials.append(mat)
 for face in obj.data.polygons:face.material_index=0
 cutters=bpy.data.collections.new('NativeStreetSubgradeCut');bpy.context.scene.collection.children.link(cutters)
 operands=[]
 for index,prism in enumerate(prisms):
  p=prism['polygon'];n=len(p)
  vertices=[(x,-z,prism['slope']*x+prism['intercept']) for x,z in p]+[(x,-z,1.) for x,z in p]
  faces=[tuple(range(n)),tuple(reversed(range(n,2*n)))]+[(j,i,i+n,j+n) for i in range(n) for j in [(i+1)%n]]
  mesh=bpy.data.meshes.new('StreetCut'+str(index));mesh.from_pydata(vertices,[],faces);mesh.update()
  for mat in mats:mesh.materials.append(mat)
  for face in mesh.polygons:face.material_index=4
  operand=bpy.data.objects.new(mesh.name,mesh);cutters.objects.link(operand);operands.append(operand)
 hidden=collection.hide_viewport;object_hidden=obj.hide_get()
 try:
  collection.hide_viewport=False;obj.hide_set(False)
  bpy.context.view_layer.update();bpy.context.view_layer.objects.active=obj
  modifier=obj.modifiers.new('SourceOwnedStreetCut','BOOLEAN')
  modifier.operation='DIFFERENCE';modifier.operand_type='COLLECTION';modifier.collection=cutters
  modifier.solver='EXACT';modifier.use_self=True;modifier.material_mode='INDEX'
  bpy.ops.object.modifier_apply(modifier=modifier.name)
  after=volume()
  assert abs((before-after)-expected_removed)<.001,('Independent native street cut volume',before-after,expected_removed)
  bm=bmesh.new();bm.from_mesh(obj.data)
  selected=[f for f in bm.faces if f.material_index==4]
  bmesh.ops.triangulate(bm,faces=selected)
  bm.to_mesh(obj.data);bm.free();obj.data.update()
  cavity=[]
  for face in obj.data.polygons:
   if face.material_index!=4:continue
   points=[obj.matrix_world@obj.data.vertices[i].co for i in face.vertices]
   cavity.append([(p.x,p.z,-p.y) for p in points])
  report={'expected_removed_m3':expected_removed,'actual_removed_m3':before-after,
          'before_m3':before,'after_m3':after,'volume_error_m3':abs(before-after-expected_removed),
          'closed':True,'source_prisms':source_prisms,'operand_prisms':len(prisms),'new_triangles':len(cavity)}
  print('SOURCE-OWNED STREET SOIL CUT',report,flush=True)
  return cavity,report
 finally:
  collection.hide_viewport=hidden;obj.hide_set(object_hidden)
  for operand in operands:
   mesh=operand.data;bpy.data.objects.remove(operand,do_unlink=True)
   bpy.data.meshes.remove(mesh)
  bpy.data.collections.remove(cutters)

def build_closed_ground(rectangles,collection,expected_volume,sloped=False):
 def line_key(axis,p):return (axis,)+tuple(p[i] for i in range(3) if i!=axis)
 def general_line(a,b):
  axis=max(range(3),key=lambda i:abs(b[i]-a[i]));scale=b[axis]-a[axis]
  assert abs(scale)>1e-12
  direction=[(b[i]-a[i])/scale for i in range(3)]
  intercept=[a[i]-direction[i]*a[axis] for i in range(3)]
  return (axis,)+tuple(round(v,9) for v in direction+intercept)
 lines=collections.defaultdict(set)
 for face in rectangles:
  if sloped:
   for a,b in zip(face,face[1:]+face[:1]):
    key=general_line(a,b);axis=key[0];lines[key].update([a[axis],b[axis]])
  else:
   for p in face:
    for axis in range(3):lines[line_key(axis,p)].add(p[axis])
 lines={key:sorted(values) for key,values in lines.items()}
 points=[];point_index={};faces=[]
 for rectangle in rectangles:
  polygon=[]
  for a,b in zip(rectangle,rectangle[1:]+rectangle[:1]):
   if sloped:key=general_line(a,b);axis=key[0];values=lines[key]
   else:axis=next(i for i in range(3) if a[i]!=b[i]);values=lines[line_key(axis,a)]
   low=min(a[axis],b[axis]);high=max(a[axis],b[axis])
   values=values[bisect.bisect_left(values,low):bisect.bisect_right(values,high)]
   if a[axis]>b[axis]:values=list(reversed(values))
   for value in values[:-1]:
    if sloped:
     t=(value-a[axis])/(b[axis]-a[axis]);p=tuple(u+t*(v-u) for u,v in zip(a,b))
     identity=tuple(round(v,9) for v in p)
    else:p=list(a);p[axis]=value;p=tuple(p);identity=p
    if identity not in point_index:point_index[identity]=len(points);points.append((p[0],-p[2],p[1]))
    polygon.append(point_index[identity])
  if sloped:
   polygon=[p for i,p in enumerate(polygon) if i==0 or p!=polygon[i-1]]
   if len(polygon)>1 and polygon[0]==polygon[-1]:polygon.pop()
  assert len(set(polygon))==len(polygon),(polygon,rectangle)
  assert len(polygon)>=3,rectangle
  faces.append(polygon)
 pre_storage_volume=None
 if sloped:
  center=[(min(p[i] for p in points)+max(p[i] for p in points))*.5 for i in range(3)]
  terms=[]
  for face in faces:
   a=[points[face[0]][i]-center[i] for i in range(3)]
   for j in range(1,len(face)-1):
    b=[points[face[j]][i]-center[i] for i in range(3)]
    c=[points[face[j+1]][i]-center[i] for i in range(3)]
    terms.append((a[0]*(b[1]*c[2]-b[2]*c[1])+a[1]*(b[2]*c[0]-b[0]*c[2])+a[2]*(b[0]*c[1]-b[1]*c[0]))/6)
  pre_storage_volume=math.fsum(terms)
  assert abs(pre_storage_volume-expected_volume)<.00001,('pre-storage affine cell proof',pre_storage_volume,expected_volume)
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
 # Original orthogonal represented planes retain their exact 1e-5 check.
 # Affine intersections additionally pass that same bound before float32 mesh
 # storage; the saved representation retains the inspector's existing 0.001m3
 # absolute gate, independently re-integrated there from saved vertices.
 volume=bm.calc_volume(signed=True);assert abs(volume-expected_volume)<(.001 if sloped else .00001),(volume,expected_volume)
 area=sum(face.calc_area() for face in bm.faces);bm.to_mesh(mesh);bm.free()
 obj=bpy.data.objects.new('OrisonGroundClosedUnion',mesh);collection.objects.link(obj)
 if sloped:
  mesh['pre_storage_volume_m3']=pre_storage_volume
  mesh['represented_volume_error_m3']=abs(volume-expected_volume)
  print('AFFINE SOIL PRE-STORAGE VOLUME ERROR',abs(pre_storage_volume-expected_volume),'m3; bound 0.00001; represented bound 0.001m3',flush=True)
 print('CONFORMING EXACT SOIL UNION',len(rectangles),'rectangles;',len(points),'represented vertices;',len(bad),'edge contacts;',split_fans,'split fans; volume error',abs(volume-expected_volume),flush=True)
 return mesh,area,len(bad),split_fans
