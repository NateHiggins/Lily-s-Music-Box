"""Build and inspect an INERT lobby tee candidate; never writes production assets."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

import bpy
import bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'tools'))
from heating_pipe_fittings import fitted_stations

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--plan',type=Path,required=True)
parser.add_argument('--out',type=Path,required=True)
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:])
plan=json.loads(args.plan.read_text());out=args.out.resolve();out.mkdir(parents=True,exist_ok=True)
socket=plan['socket']
for relative,digest in plan['source_sha256_lf'].items():
    if hashlib.sha256((ROOT/relative).read_bytes().replace(b'\r\n',b'\n')).hexdigest()!=digest:
        raise ValueError('Takeoff plan source changed: '+relative)
bpy.ops.wm.read_factory_settings(use_empty=True)
catalog_path=ROOT/'game/data/runtime_material_sets.json'
catalog_bytes=catalog_path.read_bytes()
spec=json.loads(catalog_bytes)['materials']['iron_neutral']
material_bindings={name:hashlib.sha256((ROOT/'game/assets/building/textures'/name).read_bytes()).hexdigest() for name in spec['files']}
mat=bpy.data.materials.new('iron_neutral');mat.use_nodes=True
bsdf=mat.node_tree.nodes['Principled BSDF'];bsdf.inputs['Metallic'].default_value=spec['metallic']
for i,input_name in [(0,'Base Color'),(1,'Roughness'),(2,'Normal')]:
    tex=mat.node_tree.nodes.new('ShaderNodeTexImage')
    tex.image=bpy.data.images.load(str(ROOT/'game/assets/building/textures'/spec['files'][i]),check_existing=True)
    if i:tex.image.colorspace_settings.name='Non-Color'
    if i==2:
        normal=mat.node_tree.nodes.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.25
        mat.node_tree.links.new(tex.outputs['Color'],normal.inputs['Color'])
        mat.node_tree.links.new(normal.outputs['Normal'],bsdf.inputs[input_name])
    else:mat.node_tree.links.new(tex.outputs['Color'],bsdf.inputs[input_name])

origin=Vector(plan['join_local_godot'])
source_u=Vector(plan['main_axis_local_godot'])
source_v=Vector(plan['outlet_axis_local_godot'])
source_n=source_u.cross(source_v).normalized()

def dv(p):
    p=Vector(p)
    return Vector((p.dot(source_u),p.dot(source_v),p.dot(source_n)))

def cv(p):return dv(Vector(p)-origin)

def source_point(p):return list(origin+source_u*p.x+source_v*p.y+source_n*p.z)

def stock(name,a,b,radius,sides=64):
    axis=(b-a).normalized();u=axis.cross(Vector((0,0,1)) if abs(axis.z)<.9 else Vector((0,1,0))).normalized();v=axis.cross(u)
    verts=[at+radius*(u*math.cos(j*math.tau/sides)+v*math.sin(j*math.tau/sides)) for at in (a,b) for j in range(sides)]
    faces=[];charts=[];length=(b-a).length
    for j in range(sides):
        k=(j+1)%sides;faces.append((j,k,k+sides,j+sides))
        charts.append([(j/sides*math.tau*radius,0),((j+1)/sides*math.tau*radius,0),((j+1)/sides*math.tau*radius,length),(j/sides*math.tau*radius,length)])
    for face in (tuple(reversed(range(sides))),tuple(range(sides,2*sides))):
        faces.append(face);charts.append([((verts[k]-a).dot(u),(verts[k]-a).dot(v)) for k in face])
    return mesh_object(name,verts,faces,charts)

def mesh_object(name,verts,faces,charts):
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
    uv=mesh.uv_layers.new(name='MetreUV')
    for face,chart in zip(mesh.polygons,charts):
        face.use_smooth=len(face.vertices)==4
        for loop,coord in zip(face.loop_indices,chart):uv.data[loop].uv=(coord[0]/spec['meters_per_tile'],coord[1]/spec['meters_per_tile'])
    obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj);mesh.materials.append(mat)
    return obj

stages=[]

def boolean(obj,cutter,operation):
    label=cutter.name
    bpy.context.view_layer.objects.active=obj
    mod=obj.modifiers.new(operation,'BOOLEAN');mod.operation=operation;mod.solver='EXACT';mod.object=cutter
    bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(cutter,do_unlink=True)
    bm=bmesh.new();bm.from_mesh(obj.data)
    tree=BVHTree.FromPolygons([p.co for p in obj.data.vertices],[p.vertices[:] for p in obj.data.polygons])
    hit=tree.ray_cast(Vector((-.3,0,0)),Vector((1,0,0)),.6)
    stages.append({'cut':label,'bad_edges':sum(not e.is_manifold for e in bm.edges),
                   'main_hit':list(hit[0]) if hit[0] is not None else None})
    bm.free()

def tube(name,points):
    frames=[];distance=0;previous=None;u=None;sides=48
    for point,tangent in fitted_stations(points,steps=24):
        at,t=cv(point),dv(tangent).normalized()
        if previous is not None:distance+=(at-previous).length
        u=t.cross(Vector((0,0,1)) if abs(t.z)<.9 else Vector((0,1,0))).normalized() if u is None else (u-t*u.dot(t)).normalized()
        frames.append((at,u.copy(),t.cross(u),distance));previous=at
    verts=[];faces=[];charts=[];n=len(frames);layer=n*sides
    for radius in (socket['pipe_outer_radius_m'],socket['flow_radius_m']):
        for at,u,v,d in frames:
            verts.extend(at+radius*(u*math.cos(j*math.tau/sides)+v*math.sin(j*math.tau/sides)) for j in range(sides))
    for inside,radius in enumerate((socket['pipe_outer_radius_m'],socket['flow_radius_m'])):
        for i in range(n-1):
            for j in range(sides):
                a=inside*layer+i*sides+j;b=inside*layer+i*sides+(j+1)%sides
                face=(a,b,b+sides,a+sides)
                chart=[(j/sides*math.tau*radius,frames[i][3]),((j+1)/sides*math.tau*radius,frames[i][3]),((j+1)/sides*math.tau*radius,frames[i+1][3]),(j/sides*math.tau*radius,frames[i+1][3])]
                faces.append(tuple(reversed(face)) if inside else face);charts.append(list(reversed(chart)) if inside else chart)
    for end in (0,n-1):
        at,u,v,_=frames[end]
        for j in range(sides):
            a=end*sides+j;b=end*sides+(j+1)%sides;face=(a,a+layer,b+layer,b)
            faces.append(face);charts.append([((verts[k]-at).dot(u),(verts[k]-at).dot(v)) for k in face])
    return mesh_object(name,verts,faces,charts)

c=Vector((0,0,0));u=Vector((1,0,0));v=Vector((0,1,0))
half=socket['main_half_length_m'];cut=socket['parent_cut_offset_m'];insert=socket['branch_insert_start_m']
tee=stock('SocketedTee',c-u*half,c+u*half,socket['outer_radius_m'])
# Contain each closed operand cap strictly inside the receiving stock/void.
# Equal-radius perpendicular cylinders otherwise meet at zero-area tangencies.
# Main relief enlarges the internal flow; every attached pipe retains 24 mm.
boolean(tee,stock('BranchStock',c,c+v*socket['branch_length_m'],socket['branch_outer_radius_m']),'UNION')
boolean(tee,stock('MainLumen',c-u*(half+.05),c+u*(half+.05),
                  socket['flow_radius_m']+socket['main_flow_relief_m']),'DIFFERENCE')
boolean(tee,stock('BranchLumen',c,c+v*(socket['branch_length_m']+.03),socket['flow_radius_m']),'DIFFERENCE')
for sign in (-1,1):
    boolean(tee,stock('MainSocket',c+u*sign*cut,c+u*sign*(half+.05),socket['receiving_radius_m']),'DIFFERENCE')
boolean(tee,stock('BranchSocket',c+v*insert,c+v*(socket['branch_length_m']+.03),socket['receiving_radius_m']),'DIFFERENCE')
bm=bmesh.new();bm.from_mesh(tee.data)
bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-8)
bmesh.ops.triangulate(bm,faces=list(bm.faces))
bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-9)
bm.to_mesh(tee.data);bm.free()
bevel=tee.modifiers.new('CastEdgeRadius','BEVEL');bevel.width=.0008;bevel.segments=3
bevel.limit_method='ANGLE';bevel.angle_limit=.45
bpy.context.view_layer.objects.active=tee;bpy.ops.object.modifier_apply(modifier=bevel.name)
objects=[tee]
for name in ('ParentUpstream','ParentDownstream'):
    # Keep a local review length, retaining the exact source axis and insertion.
    pair=[c-u*.28,c-u*cut] if name=='ParentUpstream' else [c+u*cut,c+u*.28]
    objects.append(tube(name,[source_point(p) for p in pair]))
objects.append(tube('LobbyBranch',plan['child']['points_local_godot']))
failures=[];triangles=0;stock_checks=[]
for obj in objects:
    mesh=obj.data;bm=bmesh.new();bm.from_mesh(mesh)
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-8)
    bmesh.ops.triangulate(bm,faces=list(bm.faces))
    bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-9)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bad=sum(not e.is_manifold for e in bm.edges);volume=bm.calc_volume(signed=True);bm.to_mesh(mesh);bm.free()
    if bad or not math.isfinite(volume) or volume<=0:failures.append({'id':obj.name,'kind':'stock','edges':bad,'volume':volume})
    stock_checks.append({'id':obj.name,'nonmanifold_edges':bad,'signed_volume_m3':volume})
    mesh.calc_loop_triangles();uv=mesh.uv_layers.active.data;bad_faces=set()
    for tri in mesh.loop_triangles:
        a,b,d=[uv[i].uv for i in tri.loops]
        area=abs((b.x-a.x)*(d.y-a.y)-(b.y-a.y)*(d.x-a.x))*.5
        if not math.isfinite(area) or area<1e-12:bad_faces.add(tri.polygon_index)
    for face in mesh.polygons:
        if face.index in bad_faces:
            normal=face.normal.normalized();x=normal.cross(Vector((0,0,1)) if abs(normal.z)<.9 else Vector((0,1,0))).normalized();y=normal.cross(x);face_origin=mesh.vertices[face.vertices[0]].co
            for loop in face.loop_indices:
                p=mesh.vertices[mesh.loops[loop].vertex_index].co-face_origin;uv[loop].uv=(p.dot(x)/spec['meters_per_tile'],p.dot(y)/spec['meters_per_tile'])
    mesh.calc_loop_triangles();triangles+=len(mesh.loop_triangles)
    for tri in mesh.loop_triangles:
        a,b,d=[uv[i].uv for i in tri.loops]
        area=abs((b.x-a.x)*(d.y-a.y)-(b.y-a.y)*(d.x-a.x))*.5
        if not math.isfinite(area) or area<1e-12:failures.append({'id':obj.name,'kind':'uv','triangle':tri.index})
trees=[BVHTree.FromPolygons([p.co for p in obj.data.vertices],[p.vertices[:] for p in obj.data.polygons]) for obj in objects]
probes=0
for axis,length in ((u,.56),(v,.34)):
    x=axis.cross(u if axis==v else v).normalized();y=axis.cross(x)
    for dx,dy in [(0,0),(.018,0),(-.018,0),(0,.018),(0,-.018)]:
        start=c-u*.28 if axis==u else c+v*.005
        start+=x*dx+y*dy;probes+=1
        if any(t.ray_cast(start,axis,length)[0] is not None for t in trees):failures.append({'kind':'blocked_assembled_lumen','axis':list(axis),'offset':[dx,dy]})
tee_tree=trees[0]
for name,at,axis,radius in [('upstream_socket',c-u*((cut+half)/2),u,socket['receiving_radius_m']),
                          ('downstream_socket',c+u*((cut+half)/2),u,socket['receiving_radius_m']),
                          ('branch_socket',c+v*((insert+socket['branch_length_m'])/2),v,socket['receiving_radius_m']),
                          ('main_relief',c+u*(cut-.005),u,socket['flow_radius_m']+socket['main_flow_relief_m']),
                          ('branch_flow',c+v*(insert-.02),v,socket['flow_radius_m'])]:
    x=axis.cross(v if axis==u else u).normalized();y=axis.cross(x)
    for j in range(8):
        angle=math.tau*(j+.37)/8;direction=x*math.cos(angle)+y*math.sin(angle)
        hit=tee_tree.ray_cast(at,direction,.1);probes+=1
        if hit[0] is None or abs(hit[3]-radius)>.0002:
            failures.append({'kind':'incorrect_socket_or_flow_radius','station':name,'probe':j,'distance_m':hit[3],'expected_m':radius})
if (origin-Vector(plan['join_local_godot'])).length>1e-9:
    failures.append({'kind':'placement_origin_changed'})
end=Vector(plan['child']['points_local_godot'][-1])
world_vertices=[Vector(source_point(p.co)) for p in objects[-1].data.vertices]
end_vertices=[p for p in world_vertices if abs(p.y-end.y)<1e-6]
end_center=sum(end_vertices,Vector())/len(end_vertices) if end_vertices else Vector((1e9,1e9,1e9))
if len(end_vertices)<48 or (end_center-end).length>1e-6:
    failures.append({'kind':'native_end_does_not_reach_source_floor_stub','vertices':len(end_vertices),'center':list(end_center),'expected':list(end)})
if failures:
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(out/'failed_native.blend'))
    (out/'native_review.json').write_text(json.dumps({'evidence_class':'INERT',
        'scope':'Failed native preflight; no renders or acceptance.',
        'stages':stages,'stock_checks':stock_checks,'failures':failures},indent=2)+'\n')
    raise RuntimeError('Native takeoff preflight failed before rendering')
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=32
scene.render.resolution_x=1100;scene.render.resolution_y=850;scene.render.resolution_percentage=100
world=bpy.data.worlds.new('ReviewWorld');world.use_nodes=True;world.node_tree.nodes['Background'].inputs[0].default_value=(.12,.12,.12,1);scene.world=world
for name,offset,power,size in [('Key',(1,-1,1.5),150,1),('Fill',(-.7,.5,.6),90,.7)]:
    data=bpy.data.lights.new(name,'AREA');data.energy=power;data.shape='DISK';data.size=size
    obj=bpy.data.objects.new(name,data);scene.collection.objects.link(obj);obj.location=c+Vector(offset);obj.rotation_euler=(c-obj.location).to_track_quat('-Z','Y').to_euler()
camera=bpy.data.objects.new('Camera',bpy.data.cameras.new('Camera'));scene.collection.objects.link(camera);scene.camera=camera;camera.data.type='ORTHO'
for name,position,target,scale in [('tee_external',c+Vector((.27,-.38,.32)),c,.31),('tee_main_bore',c-u*.42,c+u*.1,.12)]:
    camera.location=position;camera.rotation_euler=(target-position).to_track_quat('-Z','Y').to_euler();camera.data.ortho_scale=scale
    scene.render.filepath=str(out/(name+'.png'));bpy.ops.render.render(write_still=True)
bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(out/'lobby_takeoff_candidate.blend'))
if catalog_path.read_bytes()!=catalog_bytes or any(hashlib.sha256(
    (ROOT/'game/assets/building/textures'/name).read_bytes()).hexdigest()!=digest for name,digest in material_bindings.items()):
    raise RuntimeError('Material source changed during native review')
report={'evidence_class':'INERT','scope':'Local native tee/pipe socket review only; no world installation, supports, export or runtime acceptance.',
        'plan_sha256':hashlib.sha256(args.plan.read_bytes()).hexdigest(),
        'recipe_sha256_lf':hashlib.sha256(Path(__file__).read_bytes().replace(b'\r\n',b'\n')).hexdigest(),
        'native_sha256':hashlib.sha256((out/'lobby_takeoff_candidate.blend').read_bytes()).hexdigest(),
        'placement_godot':{'origin':list(origin),'basis_columns':[list(source_u),list(source_n),list(-source_v)]},
        'placement_end_check':{'vertices':len(end_vertices),'native_end_world':list(end_center),'expected_world':list(end)},
        'material_catalog_sha256_lf':hashlib.sha256(catalog_bytes.replace(b'\r\n',b'\n')).hexdigest(),
        'material_spec':spec,'material_bindings':material_bindings,
        'triangles':triangles,'assembled_lumen_probes':probes,'stock_checks':stock_checks,'stages':stages,'failures':failures}
(out/'native_review.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({'triangles':triangles,'probes':probes,'failures':len(failures)}))
if failures:raise RuntimeError('Native takeoff inspection failed')
