"""Native candidate review of source-routed heating pipes; never exports shipping assets."""
import bpy,bmesh,json,math,sys,hashlib,argparse
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'tools'))
from heating_pipe_fittings import fitted_stations
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--work-dir',type=Path,required=True,
                    help='Directory containing routes, interfaces and boiler-feed; outputs go in native/.')
parser.add_argument('renders',nargs='*',help='Optional capture names; omit to render all views.')
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
OUT=args.work_dir.resolve()/'native';OUT.mkdir(parents=True,exist_ok=True)
render_names=set(args.renders)
route_path=OUT.parent/'heating_routes_exact.json'
data=json.loads(route_path.read_text())
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
catalog=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text())['materials'];spec=catalog['iron_neutral']
mat=bpy.data.materials.new('iron_neutral');mat.use_nodes=True;bsdf=mat.node_tree.nodes['Principled BSDF'];bsdf.inputs['Metallic'].default_value=spec['metallic']
for i,socket in [(0,'Base Color'),(1,'Roughness'),(2,'Normal')]:
 tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(ROOT/'game/assets/building/textures'/spec['files'][i]),check_existing=True)
 if i:tex.image.colorspace_settings.name='Non-Color'
 if i==2:
  normal=mat.node_tree.nodes.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.25;mat.node_tree.links.new(tex.outputs['Color'],normal.inputs['Color']);mat.node_tree.links.new(normal.outputs['Normal'],bsdf.inputs[socket])
 else:mat.node_tree.links.new(tex.outputs['Color'],bsdf.inputs[socket])
def cv(p):return Vector((p[0],-p[2],p[1]))
def repair_boolean_charts(mesh):
 # Preserve continuous cylindrical UVs. Only boolean-generated degenerate
 # charts need a local metric projection; remapping every face creates seams.
 mesh.calc_loop_triangles();uv=mesh.uv_layers.active;bad=set()
 for tri in mesh.loop_triangles:
  a,b,c=[uv.data[i].uv for i in tri.loops]
  area=abs((b.x-a.x)*(c.y-a.y)-(b.y-a.y)*(c.x-a.x))*.5
  if not math.isfinite(area) or area<1e-12:bad.add(tri.polygon_index)
 for face in mesh.polygons:
  if face.index not in bad:continue
  n=face.normal.normalized();u=n.cross(Vector((0,0,1)) if abs(n.z)<.9 else Vector((0,1,0))).normalized();v=n.cross(u);origin=mesh.vertices[face.vertices[0]].co
  for loop in face.loop_indices:
   delta=mesh.vertices[mesh.loops[loop].vertex_index].co-origin;uv.data[loop].uv=(delta.dot(u)/spec['meters_per_tile'],delta.dot(v)/spec['meters_per_tile'])
 return len(bad)

objects=[];rejected=[];census=[]
# Coupling sleeves are closed annular stocks, with no cap across the lumen.
def coupling(name,a,b,level,outer=.035,inner=.029):
 direction=(b-a).normalized();u=direction.cross(Vector((0,0,1)) if abs(direction.z)<.9 else Vector((0,1,0))).normalized();v=direction.cross(u)
 verts=[];faces=[];charts=[];sides=32;length=(b-a).length
 for radius in [outer,inner]:
  for at in [a,b]:
   for j in range(sides):verts.append(at+radius*(u*math.cos(j*math.tau/sides)+v*math.sin(j*math.tau/sides)))
 for layer,radius in enumerate([outer,inner]):
  for j in range(sides):
   k=layer*2*sides+j;n=layer*2*sides+(j+1)%sides
   faces.append((k,n,n+sides,k+sides));charts.append([(j/sides*math.tau*radius,0),((j+1)/sides*math.tau*radius,0),((j+1)/sides*math.tau*radius,length),(j/sides*math.tau*radius,length)])
 for end in [0,1]:
  for j in range(sides):
   k=end*sides+j;n=end*sides+(j+1)%sides;face=(k,k+2*sides,n+2*sides,n)
   faces.append(face);charts.append([((verts[i]-a).dot(u),(verts[i]-a).dot(v)) for i in face])
 mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update();uv=mesh.uv_layers.new(name='MetreUV')
 for face,chart in zip(mesh.polygons,charts):
  for loop,coord in zip(face.loop_indices,chart):uv.data[loop].uv=(coord[0]/spec['meters_per_tile'],coord[1]/spec['meters_per_tile'])
 bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bad=sum(not e.is_manifold for e in bm.edges);volume=bm.calc_volume(signed=True);bm.to_mesh(mesh);bm.free()
 for face in mesh.polygons:face.use_smooth=face.index<2*sides
 mesh.materials.append(mat);obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj);obj['level']=level;obj['branch']=name.split('__')[0];objects.append(obj)
 return {'id':name,'nonmanifold_edges':bad,'volume':volume,'start_blender':list(a),'end_blender':list(b),'outer_radius_m':outer,'inner_radius_m':inner}
joinery=[]
for row in data['branches']:
 try:stations=fitted_stations(row['points_local_godot'])
 except ValueError as e:rejected.append({'id':row['id'],'reason':str(e)});continue
 # Sleeve each end of a long straight stock, leaving elbow arcs exposed.
 for index,((a,ta),(b,tb)) in enumerate(zip(stations,stations[1:])):
  if math.dist(a,b)<.12 or sum(x*y for x,y in zip(ta,tb))<.999999:continue
  aa,bb=cv(a),cv(b);direction=(bb-aa).normalized()
  for suffix,center in [('a',aa+direction*.025),('b',bb-direction*.025)]:
   joinery.append(coupling(row['id']+'__Coupling_%02d_'%index+suffix,center-direction*.02,center+direction*.02,row['level']))
 sides=24;verts=[];faces=[];charts=[];frames=[];distance=0;prev=None;u=None
 for position,tangent in stations:
  at=cv(position);t=cv(tangent).normalized()
  if prev is not None:distance+=(at-prev).length
  if u is None:u=t.cross(Vector((0,0,1)) if abs(t.z)<.9 else Vector((0,1,0))).normalized()
  else:u=(u-t*u.dot(t)).normalized()
  v=t.cross(u).normalized();frames.append((at,u.copy(),v,distance));prev=at
 count=len(frames);layer_size=count*sides
 for radius in [.029,.024]:
  for at,u,v,dist in frames:
   for j in range(sides):verts.append(at+radius*(u*math.cos(j*math.tau/sides)+v*math.sin(j*math.tau/sides)))
 for layer,radius in enumerate([.029,.024]):
  for i in range(count-1):
   for j in range(sides):
    a=layer*layer_size+i*sides+j;b=layer*layer_size+i*sides+(j+1)%sides
    face=(a,b,b+sides,a+sides);uv=[(j/sides*math.tau*radius,frames[i][3]),((j+1)/sides*math.tau*radius,frames[i][3]),((j+1)/sides*math.tau*radius,frames[i+1][3]),(j/sides*math.tau*radius,frames[i+1][3])]
    faces.append(face if layer==0 else tuple(reversed(face)));charts.append(uv if layer==0 else list(reversed(uv)))
 for end in [0,count-1]:
  for j in range(sides):
   a=end*sides+j;b=end*sides+(j+1)%sides;face=(a,a+layer_size,b+layer_size,b)
   faces.append(face);at,u,v,_=frames[end];charts.append([((verts[k]-at).dot(u),(verts[k]-at).dot(v)) for k in face])
 mesh=bpy.data.meshes.new(row['id']);mesh.from_pydata(verts,[],faces);mesh.update();uv=mesh.uv_layers.new(name='MetreUV')
 for face,chart in zip(mesh.polygons,charts):
  for loop,coord in zip(face.loop_indices,chart):uv.data[loop].uv=(coord[0]/spec['meters_per_tile'],coord[1]/spec['meters_per_tile'])
 bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bad=sum(not e.is_manifold for e in bm.edges);volume=bm.calc_volume(signed=True);bm.to_mesh(mesh);bm.free()
 for face in mesh.polygons:face.use_smooth=face.index<2*(count-1)*sides
 obj=bpy.data.objects.new(row['id'],mesh);bpy.context.collection.objects.link(obj);mesh.materials.append(mat);obj['level']=row['level'];objects.append(obj)
 mesh.calc_loop_triangles();uv_data=mesh.uv_layers.active.data;collapsed_uv=0
 for triangle in mesh.loop_triangles:
  a,b,c=[uv_data[i].uv for i in triangle.loops]
  area=abs((b.x-a.x)*(c.y-a.y)-(b.y-a.y)*(c.x-a.x))*.5
  if not math.isfinite(area) or area<1e-12:collapsed_uv+=1
 census.append({'id':row['id'],'nonmanifold_edges':bad,'volume':volume,'stations':len(stations),'collapsed_uv_triangles':collapsed_uv})
# Four source-aligned hollow mains. Ports are actually bored into their
# walls; this remains a fabrication candidate until shaft clearance and
# complete branch/main unions are independently inspected.
risers=[]
for riser in sorted({row['riser'] for row in data['branches']}):
 rows=[row for row in data['branches'] if row['riser']==riser]
 first=rows[0]['points_local_godot'][0];top=max(row['points_local_godot'][0][1] for row in rows)+.15
 a,b=cv([first[0],-.45,first[2]]),cv([first[0],top,first[2]])
 record=coupling('Main_'+riser,a,b,'SHAFT',outer=.029,inner=.024)
 obj=bpy.data.objects[record['id']];ports=[]
 for row in rows:
  points=row['points_local_godot'];at=cv(points[0]);direction=(cv(points[1])-at).normalized()
  bpy.ops.mesh.primitive_cylinder_add(vertices=48,radius=.024,depth=.08,location=at+direction*.04)
  cutter=bpy.context.object;cutter.rotation_euler=direction.to_track_quat('Z','Y').to_euler()
  bpy.context.view_layer.objects.active=obj
  modifier=obj.modifiers.new('OpenBranchPort','BOOLEAN');modifier.operation='DIFFERENCE';modifier.solver='EXACT';modifier.object=cutter
  bpy.ops.object.modifier_apply(modifier=modifier.name);bpy.data.objects.remove(cutter,do_unlink=True)
  ports.append({'branch':row['id'],'origin_blender':list(at),'direction_blender':list(direction),'bore_radius_m':.024})
 mesh=obj.data;record['repaired_boolean_charts']=repair_boolean_charts(mesh)
 bm=bmesh.new();bm.from_mesh(mesh);record['nonmanifold_edges']=sum(not edge.is_manifold for edge in bm.edges);record['volume']=bm.calc_volume(signed=True);bm.free()
 record['ports']=ports;risers.append(record)
# Blind end caps close the mains above their last branch. The sleeve overlaps
# the pipe stock; the solid crown begins above its open end, preserving the bore.
main_caps=[]
for record in risers:
 end=Vector(record['end_blender'])
 sleeve=coupling(record['id']+'__CapSleeve',end-Vector((0,0,.02)),end+Vector((0,0,.02)),'SHAFT',outer=.035,inner=.029)
 name=record['id']+'__CapCrown'
 sides=32;verts=[];faces=[];charts=[]
 for z in [.02,.026]:
  for j in range(sides):verts.append(end+Vector((.035*math.cos(j*math.tau/sides),.035*math.sin(j*math.tau/sides),z)))
 for j in range(sides):
  n=(j+1)%sides;faces.append((j,n,n+sides,j+sides))
  charts.append([(j/sides*math.tau*.035,0),((j+1)/sides*math.tau*.035,0),((j+1)/sides*math.tau*.035,.006),(j/sides*math.tau*.035,.006)])
 for face in [tuple(reversed(range(sides))),tuple(range(sides,2*sides))]:
  faces.append(face);charts.append([(verts[i].x-end.x,verts[i].y-end.y) for i in face])
 mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update();uv=mesh.uv_layers.new(name='MetreUV')
 for face,chart in zip(mesh.polygons,charts):
  face.use_smooth=face.index<sides
  for loop,coord in zip(face.loop_indices,chart):uv.data[loop].uv=(coord[0]/spec['meters_per_tile'],coord[1]/spec['meters_per_tile'])
 mesh.materials.append(mat);obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj);obj['level']='SHAFT';objects.append(obj)
 main_caps.append({'riser':record['id'],'sleeve':sleeve['id'],'crown':name,'end_blender':list(end),'underside_offset_m':.02,'top_offset_m':.026})
# Remove branch end rings and sleeve stock from each vertical main lumen.
# Keeping the visible stocks separate preserves their material/part identities.
junction_parts=[]
for record in risers:
 a,b=Vector(record['start_blender']),Vector(record['end_blender'])
 bpy.ops.mesh.primitive_cylinder_add(vertices=32,radius=record['inner_radius_m'],depth=(b-a).length+.02,location=(a+b)/2)
 cutter=bpy.context.object
 for port in record['ports']:
  names=[port['branch'],port['branch']+'__Coupling_00_a']
  for name in names:
   obj=bpy.data.objects.get(name)
   if obj is None:continue
   bpy.context.view_layer.objects.active=obj
   modifier=obj.modifiers.new('ClearMainLumen','BOOLEAN');modifier.operation='DIFFERENCE';modifier.solver='EXACT';modifier.object=cutter
   bpy.ops.object.modifier_apply(modifier=modifier.name)
   repair_boolean_charts(obj.data)
   junction_parts.append(name)
 bpy.data.objects.remove(cutter,do_unlink=True)
# Cast receiver fitted to the authored HEAT_STEAM_RECEIVER_CLEAR volume.
layout=json.loads((ROOT/'game/data/orison_v2_blockout.json').read_text())
receiver=next(r for r in layout['riser_openings'] if r['id']=='HEAT_STEAM_RECEIVER_CLEAR')['bounds']
low,high=Vector(receiver[:3]),Vector(receiver[3:]);center=(low+high)/2;size=high-low
bpy.ops.mesh.primitive_cube_add(size=1,location=cv(center));header=bpy.context.object;header.name='SteamReceiver';header.dimensions=(size.x,size.z,size.y)
bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
def subtract_header(cutter):
 bpy.context.view_layer.objects.active=header
 mod=header.modifiers.new('ReceiverCavity','BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=cutter
 bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(cutter,do_unlink=True)
bpy.ops.mesh.primitive_cube_add(size=1,location=cv(center));cutter=bpy.context.object;cutter.dimensions=(size.x-.012,size.z-.012,size.y-.012)
bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);subtract_header(cutter)
for record in risers:
 at=Vector(record['start_blender']);bpy.ops.mesh.primitive_cylinder_add(vertices=48,radius=.024,depth=.04,location=at);subtract_header(bpy.context.object)
feed=cv([center.x,center.y,low.z]);bpy.ops.mesh.primitive_cylinder_add(vertices=64,radius=.073,depth=.04,location=feed,rotation=(math.pi/2,0,0));subtract_header(bpy.context.object)
bpy.context.view_layer.objects.active=header
bevel=header.modifiers.new('CastEdgeRadii','BEVEL');bevel.width=.0015;bevel.segments=3
bpy.ops.object.modifier_apply(modifier=bevel.name)
mesh=header.data;uv=mesh.uv_layers.active or mesh.uv_layers.new(name='MetreUV')
for face in mesh.polygons:
 n=face.normal.normalized();u=n.cross(Vector((0,0,1)) if abs(n.z)<.9 else Vector((0,1,0))).normalized();v=n.cross(u);origin=mesh.vertices[face.vertices[0]].co
 for loop in face.loop_indices:
  delta=mesh.vertices[mesh.loops[loop].vertex_index].co-origin;uv.data[loop].uv=(delta.dot(u)/spec['meters_per_tile'],delta.dot(v)/spec['meters_per_tile'])
mesh.materials.clear();mesh.materials.append(mat)
for face in mesh.polygons:face.material_index=0
header['level']='SHAFT';objects.append(header)
receiver_record={'id':header.name,'source_opening':'HEAT_STEAM_RECEIVER_CLEAR','bounds_local_godot':receiver,'wall_m':.006,'feed_bore_radius_m':.073,'feed_origin_blender':list(feed)}
# Review the actual regenerated boiler feed beside its receiver; production
# assets remain untouched until the composed fabrication is accepted.
feed_source=OUT.parent/'boiler-feed/boiler_pipework.blend'
feed_parts=[]
with bpy.data.libraries.load(str(feed_source),link=False) as (source,target):
 target.objects=source.objects
for obj in target.objects:
 if obj is None or obj.type!='MESH':continue
 bpy.context.collection.objects.link(obj);obj.name='BoilerFeed__'+obj.name
 obj.data.materials.clear();obj.data.materials.append(mat)
 for face in obj.data.polygons:face.material_index=0
 if obj.data.uv_layers.active:
  for loop in obj.data.uv_layers.active.data:loop.uv/=spec['meters_per_tile']
 obj['level']='BOILER';objects.append(obj);feed_parts.append(obj.name)
tailpieces=[]
heating_source=ROOT/'game/data/orison_v2/heating.json'
heating=json.loads(heating_source.read_text())
anchors={row['id']:row for row in layout['anchors']}
level_elevations={row['id']:row['y'] for row in layout['levels']}
for radiator in heating['installed']:
 half=(radiator['sections']-1)*.092*.5
 # The retained union is fixed at x=-.42 for every section count. Shorter
 # castings need a tailpiece; the ten-section casting already meets it.
 end_x=-half+.015
 if end_x-(-.40)<.008:continue
 anchor=anchors[radiator['id']];yaw=anchor.get('yaw',0);origin=anchor['position']
 def local_point(x):
  z=-.055
  return [origin[0]+x*math.cos(yaw)+z*math.sin(yaw),level_elevations[anchor['level']]+origin[1]-.75+.19,origin[2]-x*math.sin(yaw)+z*math.cos(yaw)]
 a,b=cv(local_point(-.40)),cv(local_point(end_x))
 record=coupling(radiator['id']+'__UnionTailpiece',a,b,anchor['level'],outer=.026,inner=.019)
 record['radiator']=radiator['id'];record['sections']=radiator['sections'];tailpieces.append(record)
interface_path=OUT.parent/'heating_interfaces.json'
interfaces=json.loads(interface_path.read_text());floor_sleeves=[]
branch_support_path=OUT.parent/'heating_branch_supports.json'
branch_support_data=json.loads(branch_support_path.read_text())
if branch_support_data['unserved_straights']:raise RuntimeError('Unserved heating branch straights')
branch_supports=[]
for support in branch_support_data['supports']:
 center=cv(support['center']);direction=cv(support['tangent']).normalized();half=support['band_length_m']*.5
 band=coupling(support['id']+'__Band',center-direction*half,center+direction*half,support['level'],outer=support['outer_radius_m'],inner=support['inner_radius_m'])
 parts=[band['id']]
 for role,bottom,top,width in [('Stem',support['stem_bottom_y'],support['stem_top_y'],.008),('Foot',support['stem_top_y']-.004,support['stem_top_y'],.026)]:
  bpy.ops.mesh.primitive_cube_add(size=1,location=Vector((center.x,center.y,(bottom+top)*.5)))
  obj=bpy.context.object;obj.name=support['id']+'__'+role;obj.dimensions=(width,width,top-bottom)
  bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
  bevel=obj.modifiers.new('EasedSteelEdges','BEVEL');bevel.width=.0004;bevel.segments=2
  bpy.ops.object.modifier_apply(modifier=bevel.name)
  mesh=obj.data;mesh.materials.clear();mesh.materials.append(mat)
  for face in mesh.polygons:face.material_index=0
  for loop in mesh.uv_layers.active.data:loop.uv=(0,0)
  repair_boolean_charts(mesh)
  obj['level']=support['level'];objects.append(obj);parts.append(obj.name)
 branch_supports.append(dict(support,parts=parts))
main_supports=[]
for support in interfaces['main_supports']:
 center=cv(support['center']);half=support['height_m']*.5
 band=coupling(support['id']+'__Band',center-Vector((0,0,half)),center+Vector((0,0,half)),'SHAFT',outer=support['outer_radius_m'],inner=support['inner_radius_m'])
 parts=[band['id']]
 for sign in [-1,1]:
  # Welded lugs overlap the band wall and embed beyond the shaft bore.
  inner=.033;outer=support['lug_reach_m']
  bpy.ops.mesh.primitive_cube_add(size=1,location=center+Vector((sign*(inner+outer)*.5,0,0)))
  obj=bpy.context.object;obj.name=support['id']+('__LugLeft' if sign<0 else '__LugRight')
  obj.dimensions=(outer-inner,2*support['lug_half_depth_m'],2*support['lug_half_height_m'])
  bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
  bevel=obj.modifiers.new('EasedSteelEdges','BEVEL');bevel.width=.0006;bevel.segments=2
  bpy.ops.object.modifier_apply(modifier=bevel.name)
  mesh=obj.data;mesh.materials.clear();mesh.materials.append(mat)
  for face in mesh.polygons:face.material_index=0
  # A zeroed chart requests metric planar charts for each new steel face.
  for loop in mesh.uv_layers.active.data:loop.uv=(0,0)
  repair_boolean_charts(mesh)
  obj['level']='SHAFT';objects.append(obj);parts.append(obj.name)
 main_supports.append(dict(support,parts=parts))
for sleeve in interfaces['floor_sleeves']:
 x,y,z=sleeve['center'];parts=[]
 for role,outer,low,high in [('FloorPlate',sleeve['plate_outer_radius_m'],sleeve['plate_bottom_m'],sleeve['plate_top_m']),('FloorNeck',sleeve['neck_outer_radius_m'],sleeve['neck_bottom_m'],sleeve['neck_top_m'])]:
  record=coupling(sleeve['branch']+'__'+role,cv([x,y+low,z]),cv([x,y+high,z]),sleeve['level'],outer=outer,inner=sleeve['bore_radius_m'])
  parts.append(record)
 floor_sleeves.append(dict(sleeve,parts=parts))
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=32;scene.render.resolution_x=1400;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
scene.world.color=(.25,.25,.25)
bpy.ops.object.camera_add();camera=bpy.context.object;scene.camera=camera;camera.data.type='ORTHO'
bpy.ops.object.light_add(type='AREA',location=(0,0,30));light=bpy.context.object;light.data.energy=5000;light.data.shape='DISK';light.data.size=25
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'heating_distribution_candidate.blend'))
def render(name,center,offset,scale):
 if render_names and name not in render_names:return
 camera.location=Vector(center)+Vector(offset);camera.rotation_euler=(Vector(center)-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.ortho_scale=scale
 light.location=Vector(center)+Vector((2,-2,8));scene.render.filepath=str(OUT/(name+'.png'));bpy.ops.render.render(write_still=True)
for obj in objects:obj.hide_render=obj['level']!='F03'
render('floor03_routes',(0,0,6.3),(0,-.01,40),35)
selected=next(o for o in objects if o.name=='F03_A_RADIATOR_01')
for obj in objects:obj.hide_render=obj!=selected and obj.get('branch','')!=selected.name
row=next(r for r in data['branches'] if r['id']==selected.name);center=cv(row['points_local_godot'][-2]);render('radiator_elbow',center,(.45,-.6,.65),.55)
for obj in objects:obj.hide_render=not (obj.get('level') in ['SHAFT','BOILER','F03'])
shaft_center=cv([8.675,6.27,.525]);render('riser_branch_ports',shaft_center,(.9,-1.1,.8),.65)
render('steam_receiver',cv([8.675,-.55,.525]),(.7,1.1,.6),.7)
render('boiler_receiver_context',cv([10.4,-.9,-.1]),(4,6,3),5.2)
# Read-only section of the authored heat shaft after the proposed cuts.
shaft_context=[]
section_mat=bpy.data.materials.new('ReadOnlyShaftSection');section_mat.use_nodes=True
section_mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.19,.15,.10,1)
section_mat.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.85
for bounds in interfaces['shaft_review_pieces']:
 lo=list(bounds[:3]);hi=list(bounds[3:]);lo[1]=max(lo[1],6.15);hi[1]=min(hi[1],6.42)
 if any(hi[i]<=lo[i] for i in range(3)):continue
 center=[(a+b)/2 for a,b in zip(lo,hi)];size=[b-a for a,b in zip(lo,hi)]
 bpy.ops.mesh.primitive_cube_add(size=1,location=cv(center));context=bpy.context.object;context.dimensions=(size[0],size[2],size[1]);context.data.materials.clear();context.data.materials.append(section_mat)
 for face in context.data.polygons:face.material_index=0
 shaft_context.append(context)
render('shaft_branch_context',cv([8.675,6.27,.525]),(.9,-1.1,.9),.8)
for context in shaft_context:bpy.data.objects.remove(context,do_unlink=True)
# Review an actual pitched branch and its floor hanger.
hanger=branch_supports[0]
for obj in objects:obj.hide_render=obj.name not in hanger['parts'] and obj.name!=hanger['branch']
render('branch_hanger',cv(hanger['center']),(.2,-.3,.15),.22)
# Render the band and embedded lugs without the opaque shaft covering them.
support=main_supports[0]
for obj in objects:obj.hide_render=obj.name not in support['parts'] and obj.name!='Main_'+support['riser']
render('main_support',cv(support['center']),(.22,-.3,.2),.22)
# Review one complete capped main end at player-detail scale.
cap=main_caps[-1]
for obj in objects:obj.hide_render=obj.name not in [cap['riser'],cap['sleeve'],cap['crown']]
render('main_end_cap',Vector(cap['end_blender']),(.2,-.3,.2),.16)
# Temporary section context is not saved or exported as a game asset.
for obj in objects:obj.hide_render=obj.name!=selected.name and obj.get('branch','')!=selected.name
floor_row=next(r for r in data['branches'] if r['id']==selected.name);floor_at=cv(floor_row['points_local_godot'][-1])
context_mat=bpy.data.materials.new('ReadOnlyFloorSection');context_mat.diffuse_color=(.16,.13,.10,1)
for lo_x,lo_y,hi_x,hi_y in [(-.3,-.3,-.034,.3),(.034,-.3,.3,.3),(-.034,-.3,.034,-.034),(-.034,.034,.034,.3)]:
 bpy.ops.mesh.primitive_cube_add(size=1,location=floor_at+Vector(((lo_x+hi_x)/2,(lo_y+hi_y)/2,-.1)))
 context=bpy.context.object;context.dimensions=(hi_x-lo_x,hi_y-lo_y,.2);context.data.materials.clear();context.data.materials.append(context_mat)
 for face in context.data.polygons:face.material_index=0
render('radiator_floor_sleeve',floor_at,(.4,-.6,.5),.32)
(OUT/'native_review.json').write_text(json.dumps({'evidence_class':'INERT','scope':'Candidate hollow pipes and annular couplings. Hollow risers have bored branch ports; complete junction unions, shaft bores, supports, penetrations, self-intersection and runtime acceptance remain unverified.','routes_sha256':hashlib.sha256(route_path.read_bytes().replace(b'\r\n',b'\n')).hexdigest(),'census':census,'couplings':joinery,'risers':risers,'main_caps':main_caps,'main_supports':main_supports,'branch_supports':branch_supports,'radiator_tailpieces':tailpieces,'heating_source_sha256':hashlib.sha256(heating_source.read_bytes().replace(b'\r\n',b'\n')).hexdigest(),'branch_supports_sha256':hashlib.sha256(branch_support_path.read_bytes().replace(b'\r\n',b'\n')).hexdigest(),'junction_parts':junction_parts,'receiver':receiver_record,'floor_sleeves':floor_sleeves,'interfaces_sha256':hashlib.sha256(interface_path.read_bytes().replace(b'\r\n',b'\n')).hexdigest(),'boiler_feed_parts':feed_parts,'boiler_feed_source_sha256':hashlib.sha256(feed_source.read_bytes()).hexdigest(),'rejected':rejected},indent=2)+'\n')
print('HEATING NATIVE REVIEW',len(census),'built;',len(rejected),'rejected')
