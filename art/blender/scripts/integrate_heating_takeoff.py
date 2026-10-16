"""Fit the checked lobby takeoff into a copy of the installed native assembly.

Candidate only; never replaces production assets, layout or heating authority.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys
import bpy
import bmesh
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'tools'))
from build_v2_heating_branch_supports import build as supports_for
from plan_v2_heating_distribution import segment_distance

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--plan',type=Path,required=True)
parser.add_argument('--out',type=Path,required=True)
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:])
out=args.out.resolve();out.mkdir(parents=True,exist_ok=True)
plan=json.loads(args.plan.read_text())
prototype=ROOT/'art/blender/heating_takeoff_candidate.blend'
prototype_report=json.loads((ROOT/'art/renders/orison_v2/heating_takeoff_candidate_20261016/native_review.json').read_text())
baseline=ROOT/plan['baseline_native']
base_inspection=json.loads((ROOT/'art/blender/heating_distribution/base18_mesh_inspection.json').read_text())
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
if prototype_report['failures'] or sha(prototype)!=prototype_report['native_sha256']:
    raise ValueError('Takeoff native model has no matching inspection')
if (sha(args.plan)!=prototype_report['plan_sha256'] or base_inspection['failures'] or
        sha(baseline)!=base_inspection['blend_sha256'] or sha(baseline)!=plan['baseline_native_sha256']):
    raise ValueError('Source plan or installed native baseline changed')
catalog_path=ROOT/'game/data/runtime_material_sets.json'
if hashlib.sha256(catalog_path.read_bytes().replace(b'\r\n',b'\n')).hexdigest()!=prototype_report['material_catalog_sha256_lf']:
    raise ValueError('Prototype material catalogue changed')
for name,digest in prototype_report['material_bindings'].items():
    if sha(ROOT/'game/assets/building/textures'/name)!=digest:raise ValueError('Prototype map changed: '+name)
for relative,digest in plan['source_sha256_lf'].items():
    if hashlib.sha256((ROOT/relative).read_bytes().replace(b'\r\n',b'\n')).hexdigest()!=digest:
        raise ValueError('Plan dependency changed: '+relative)
bpy.ops.wm.open_mainfile(filepath=str(baseline))
mat=bpy.data.materials['iron_neutral']
spec=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text())['materials']['iron_neutral']
# A raw-copied historical blend can retain paths relative to its former
# scratch directory. Rebuild the same catalogue material from real sources.
mat.use_nodes=True;mat.node_tree.nodes.clear()
bsdf=mat.node_tree.nodes.new('ShaderNodeBsdfPrincipled');output=mat.node_tree.nodes.new('ShaderNodeOutputMaterial')
mat.node_tree.links.new(bsdf.outputs['BSDF'],output.inputs['Surface']);bsdf.inputs['Metallic'].default_value=spec['metallic']
for index,input_name in [(0,'Base Color'),(1,'Roughness'),(2,'Normal')]:
    texture=mat.node_tree.nodes.new('ShaderNodeTexImage')
    texture.image=bpy.data.images.load(str(ROOT/'game/assets/building/textures'/spec['files'][index]),check_existing=False)
    if index:texture.image.colorspace_settings.name='Non-Color'
    if index==2:
        normal=mat.node_tree.nodes.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.25
        mat.node_tree.links.new(texture.outputs['Color'],normal.inputs['Color']);mat.node_tree.links.new(normal.outputs['Normal'],bsdf.inputs[input_name])
    else:mat.node_tree.links.new(texture.outputs['Color'],bsdf.inputs[input_name])
def cv(p):return Vector((p[0],-p[2],p[1]))
center=cv(plan['join_local_godot']);u=cv(plan['main_axis_local_godot']);v=cv(plan['outlet_axis_local_godot']);n=u.cross(v)
frame=Matrix((u,v,n)).transposed().to_4x4();frame.translation=center
parent=bpy.data.objects[plan['parent_branch']]

def finish(mesh):
    bm=bmesh.new();bm.from_mesh(mesh)
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-8)
    bmesh.ops.triangulate(bm,faces=list(bm.faces))
    bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-9)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
    mesh.update();mesh.calc_loop_triangles();uv=mesh.uv_layers.active or mesh.uv_layers.new(name='MetreUV')
    bad=set()
    for tri in mesh.loop_triangles:
        a,b,c=[uv.data[i].uv for i in tri.loops]
        area=abs((b.x-a.x)*(c.y-a.y)-(b.y-a.y)*(c.x-a.x))*.5
        expected=tri.area/(spec['meters_per_tile']**2)
        # Boolean caps can inherit almost-collinear cylinder charts that
        # survive native floats but collapse when glTF stores float32 UVs.
        if not math.isfinite(area) or area<max(1e-10,expected*.001):bad.add(tri.polygon_index)
    for face in mesh.polygons:
        if face.index not in bad:continue
        normal=face.normal.normalized();x=normal.cross(Vector((0,0,1)) if abs(normal.z)<.9 else Vector((0,1,0))).normalized();y=normal.cross(x);origin=mesh.vertices[face.vertices[0]].co
        for loop in face.loop_indices:
            delta=mesh.vertices[mesh.loops[loop].vertex_index].co-origin
            uv.data[loop].uv=(delta.dot(x)/spec['meters_per_tile'],delta.dot(y)/spec['meters_per_tile'])

# Cut in the fitting's local frame, preserving the original UVs away from
# newly generated end faces and avoiding large-coordinate Boolean errors.
parent.data.transform(frame.inverted()@parent.matrix_world);parent.matrix_world=Matrix.Identity(4)
bpy.ops.mesh.primitive_cube_add(size=1)
cutter=bpy.context.object;cutter.dimensions=(.09,.16,.16)
bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
bpy.context.view_layer.objects.active=parent
mod=parent.modifiers.new('ActualTakeoffGap','BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=cutter
bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(cutter,do_unlink=True)
finish(parent.data);parent.data.transform(frame);parent.data.update()

with bpy.data.libraries.load(str(prototype),link=False) as (source,target):
    target.objects=['SocketedTee','LobbyBranch']
new=[]
for obj in target.objects:
    bpy.context.collection.objects.link(obj)
    obj.data.transform(frame@obj.matrix_world);obj.matrix_world=Matrix.Identity(4)
    obj.name='LobbySupplyTakeoff' if obj.name.startswith('SocketedTee') else 'F01_LOBBY_RADIATOR_01'
    obj['level']='F01';obj.data.materials.clear();obj.data.materials.append(mat)
    new.append(obj)

def annulus(name,a,b,outer,inner):
    axis=(b-a).normalized();x=axis.cross(Vector((0,0,1)) if abs(axis.z)<.9 else Vector((0,1,0))).normalized();y=axis.cross(x)
    sides=32;vertices=[];faces=[];charts=[];length=(b-a).length
    for radius in (outer,inner):
        for at in (a,b):vertices.extend(at+radius*(x*math.cos(j*math.tau/sides)+y*math.sin(j*math.tau/sides)) for j in range(sides))
    for layer,radius in enumerate((outer,inner)):
        for j in range(sides):
            a0=layer*2*sides+j;b0=layer*2*sides+(j+1)%sides
            faces.append((a0,b0,b0+sides,a0+sides))
            charts.append([(j/sides*math.tau*radius,0),((j+1)/sides*math.tau*radius,0),((j+1)/sides*math.tau*radius,length),(j/sides*math.tau*radius,length)])
    for end in (0,1):
        for j in range(sides):
            a0=end*sides+j;b0=end*sides+(j+1)%sides;face=(a0,a0+2*sides,b0+2*sides,b0)
            faces.append(face);charts.append([((vertices[k]-a).dot(x),(vertices[k]-a).dot(y)) for k in face])
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces);mesh.update();uv=mesh.uv_layers.new(name='MetreUV')
    for face,chart in zip(mesh.polygons,charts):
        face.use_smooth=face.index<2*sides
        for loop,coord in zip(face.loop_indices,chart):uv.data[loop].uv=(coord[0]/spec['meters_per_tile'],coord[1]/spec['meters_per_tile'])
    obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj);mesh.materials.append(mat);obj['level']='F01';new.append(obj);finish(mesh)
    return obj

end=plan['child']['points_local_godot'][-1]
for role,radius,low,high in [('FloorPlate',.052,0,.004),('FloorNeck',.033,-.025,0)]:
    annulus('F01_LOBBY_RADIATOR_01__'+role,cv([end[0],end[1]+low,end[2]]),cv([end[0],end[1]+high,end[2]]),radius,.031)
anchor=plan['anchor_candidate'];yaw=anchor['yaw'];origin=anchor['position']
def tail_point(x):return cv([origin[0]+x*math.cos(yaw)-.055*math.sin(yaw),end[1]+.19,origin[2]-x*math.sin(yaw)-.055*math.cos(yaw)])
annulus('F01_LOBBY_RADIATOR_01__Tailpiece',tail_point(-.4),tail_point(-8*.092*.5+.015),.026,.019)
layout=json.loads((ROOT/'game/data/orison_v2_blockout.json').read_text());routes=json.loads((ROOT/'art/blender/heating_distribution/heating_routes_exact.json').read_text())
routes['branches'].append(plan['child'])
supports=supports_for(layout,routes)
lobby_supports=[s for s in supports['supports'] if s['branch']==anchor['id']]
if any(s['branch']==anchor['id'] for s in supports['unserved_straights']):raise ValueError('Lobby straight has no hanger')
old_supports=json.loads((ROOT/'art/blender/heating_distribution/heating_branch_supports.json').read_text())['supports']
by_id={s['id']:s for s in supports['supports']}
if any(by_id.get(s['id'])!=s for s in old_supports):raise ValueError('New branch requires review of existing hangers')
for support in lobby_supports:
    at=cv(support['center']);axis=cv(support['tangent']);half=support['band_length_m']/2
    annulus(support['id']+'__Band',at-axis*half,at+axis*half,support['outer_radius_m'],support['inner_radius_m'])
    for role,bottom,top,width in [('Stem',support['stem_bottom_y'],support['stem_top_y'],.008),('Foot',support['stem_top_y']-.004,support['stem_top_y'],.026)]:
        bpy.ops.mesh.primitive_cube_add(size=1,location=cv([support['center'][0],(bottom+top)/2,support['center'][2]]))
        obj=bpy.context.object;obj.name=support['id']+'__'+role;obj.dimensions=(width,width,top-bottom)
        bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
        obj['level']='F01';obj.data.materials.clear();obj.data.materials.append(mat)
        for loop in obj.data.uv_layers.active.data:loop.uv=(0,0)
        finish(obj.data);new.append(obj)

failures=[];checks=[]
for obj in [parent]+new:finish(obj.data)
for obj in [o for o in bpy.context.scene.objects if o.type=='MESH']:
    bm=bmesh.new();bm.from_mesh(obj.data)
    bad=sum(not edge.is_manifold for edge in bm.edges);volume=bm.calc_volume(signed=True);bm.free()
    obj.data.calc_loop_triangles();uv=obj.data.uv_layers.active.data;collapsed=0
    for tri in obj.data.loop_triangles:
        a,b,c=[uv[i].uv for i in tri.loops];area=abs((b.x-a.x)*(c.y-a.y)-(b.y-a.y)*(c.x-a.x))*.5
        if not math.isfinite(area) or area<1e-12:collapsed+=1
    checks.append({'id':obj.name,'nonmanifold_edges':bad,'signed_volume_m3':volume,'collapsed_uv_triangles':collapsed})
    if bad or volume<=0 or not math.isfinite(volume) or collapsed:failures.append(checks[-1])
trees=[BVHTree.FromPolygons([p.co for p in obj.data.vertices],[p.vertices[:] for p in obj.data.polygons]) for obj in [parent]+new[:2]]
probes=0
for axis,start,length in [(u,center-u*.3,.6),(v,center+v*.005,.34)]:
    x=axis.cross(v if axis==u else u).normalized();y=axis.cross(x)
    for dx,dy in [(0,0),(.018,0),(-.018,0),(0,.018),(0,-.018)]:
        probes+=1
        if any(tree.ray_cast(start+x*dx+y*dy,axis,length)[0] is not None for tree in trees):failures.append({'kind':'assembled_lumen_blocked','axis':list(axis),'offset':[dx,dy]})
bpy.context.preferences.filepaths.save_version=0
native=out/'heating_distribution_candidate.blend';bpy.ops.wm.save_as_mainfile(filepath=str(native))
report={'evidence_class':'INERT','scope':'Full native takeoff assembly candidate; no production replacement, world activation or runtime proof.',
        'baseline_sha256':sha(baseline),'prototype_sha256':sha(prototype),'plan_sha256':sha(args.plan),
        'recipe_sha256_lf':hashlib.sha256(Path(__file__).read_bytes().replace(b'\r\n',b'\n')).hexdigest(),
        'native_sha256':sha(native),'blend_sha256':sha(native),'changed_parent':parent.name,'new_parts':[o.name for o in new],
        'new_hangers':lobby_supports,'retained_hangers':len(old_supports),'checks':checks,'assembled_lumen_probes':probes,'failures':failures}
(out/'assembly_review.json').write_text(json.dumps(report,indent=2)+'\n')
(out/'mesh_inspection.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({'new_parts':len(new),'hangers':len(lobby_supports),'probes':probes,'failures':len(failures)}))
if failures:raise RuntimeError('Assembled takeoff inspection failed')
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=32
scene.render.resolution_x=1200;scene.render.resolution_y=850;scene.render.resolution_percentage=100
for obj in scene.objects:
    if obj.type!='MESH':continue
    bounds_center=sum((obj.matrix_world@Vector(p) for p in obj.bound_box),Vector())/8
    nearby_old_hanger=obj.name.startswith(plan['parent_branch']+'_HANGER_') and (bounds_center-center).length<3
    obj.hide_render=obj not in [parent]+new and not nearby_old_hanger
camera=scene.camera
if camera is None:
    camera=bpy.data.objects.new('TakeoffCamera',bpy.data.cameras.new('TakeoffCamera'));scene.collection.objects.link(camera);scene.camera=camera
camera.data.type='ORTHO'
for obj in list(scene.objects):
    if obj.type=='LIGHT':bpy.data.objects.remove(obj,do_unlink=True)
for name,offset,power,size in [('TakeoffKey',(1,-2,2),450,1.5),('TakeoffFill',(-1,.5,1),220,1)]:
    light=bpy.data.objects.new(name,bpy.data.lights.new(name,'AREA'));scene.collection.objects.link(light)
    light.location=center+Vector(offset);light.data.energy=power;light.data.size=size
    light.rotation_euler=(center-light.location).to_track_quat('-Z','Y').to_euler()
overview=(center+cv(end))/2
renders=[]
for name,target,offset,scale in [('assembled_takeoff',center,frame.to_3x3()@Vector((.4,-.6,.4)),.65),
                                ('lobby_branch_supports',overview,Vector((1.2,1.5,-1)),2.7)]:
    camera.location=target+offset;camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.ortho_scale=scale
    path=out/(name+'.png');scene.render.filepath=str(path);bpy.ops.render.render(write_still=True)
    renders.append({'file':path.name,'sha256':sha(path)})
report['renders']=renders
(out/'assembly_review.json').write_text(json.dumps(report,indent=2)+'\n')
