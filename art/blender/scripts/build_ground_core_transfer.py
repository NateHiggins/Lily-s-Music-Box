"""Source-derived fitted frame beneath the shifted ground public-core wall.

The retained floor/landing slabs and source apertures keep their owners.
Native footings exclude the earlier foundation union. No shell cut is added.
"""
from pathlib import Path
import json,math,collections,hashlib
import bpy,bmesh
from mathutils import Vector
root=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
layout=json.loads((root/'game/data/orison_v2_blockout.json').read_text())
rooms={r['id']:r for r in layout['spaces']};levels={r['id']:r['y'] for r in layout['levels']}
d=layout['dimensions'];half=d['partition_wall']/2;reach=d['outer_wall']-half
core=rooms['F01_PUBLIC_CORE']['rect'];lower=rooms['B1_PUBLIC_CORE']['rect'];watch=rooms['F01_WATCH']['rect']
x=core[0]-(reach-half)/2
top=levels['F01']-d['slab_thickness'];depth=.45;bottom=top-depth
plan=dict(evidence_class='INERT',authority=['game/data/orison_v2_blockout.json:spaces/dimensions/levels','art/blender/orison_foundations_construction.json:source_plan'],beam_width_m=d['outer_wall'],beam_depth_m=depth,flange_m=.035,web_m=.016,
 beam=dict(bounds=[core[0]-reach,bottom,watch[3]-half,core[0]+half,top,lower[3]-half]),
 cantilever=dict(bounds=[lower[0]+half,bottom,watch[3]-half,core[0]-reach,top,watch[3]+reach]),
 edge_closure=dict(bounds=[core[0]-half,top,watch[3],core[0],levels['F01'],lower[3]-half]),
 columns=[dict(id=side,center=[x+.13 if side=='South' else x,levels['B1'],at],floor_owner='B1_PUBLIC_LANDING_W_SHAFT_1') for side,at in [('South',watch[3]-half+.21),('North',lower[3]-.21)]],
 column_width_m=.18,column_flange_m=.02,column_web_m=.016,base_plate_m=.26,base_plate_depth_m=.02,pad_width_m=.7,pad_depth_m=.4,
 method='Rolled I transfer beam under the source wall base; a short westward cantilever seats the uncovered watch-wall end. Two fitted columns bear on retained basement landing slabs with supplemental pads beneath their exact bottoms, excluding existing foundation union. No laundry wall pocket, service aperture, occupied-room fill or simulation change. Modeled contact does not determine load, reinforcement or soil capacity.')
found=json.loads((root/'art/blender/orison_foundations_construction.json').read_text())['source_plan']
steel=[];concrete=[];components=[]
def add(family,name,b):
 b=[round(v,5) for v in b];(steel if family=='Steel' else concrete).append(b);components.append(dict(family=family,id=name,bounds=b))
def beam(name,b,axis):
 a,y,c,d,t,f=b;fl=plan['flange_m'];web=plan['web_m']
 add('Steel',name+'_Upper',[a,t-fl,c,d,t,f]);add('Steel',name+'_Lower',[a,y,c,d,y+fl,f])
 if axis==2:
  mid=(a+d)/2;add('Steel',name+'_Web',[mid-web/2,y+fl,c,mid+web/2,t-fl,f])
 else:
  mid=(c+f)/2;add('Steel',name+'_Web',[a,y+fl,mid-web/2,d,t-fl,mid+web/2])
beam('Main',plan['beam']['bounds'],2);beam('Cantilever',plan['cantilever']['bounds'],0)
# The watch outer leaf already owns part of the small inner edge band.
# Subtract its actual editable source envelope instead of adding buried volume.
edge=plan['edge_closure']['bounds'];edge_parts=[edge]
with bpy.data.libraries.load(str(root/'art/blender/exterior_masonry.blend'),link=False) as (available,loaded):
 assert 'PreServiceMasonry' in available.collections,'Retained editable masonry authority is required'
 loaded.collections=['PreServiceMasonry']
bounds=[]
for obj in loaded.collections[0].objects:
 assert obj.type=='EMPTY' and obj.parent is None
 p=obj.location;s=obj.scale;at=[p.x,p.z,-p.y];size=[s.x,s.z,s.y]
 bounds.append(dict(name=obj.name,bounds=[at[i]-size[i]/2 for i in range(3)]+[at[i]+size[i]/2 for i in range(3)]))
def subtract_box(b,c):
 lo=[max(b[i],c[i]) for i in range(3)];hi=[min(b[i+3],c[i+3]) for i in range(3)]
 if any(hi[i]<=lo[i]+1e-7 for i in range(3)):return [b]
 a,y,z,d,t,f=b;x,v,w,u,k,m=lo+hi
 return [p for p in [(a,y,z,x,t,f),(u,y,z,d,t,f),(x,y,z,u,v,f),(x,k,z,u,t,f),(x,v,z,u,k,w),(x,v,m,u,k,f)] if all(p[i+3]-p[i]>1e-6 for i in range(3))]
for record in bounds:edge_parts=[s for b in edge_parts for s in subtract_box(b,[round(v,5) for v in record['bounds']])]
for i,b in enumerate(edge_parts):add('Concrete','CoreEdge%02d'%i,b)
def subtract(r,cut):
 a,b,c,d=r;e,f,g,h=cut;lo=max(a,e);hi=min(c,g);low=max(b,f);high=min(d,h)
 if lo>=hi-1e-7 or low>=high-1e-7:return [r]
 return [s for s in [(a,b,lo,d),(hi,b,c,d),(lo,b,hi,low),(lo,high,hi,d)] if s[2]-s[0]>1e-6 and s[3]-s[1]>1e-6]
for col in plan['columns']:
 x,y,z=col['center'];w=plan['column_width_m']/2;fl=plan['column_flange_m'];web=plan['column_web_m']/2;plate=plan['base_plate_m']/2;pdepth=plan['base_plate_depth_m'];cap_y=plan['beam']['bounds'][1]
 add('Steel',col['id']+'_Base',[x-plate,y,z-plate,x+plate,y+pdepth,z+plate])
 for j,(dx,dz) in enumerate([(-.11,-.11),(-.11,.11),(.11,-.11),(.11,.11)]):
  bx,bz=x+dx,z+dz
  add('Steel',col['id']+'_AnchorWasher%d'%j,[bx-.0125,y+pdepth,bz-.0125,bx+.0125,y+pdepth+.003,bz+.0125])
  add('Steel',col['id']+'_AnchorHead%d'%j,[bx-.009,y+pdepth+.003,bz-.009,bx+.009,y+pdepth+.015,bz+.009])
 cap_half=.175 if col['id']=='South' else plate
 add('Steel',col['id']+'_Cap',[x-cap_half,cap_y-pdepth,z-plate,x+cap_half,cap_y,z+plate])
 low,high=y+pdepth,cap_y-pdepth
 add('Steel',col['id']+'_WestFlange',[x-w,low,z-w,x-w+fl,high,z+w])
 add('Steel',col['id']+'_EastFlange',[x+w-fl,low,z-w,x+w,high,z+w])
 add('Steel',col['id']+'_Web',[x-w+fl,low,z-web,x+w-fl,high,z+web])
 pad=plan['pad_width_m']/2;rects=[[x-pad,z-pad,x+pad,z+pad]]
 for mask in found['footings']:rects=[s for r in rects for s in subtract(r,mask)]
 for i,r in enumerate(rects):add('Concrete',col['id']+'_Pad%02d'%i,[r[0],y-.2-plan['pad_depth_m'],r[1],r[2],y-.2,r[3]])
# Stiffener plates tie the short transverse cantilever to the main web.
b=plan['beam']['bounds'];s=plan['cantilever']['bounds'];mid=(b[0]+b[3])/2
for side,z in [('Front',s[2]),('Rear',s[5]-.016)]:add('Steel','Junction_'+side,[b[0],b[1]+plan['flange_m'],z,mid,b[4]-plan['flange_m'],z+.016])
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.context.preferences.filepaths.save_version=0
construction=bpy.data.collections.new('TransferConstruction');bpy.context.scene.collection.children.link(construction);construction.hide_render=True;construction.hide_viewport=True
for r in components:
 b=r['bounds'];obj=bpy.data.objects.new(r['id'],None);obj.empty_display_type='CUBE';obj.empty_display_size=.5;obj.location=((b[0]+b[3])/2,-(b[2]+b[5])/2,(b[1]+b[4])/2);obj.scale=(b[3]-b[0],b[5]-b[2],b[4]-b[1]);construction.objects.link(obj)
materials={}
for family,key,color in [('Steel','metal',(.28,.27,.25,1)),('Concrete','concrete',(.36,.34,.30,1))]:
 mat=bpy.data.materials.new(key);mat.diffuse_color=color;materials[family]=mat
parts=[];reports=[];total_quads=0
for family,solids in [('Steel',steel),('Concrete',concrete)]:
 grids=[]
 for axis in range(3):
  values={v for b in solids for v in [b[axis],b[axis+3]]}
  values.update(4*i for i in range(math.floor(min(values)/4),math.ceil(max(values)/4)+1) if min(values)<4*i<max(values))
  grids.append(sorted(values))
 xs,ys,zs=grids;occupied=set()
 for ix,(a,d) in enumerate(zip(xs,xs[1:])):
  for iy,(b,e) in enumerate(zip(ys,ys[1:])):
   for iz,(c,f) in enumerate(zip(zs,zs[1:])):
    if any(v[0]<(a+d)/2<v[3] and v[1]<(b+e)/2<v[4] and v[2]<(c+f)/2<v[5] for v in solids):occupied.add((ix,iy,iz))
 faces=[]
 for ix,iy,iz in sorted(occupied):
  a,d=xs[ix:ix+2];b,e=ys[iy:iy+2];c,f=zs[iz:iz+2]
  for neighbor,face in [((ix-1,iy,iz),[(a,b,c),(a,b,f),(a,e,f),(a,e,c)]),((ix+1,iy,iz),[(d,b,c),(d,e,c),(d,e,f),(d,b,f)]),((ix,iy-1,iz),[(a,b,c),(d,b,c),(d,b,f),(a,b,f)]),((ix,iy+1,iz),[(a,e,c),(a,e,f),(d,e,f),(d,e,c)]),((ix,iy,iz-1),[(a,b,c),(a,e,c),(d,e,c),(d,b,c)]),((ix,iy,iz+1),[(a,b,f),(d,b,f),(d,e,f),(a,e,f)])]:
   if neighbor not in occupied:faces.append(face)
 total_quads+=len(faces)
 mesh=bpy.data.meshes.new(family+'Union');mesh.from_pydata([(p[0],-p[2],p[1]) for face in faces for p in face],[],[tuple(range(i,i+4)) for i in range(0,4*len(faces),4)]);mesh.update()
 bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-7)
 bad=sum(not e.is_manifold for e in bm.edges);print(family,'quads',len(faces),'non-manifold',bad);assert bad==0
 unseen=set(bm.verts);islands=0
 while unseen:
  islands+=1;stack=[unseen.pop()]
  while stack:
   vertex=stack.pop()
   for edge in vertex.link_edges:
    other=edge.other_vert(vertex)
    if other in unseen:unseen.remove(other);stack.append(other)
 if family=='Steel':assert islands==1,'The plates, posts and beams must form one connected native assembly'
 print(family,'connected native assemblies',islands)
 bm.to_mesh(mesh);bm.free();complete=bpy.data.objects.new(family+'Union',mesh);construction.objects.link(complete)
 groups=collections.defaultdict(list)
 for face in faces:
  center=[sum(p[k] for p in face)/4 for k in range(3)];key=tuple(math.floor(center[k]/4+1e-9) for k in range(3));groups[key].append(face)
 for key,quads in sorted(groups.items()):
  name=family+'_'+'_'.join('P%d'%v if v>=0 else 'N%d'%-v for v in key)
  mesh=bpy.data.meshes.new(name);mesh.from_pydata([(p[0],-p[2],p[1]) for face in quads for p in face],[],[tuple(range(i,i+4)) for i in range(0,4*len(quads),4)]);mesh.update()
  bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-7)
  bm.normal_update()
  before=len(bm.faces)
  print('SOURCE EDGE ANGLES',sum(e.is_manifold and e.calc_face_angle(0)<.001 for e in bm.edges),'coplanar of',len(bm.edges))
  bmesh.ops.dissolve_limit(bm,angle_limit=.001,use_dissolve_boundaries=family=='Steel',verts=list(bm.verts),edges=list(bm.edges),delimit=set())
  print('COPLANAR SIMPLIFICATION',name,before,'->',len(bm.faces))
  bmesh.ops.dissolve_degenerate(bm,dist=1e-7,edges=list(bm.edges))
  if family=='Steel':
   assert all(e.is_manifold for e in bm.edges),'This compact steel assembly must remain complete in one culling partition'
   corners=[edge for edge in bm.edges if edge.calc_face_angle(0)>1e-5]
   bmesh.ops.bevel(bm,geom=corners,offset=.0015,segments=1,affect='EDGES',clamp_overlap=True)
   # Blender's float coordinates can split one bevel point by a fraction
   # of a micron. Weld those coincident points before native triangulation.
   bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-6)
   bmesh.ops.dissolve_degenerate(bm,dist=1e-6,edges=list(bm.edges))
   assert all(e.is_manifold for e in bm.edges),'Native external chamfers must preserve the closed assembly'
  bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
  bmesh.ops.triangulate(bm,faces=list(bm.faces))
  bad_faces=[face for face in bm.faces if face.calc_area()<=1e-12]
  if bad_faces:print('DEGENERATE NATIVE TRIANGLES',[(face.calc_area(),[list(v.co) for v in face.verts]) for face in bad_faces[:8]])
  assert not bad_faces,'Reinspect a degenerate native chamfer triangle'
  bm.to_mesh(mesh);bm.free();mesh.update()
  obj=bpy.data.objects.new(name,mesh);bpy.context.scene.collection.objects.link(obj);parts.append(obj);mesh.materials.append(materials[family])
  uv=mesh.uv_layers.new(name='Metres');uv.active_render=True
  for poly in mesh.polygons:
   normal=poly.normal.normalized();axis=min([Vector((1,0,0)),Vector((0,1,0)),Vector((0,0,1))],key=lambda v:abs(v.dot(normal)))
   u=(axis-normal*axis.dot(normal)).normalized();v=normal.cross(u).normalized()
   for loop in poly.loop_indices:
    p=mesh.vertices[mesh.loops[loop].vertex_index].co;uv.data[loop].uv=(p.dot(u),p.dot(v))
  lo=[min(p[k] for face in quads for p in face) for k in range(3)];hi=[max(p[k] for face in quads for p in face) for k in range(3)]
  assert max(hi[k]-lo[k] for k in range(3))<=4.000001
  mesh.calc_loop_triangles()
  reports.append(dict(id=name,family=family,bounds=lo+hi,source_union_quads=len(quads),native_triangles=len(mesh.loop_triangles),internal_caps=False))
bpy.ops.wm.save_as_mainfile(filepath=str(root/'art/blender/ground_core_transfer.blend'))
bpy.ops.object.select_all(action='DESELECT')
for obj in parts:obj.select_set(True)
bpy.context.view_layer.objects.active=parts[0]
class ExportUVHandedness:
 partitions=0
 def gather_attribute_change(self,attribute,data,normalized,export_settings):
  if attribute=='TANGENT':data['data'][:,3]*=-1;type(self).partitions+=1
import io_scene_gltf2
io_scene_gltf2.glTF2ExportUserExtension=ExportUVHandedness
bpy.ops.export_scene.gltf(filepath=str(root/'game/assets/props/ground_core_transfer.glb'),export_format='GLB',export_yup=True,export_tangents=True,use_selection=True)
assert ExportUVHandedness.partitions==len(parts)
for obj in parts:obj.data.calc_loop_triangles()
native_triangles=sum(len(obj.data.loop_triangles) for obj in parts)
(root/'art/blender/ground_core_transfer_construction.json').write_text(json.dumps(dict(evidence_class='INERT',source_plan=plan,components=components,parts=reports,grid_union_quads=total_quads,native_triangles=native_triangles,source_layout_sha256_lf=hashlib.sha256((root/'game/data/orison_v2_blockout.json').read_text().replace('\r\n','\n').encode()).hexdigest(),source_masonry_sha256=hashlib.sha256((root/'game/assets/props/exterior_masonry.glb').read_bytes()).hexdigest()),indent=2)+'\n')
print('GROUND CORE TRANSFER:',len(parts),'parts;',sum(len(obj.data.loop_triangles) for obj in parts),'triangles; coplanar divisions dissolved; 1.5 mm steel chamfers')
