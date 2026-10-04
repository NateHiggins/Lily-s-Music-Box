"""Source-owned Orison roof/drainage construction.

Retained gameplay authorities remain; geometry and material validation are
independent of this source recipe. No drainage capacity acceptance.
"""
from pathlib import Path
import json, math, hashlib, collections, os
import bpy, bmesh, numpy as np
from mathutils import Vector

R=next(path for path in Path(__file__).resolve().parents if (path/'game/project.godot').is_file());O=R/'art/blender';O.mkdir(parents=True,exist_ok=True)
S=R/'art/data/orison_roof_drainage/roof_grade.json';study=json.loads(S.read_bytes())
roof=json.loads((R/'art/data/orison_v2/roof_source.json').read_bytes())['records']
decks=[d for d in roof['spaces'] if d['id'].startswith('ROOF_DECK_')]
xs=study['grid_x'];zs=study['grid_z'];base=study['datum'];skin=study['membrane_thickness']
heights={(round(p['point'][0],6),round(p['point'][2],6)):p['point'][1] for p in study['downhill_edges']}
for d in study['outlets']:heights[tuple(d['point'])]=base+study['overburden_toe']+skin

def inside(rect,x,z,strict=False):
 a,b,c,d=rect
 return a+1e-8<x<c-1e-8 and b+1e-8<z<d-1e-8 if strict else a-1e-8<=x<=c+1e-8 and b-1e-8<=z<=d+1e-8
def active(x,z):return any(inside(d['rect'],x,z) for d in decks) and not any(inside(b,x,z,True) for b in study['blocked_routing_rectangles']) and (not study.get('roof_field_bounds') or inside(study['roof_field_bounds'],x,z))
cells=[];points=[];point_index={};triangles=[];owners=[]
def vertex(x,z,height):
 key=(round(x,9),round(z,9))
 if key not in point_index:point_index[key]=len(points);points.append([key[0],height,key[1]])
 else:assert abs(points[point_index[key]][1]-height)<1e-8,('Discontinuous roof crease',key,height,points[point_index[key]])
 return point_index[key]

def clip_polygon(polygon,plane):
 """Clip a cell to an exact lower-envelope plane, retaining real creases."""
 result=[]
 for start,end in zip(polygon,polygon[1:]+polygon[:1]):
  sa=float(plane[0]*start[0]+plane[1]*start[1]+plane[2]);sb=float(plane[0]*end[0]+plane[1]*end[1]+plane[2])
  if sa<=1e-11:result.append(start)
  if (sa<-1e-11 and sb>1e-11) or (sa>1e-11 and sb<-1e-11):
   t=sa/(sa-sb);result.append((start[0]+t*(end[0]-start[0]),start[1]+t*(end[1]-start[1])))
 cleaned=[]
 for p in result:
  if not cleaned or math.dist(p,cleaned[-1])>1e-9:cleaned.append(p)
 if len(cleaned)>1 and math.dist(cleaned[0],cleaned[-1])<1e-9:cleaned.pop()
 return cleaned

crease_cells=0
for i in range(len(xs)-1):
 for j in range(len(zs)-1):
  a,c=xs[i:i+2];b,d=zs[j:j+2];x=(a+c)/2;z=(b+d)/2
  if not active(x,z):continue
  keys=[(a,b),(c,b),(c,d),(a,d)];assert all(k in heights for k in keys)
  owner=next(r['id'] for r in decks if inside(r['rect'],x,z,True))
  # The shortest rectilinear fall is the lower envelope of four corner
  # routes. A diagonal between corner samples smooths real meeting ridges
  # and can invent a shallow patch beside a plant reservation. Preserve
  # the exact affine crease instead of interpolating across it.
  fall=study['fall'];planes=[]
  for (px,pz),(sx,sz) in zip(keys,[(1,1),(-1,1),(-1,-1),(1,-1)]):
   planes.append(np.array([fall*sx,fall*sz,heights[(px,pz)]-fall*(sx*px+sz*pz)]))
  area=0.;pieces=0
  for k,plane in enumerate(planes):
   polygon=[(a,b),(c,b),(c,d),(a,d)]
   for l,other in enumerate(planes):
    if l!=k:polygon=clip_polygon(polygon,plane-other)
    if len(polygon)<3:break
   if len(polygon)<3:continue
   signed=sum(p[0]*q[1]-p[1]*q[0] for p,q in zip(polygon,polygon[1:]+polygon[:1]))*.5
   if signed<1e-12:continue
   area+=signed;pieces+=1
   ids=[vertex(px,pz,float(plane@np.array([px,pz,1.]))) for px,pz in polygon]
   for t in range(1,len(ids)-1):
    triangle=(ids[0],ids[t],ids[t+1]);p=np.array([points[v] for v in triangle])
    if abs(np.linalg.det(np.c_[p[:,0],p[:,2],np.ones(3)]))<1e-12:continue
    triangles.append(triangle);owners.append(owner)
  assert abs(area-(c-a)*(d-b))<1e-9,('Uncovered affine fall cell',a,b,c,d,area)
  crease_cells+=int(pieces>1);cells.append([a,b,c,d])

edges=set();gradients=[]
for triangle in triangles:
 for a,b in zip(triangle,triangle[1:]+triangle[:1]):edges.add(tuple(sorted((a,b))))
 p=np.array([points[v] for v in triangle]);matrix=np.c_[p[:,0],p[:,2],np.ones(3)];plane=np.linalg.solve(matrix,p[:,1]);gradient=float(np.linalg.norm(plane[:2]))
 assert gradient>1e-7,('Flat roof triangle',triangle,p)
 gradients.append(gradient)
# Every graph route must be a real triangulated stock edge, including around
# excluded walls and the four actual fan apertures.
axis_nodes=[collections.defaultdict(list),collections.defaultdict(list)]
for key,index in point_index.items():
 axis_nodes[0][key[0]].append((key[1],index));axis_nodes[1][key[1]].append((key[0],index))
for route in study['downhill_edges']:
 a=(round(route['point'][0],6),round(route['point'][2],6));b=(round(route['toward'][0],6),round(route['toward'][2],6))
 if a not in point_index:continue
 assert b in point_index
 # A meeting ridge can split an original routing edge. Its actual native
 # sub-edges must form the same strictly falling segment to the successor.
 axis=0 if a[0]==b[0] else 1;moving=1-axis
 on=[]
 for coordinate,index in axis_nodes[axis][a[axis]]:
  t=(coordinate-a[moving])/(b[moving]-a[moving])
  if -1e-8<=t<=1.00000001:on.append((t,index))
 on.sort()
 assert all(tuple(sorted((left[1],right[1]))) in edges and points[right[1]][1]<points[left[1]][1]-1e-9 for left,right in zip(on,on[1:])),('Unsupported drainage edge',a,b,on)
 assert heights[b]<heights[a]-1e-9

bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
closed=bpy.data.collections.new('ClosedNativeStocks');bpy.context.scene.collection.children.link(closed);closed.hide_render=True
mat=bpy.data.materials.new('ScratchRoofBitumen');mat.use_nodes=True
node=mat.node_tree.nodes['Principled BSDF'];node.inputs['Base Color'].default_value=(.04,.04,.04,1)
uv_node=mat.node_tree.nodes.new('ShaderNodeTexCoord')
for filename,socket,noncolour in [('albedo.png','Base Color',False),('roughness.png','Roughness',True),('normal.png','Normal',True)]:
 tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(R/'art/textures/procedural/roof_bitumen'/filename),check_existing=True)
 if noncolour:tex.image.colorspace_settings.name='Non-Color'
 tex.image.filepath=bpy.path.relpath(tex.image.filepath,start=str(O));mat.node_tree.links.new(uv_node.outputs['UV'],tex.inputs['Vector'])
 if socket=='Normal':
  normal=mat.node_tree.nodes.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.35;mat.node_tree.links.new(tex.outputs['Color'],normal.inputs['Color']);mat.node_tree.links.new(normal.outputs['Normal'],node.inputs[socket])
 else:mat.node_tree.links.new(tex.outputs['Color'],node.inputs[socket])
sub=bpy.data.materials.new('ScratchTaperedBacking');sub.diffuse_color=(.3,.28,.24,1)
cap=bpy.data.materials.new('ScratchGalvanizedCap');cap.diffuse_color=(.3,.32,.32,1)
stocks=[];visible=[];parts=[];physical=[];door_fittings=[]
def mesh_object(name,vertices,faces,collection,material,recalculate=True):
 origin=tuple(sum(v[i] for v in vertices)/len(vertices) for i in range(3))
 mesh=bpy.data.meshes.new(name);mesh.from_pydata([tuple(v[i]-origin[i] for i in range(3)) for v in vertices],[],faces);mesh.update()
 if recalculate:
  bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
 obj=bpy.data.objects.new(name,mesh);collection.objects.link(obj);obj.location=origin;mesh.materials.append(material)
 uv=mesh.uv_layers.new(name='Metres');uv.active_render=True
 for face in mesh.polygons:
  normal=face.normal.normalized();seed=Vector((1,0,0)) if abs(normal.x)<.85 else Vector((0,1,0));u=(seed-normal*seed.dot(normal)).normalized();v=normal.cross(u).normalized()
  for loop in face.loop_indices:
   p=Vector(origin)+mesh.vertices[mesh.loops[loop].vertex_index].co;uv.data[loop].uv=(p.x,-p.y) if normal.z>.9 else (p.dot(u),p.dot(v))
 return obj
for deck in decks:
 owner=deck['id'];source_tris=[t for t,o in zip(triangles,owners) if o==owner];ids=sorted({v for t in source_tris for v in t});lookup={v:i for i,v in enumerate(ids)}
 local_tris=[tuple(lookup[v] for v in t) for t in source_tris];count=len(ids)
 boundary=collections.Counter(tuple(sorted((a,b))) for t in local_tris for a,b in zip(t,t[1:]+t[:1]))
 assert all(n in [1,2] for n in boundary.values())
 for label,upper,lower,material in [('TaperedBacking',-skin,None,sub),('Membrane',0,-skin,mat),('PhysicalEnvelope',0,'slab',sub)]:
  vertices=[(points[v][0],-points[v][2],points[v][1]+upper) for v in ids]
  vertices += [(points[v][0],-points[v][2],base if lower is None or lower=='slab' else points[v][1]+lower) for v in ids]
  faces=local_tris+[tuple(v+count for v in t) for t in local_tris]+[(a,b,b+count,a+count) for (a,b),n in boundary.items() if n==1]
  obj=mesh_object(owner+'__'+label,vertices,faces,closed,material);obj.hide_render=True
  bm=bmesh.new();bm.from_mesh(obj.data);volume=bm.calc_volume(signed=True);assert all(e.is_manifold for e in bm.edges) and volume>0;bm.free()
  stocks.append({'name':obj.name,'owner':owner,'kind':label,'volume_m3':volume,'vertices':len(vertices),'faces':len(faces)})
  if label=='PhysicalEnvelope':physical.append(obj)
 groups=collections.defaultdict(list)
 for triangle in source_tris:
  center=np.mean([points[v] for v in triangle],axis=0);groups[(math.floor(center[0]/4),math.floor(center[2]/4))].append(triangle)
 for (x,z),source in sorted(groups.items()):
  verts=[(points[v][0],-points[v][2],points[v][1]) for t in source for v in t];faces=[(i,i+2,i+1) for i in range(0,len(verts),3)]
  obj=mesh_object(owner+f'__Field_{x}_{z}',verts,faces,bpy.context.scene.collection,mat,recalculate=False)
  assert all(p.normal.z>.999 for p in obj.data.polygons),obj.name
  visible.append(obj);parts.append({'name':obj.name,'owner':owner,'triangles':len(faces)})
def stock_box(name,low,high,material,show=False):
 vertices=[(x,-z,y) for x in [low[0],high[0]] for y in [low[1],high[1]] for z in [low[2],high[2]]]
 faces=[(0,1,3,2),(4,6,7,5),(0,4,5,1),(2,3,7,6),(0,2,6,4),(1,5,7,3)]
 obj=mesh_object(name,vertices,faces,bpy.context.scene.collection if show else closed,material);obj.hide_render=not show
 bm=bmesh.new();bm.from_mesh(obj.data);assert all(e.is_manifold for e in bm.edges) and bm.calc_volume(signed=True)>0;volume=bm.calc_volume(signed=True);bm.free()
 stocks.append({'name':obj.name,'owner':name.split('__')[0],'kind':name.split('__')[-1],'volume_m3':volume,'vertices':8,'faces':6})
 if show:visible.append(obj);parts.append({'name':obj.name,'owner':name.split('__')[0],'triangles':12})
 else:physical.append(obj)
 return obj
for door in study['doors']:
 if not door.get('curb_rect'):continue
 door=dict(door);a,b,c,d=door['curb_rect'];record=door['source_record'];x,z=record['center']
 # The original 100 degree westward swing reaches farther than the curb's
 # 350 mm outside half. Fit the sill above the actual field throughout a
 # conservative bound of that retained leaf, rather than sample the curb
 # perimeter alone. Keep the moving leaf size, hinge and target unchanged.
 assert abs(record['yaw']-math.pi/2)<1e-9
 sweep=[x-record['width']-.12,z-record['width']/2-.05,x+.08,z+record['width']/2+.25]
 sweep_values=[]
 for triangle in triangles:
  p=np.array([points[v] for v in triangle]);polygon=[(float(q[0]),float(q[2])) for q in p]
  for plane in [np.array([-1,0,sweep[0]]),np.array([1,0,-sweep[2]]),np.array([0,-1,sweep[1]]),np.array([0,1,-sweep[3]])]:
   polygon=clip_polygon(polygon,plane)
   if len(polygon)<3:break
  if len(polygon)<3:continue
  plane=np.linalg.solve(np.c_[p[:,0],p[:,2],np.ones(3)],p[:,1]);sweep_values.extend(float(plane@np.array([px,pz,1.])) for px,pz in polygon)
 assert sweep_values
 top=max(door['candidate_curb_top'],max(sweep_values)+.005)
 door.update(candidate_curb_top=top,candidate_mount_offset=top-base,interior_step=top-base,retained_swing_bounds=sweep,retained_swing_field_max_y=max(sweep_values),original_motion_degrees=100,fitted_leaf_normal_offset_m=-.07,leaf_mount_reason='Hang the original complete roof assembly on the actual 140 mm wall outer face; the source anchor/aperture, width, height and motion remain.')
 stock_box(door['id']+'__CurbBacking',[a,base,b],[c,top-.004,d],sub,True)
 stock_box(door['id']+'__CurbCap',[a,top-.004,b],[c,top,d],cap,True)
 exterior_owner=record['connects'][1]
 landing_candidates=[p['id'] for p in roof['platforms'] if all(inside(p['rect'],px,pz) for px,pz in [(x,b),(c,b),(x,d),(c,d)])]
 assert len(landing_candidates)==1,(door['id'],landing_candidates)
 landing_owner=landing_candidates[0]
 stock_box(door['id']+'__ExteriorPhysicalEnvelope',[a,base,b],[x,top,d],sub)
 stock_box(door['id']+'__InteriorPhysicalEnvelope',[x,base,b],[c,top,d],sub)
 head=stock_box(door['id']+'__FittedHead',[x-.07,top+record['height'],b],[x+.07,22.2,d],sub)
 door_fittings.append({**door,'exterior_floor_owner':exterior_owner,'interior_floor_owner':landing_owner,'head_owner':record['connects'][0]+'/WallWest_Head01','head_original_bounds':[[x-.07,base+record['height'],b],[x+.07,22.2,d]],'head_fitted_bounds':[[x-.07,top+record['height'],b],[x+.07,22.2,d]]})
bpy.ops.outliner.orphans_purge(do_local_ids=True,do_linked_ids=True,do_recursive=True)
native=O/'roof_drainage_falls.blend';bpy.ops.wm.save_as_mainfile(filepath=str(native))
bpy.ops.object.select_all(action='DESELECT')
for obj in visible+physical:obj.select_set(True)
class ExportUVHandedness:
 def gather_attribute_change(self,attribute,data,normalized,export_settings):
  if attribute=='TANGENT':data['data'][:,3]*=-1
import io_scene_gltf2
io_scene_gltf2.glTF2ExportUserExtension=ExportUVHandedness
glb=R/'game/assets/props/roof_drainage_falls.glb'
bpy.ops.export_scene.gltf(filepath=str(glb),export_format='GLB',use_selection=True,export_yup=True,export_tangents=True,export_materials='PLACEHOLDER')
report={'evidence_class':'INERT','status':'SOURCE-GENERATED CONSTRUCTION; INDEPENDENT VALIDATION REQUIRED','classification':'ADAPTATION','study_sha256':hashlib.sha256(S.read_bytes()).hexdigest(),'native_sha256':hashlib.sha256(native.read_bytes()).hexdigest(),'asset_sha256':hashlib.sha256(glb.read_bytes()).hexdigest(),'closed_stocks':stocks,'parts':parts,'vertices':len(points),'triangles':len(triangles),'physical_gradient_range': [min(gradients),max(gradients)],'minimum_retained_structural_thickness':.2,'points':points,'triangles_by_vertex':triangles,'triangle_owners':owners,'door_fittings':door_fittings,'open_work':['actual membrane roll/seam stocks','fitted door curbs and moving leaf clearance','coordinated wall flashing and old leader toes','fan, tank and roof support weather interfaces','source-owned parapet ports and downstream supports','production walking and exact candidate verification']}
report['source_bindings']={**study['source_bindings'],S.relative_to(R).as_posix():hashlib.sha256(S.read_bytes()).hexdigest(),Path(__file__).relative_to(R).as_posix():hashlib.sha256(Path(__file__).read_bytes().replace(b'\r\n',b'\n')).hexdigest()}
report['plant_interface_reservations']=study.get('plant_interface_reservations',[])
report['exact_affine_crease_cells']=crease_cells
(O/'roof_drainage_falls_construction.json').write_text(json.dumps(report,indent=2)+'\n',newline='\n')
print('SOURCE ROOF FALLS',len(stocks),'closed stocks;',len(triangles),'top triangles; gradient',report['physical_gradient_range'])

(R/'game/tests/fixtures/orison_roof_drainage_falls.json').write_bytes((O/'roof_drainage_falls_construction.json').read_bytes())
