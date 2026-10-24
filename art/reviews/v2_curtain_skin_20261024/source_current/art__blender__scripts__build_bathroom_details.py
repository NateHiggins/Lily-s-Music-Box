"""Blender-authored period shower and draped lavatory towel, metres.
Exports editable sources, shared shower/towel GLBs through the existing
bath-details contract. No interactions or gameplay authority live in this file.
"""
import bpy
import bmesh
import numpy as np
import math
import json
import sys
import os
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3]
import sys
sys.path.insert(0, str(Path(__file__).parent))
from repair_surface_uvs import repair_scene
from fabrication_chart_batch import triangle_charts
from check_exported_tangents import validate as validate_tangents
from native_curtain_skin import install_curtain_skin
def p(v): return Vector((v[0],-v[2],v[1]))
def clear():
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def material(name,color,metal=0,rough=.5):
    m=bpy.data.materials.get(name) or bpy.data.materials.new(name);m.use_nodes=True
    s=m.node_tree.nodes.get('Principled BSDF');s.inputs['Base Color'].default_value=(*color,1)
    s.inputs['Metallic'].default_value=metal;s.inputs['Roughness'].default_value=rough
    return m
def group(name,at=(0,0,0)):
    o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o);o.location=p(at);return o
def finish(o,name,mat,parent=None):
    o.name=name;o.data.materials.append(mat)
    if o.type=='MESH':
        for f in o.data.polygons:f.use_smooth=True
    bpy.context.view_layer.update();w=o.matrix_world.copy();o.parent=parent;o.matrix_world=w
    return o
def pipe(name,points,r,mat,parent=None):
    c=bpy.data.curves.new(name,'CURVE');c.dimensions='3D';c.resolution_u=2 if len(points)>16 else 6;c.bevel_depth=r;c.bevel_resolution=1 if r<.003 else 2;c.use_fill_caps=True
    s=c.splines.new('BEZIER');s.bezier_points.add(len(points)-1)
    for b,v in zip(s.bezier_points,points):b.co=p(v);b.handle_left_type=b.handle_right_type='AUTO'
    o=bpy.data.objects.new(name,c);bpy.context.collection.objects.link(o);return finish(o,name,mat,parent)
def cyl(name,at,r,h,mat,axis=(0,1,0),parent=None):
    bpy.ops.mesh.primitive_cylinder_add(vertices=32 if r>=.02 else (16 if r>=.006 else 8),radius=r,depth=h,location=p(at));o=bpy.context.object
    o.rotation_mode='QUATERNION';o.rotation_quaternion=Vector((0,0,1)).rotation_difference(p(axis))
    mod=o.modifiers.new('Soft machined edge','BEVEL');mod.width=min(.0015,r*.20,h*.20);mod.segments=2 if r>=.006 else 1
    return finish(o,name,mat,parent)
def mesh(name,verts,faces,mat,parent=None,solid=0):
    m=bpy.data.meshes.new(name);m.from_pydata([p(v) for v in verts],[],faces);m.update()
    o=bpy.data.objects.new(name,m);bpy.context.collection.objects.link(o);finish(o,name,mat,parent)
    if solid:
        mod=o.modifiers.new('Physical cloth thickness','SOLIDIFY');mod.thickness=solid
    return o
def apply():
    for o in list(bpy.context.scene.objects):
        if o.type not in {'MESH','CURVE'}:continue
        bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o;bpy.ops.object.convert(target='MESH')
        bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.normals_make_consistent(inside=False);bpy.ops.uv.smart_project(island_margin=.01);bpy.ops.object.mode_set(mode='OBJECT')
def save(name, curtain_skin=False):
    repair_scene()
    if curtain_skin: install_curtain_skin()
    bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT/f'{name}.blend'))
    repair_scene()
    bpy.ops.export_scene.gltf(filepath=str(OUTPUT/f'{name}.glb') if REVIEW_ONLY else str(ROOT/f'game/assets/props/{name}.glb'),export_format='GLB',export_yup=True,export_apply=not curtain_skin,export_tangents=True)

REVIEW_ONLY=os.environ.get('BATH_SHOWER_REVIEW')=='1'
OUTPUT=ROOT/'tmp/shower-mount-review' if REVIEW_ONLY else ROOT/'art/blender'
OUTPUT.mkdir(parents=True,exist_ok=True)
clear()
nickel=material('nickel_plated',(.72,.71,.67),.82,.28)
enamel=material('enamel',(.83,.84,.80),0,.3)
duck=material('shower_duck',(.88,.85,.77),0,.85)
rubber=material('rubber_aged',(.026,.026,.022),0,.8)
fixed=group('ShowerCasting')
# Rounded square shell; connected inner floor, cove, rim and outer apron.
rings=[(.034,.018),(.25,.021),(.316,.035),(.335,.098),(.345,.123),(.361,.129),(.377,.116),(.374,.014),(.035,.006)]
verts=[];n=96
for r,y in rings:
    for i in range(n):
        a=math.tau*i/n;c=math.cos(a);s=math.sin(a)
        # The throat is round; the receptor corners have an 8 cm radius.
        power=1 if r<.04 else .25
        verts.append((r*math.copysign(abs(c)**power,c),y,r*math.copysign(abs(s)**power,s)))
faces=[]
for j in range(len(rings)):
    for i in range(n):faces.append((j*n+i,j*n+(i+1)%n,((j+1)%len(rings))*n+(i+1)%n,((j+1)%len(rings))*n+i))
mesh('CovedReceptor',verts,faces,enamel,fixed)
cyl('WasteGrate',(0,.020,0),.033,.005,nickel,parent=fixed)
for x in range(-2,3):
    for z in range(-2,3):
        if x*x+z*z<7:cyl('DrainPerforation',(x*.009,.023,z*.009),.0025,.001,rubber,parent=fixed)
for x,name in [(-.095,'HotValve'),(.095,'ColdValve')]:
    pipe('Inlet',[(x,.98,.36),(x,.98,.286)],.014,nickel,fixed)
    valve=group(name,(x,.98,.335))
    cyl('Spindle',(x,.98,.273),.009,.029,nickel,(0,0,1),valve)
    for axis in [(1,0,0),(0,1,0)]:cyl('CrossHandle',(x,.98,.253),.006,.070,nickel,axis,valve)
    cyl('IndexCap',(x,.98,.246),.010,.005,enamel,(0,0,1),valve)
pipe('Manifold',[(-.095,.98,.31),(0,.98,.31),(.095,.98,.31)],.012,nickel,fixed)
pipe('RiserAndSwanNeck',[(0,.98,.31),(0,1.72,.31),(0,1.90,.30),(0,1.925,.21),(0,1.905,.18),(0,1.88,.18)],.012,nickel,fixed)
for y in [1.18,1.65]:
    cyl('RiserClip',(0,y,.31),.016,.020,nickel,parent=fixed)
# A vertical threaded tail engages the swan-neck end. A shouldered female
# union with wrench flats clamps onto the rose's raised receiving boss.
cyl('RoseThreadedTail',(0,1.879,.18),.0117,.034,nickel,parent=fixed)
cyl('UnionStopShoulder',(0,1.894,.18),.015,.004,nickel,parent=fixed)
cyl('RoseReceivingBoss',(0,1.870,.18),.020,.010,nickel,parent=fixed)
for y in [1.8758,1.8780,1.8802]:
    cyl('TailThreadCrest',(0,y,.18),.0123,.0008,nickel,parent=fixed)
vertices=[];faces=[];segments=24
for y,radius in [(1.881,.0125),(1.881,.019),(1.891,.019),(1.891,.0125)]:
    for i in range(segments):
        angle=math.tau*i/segments
        # Flat hexagonal outer faces around a circular receiving bore.
        r=radius if radius==.0125 else radius*math.cos(math.pi/6)/math.cos((angle+math.pi/6)%(math.pi/3)-math.pi/6)
        vertices.append((r*math.cos(angle),y,.18+r*math.sin(angle)))
for ring in range(4):
    for i in range(segments):faces.append((ring*segments+i,ring*segments+(i+1)%segments,((ring+1)%4)*segments+(i+1)%segments,((ring+1)%4)*segments+i))
union=mesh('HexagonalRoseUnion',vertices,faces,nickel,fixed)
for polygon in union.data.polygons:polygon.use_smooth=False
# Bell-shaped rose and a perforated underside, physically joined to the arm.
bpy.ops.mesh.primitive_cone_add(vertices=64,radius1=.070,radius2=.017,depth=.043,location=p((0,1.851,.18)))
finish(bpy.context.object,'ShowerRose',nickel,fixed)
cyl('RoseFace',(0,1.829,.18),.066,.004,nickel,parent=fixed)
for ring,count in [(1,8),(2,16),(3,24)]:
    for i in range(count):
        a=math.tau*i/count;cyl('RoseJet',(math.cos(a)*ring*.018,1.826,.18+math.sin(a)*ring*.018),.0017,.001,rubber,parent=fixed)
# Exact circular elbows and straight runs. Ring centers use this same path.
R=.06
L=.58*2+.56+math.pi*R
def rail(u):
    distance=u*L
    if distance<.58:return (-.34,.32-distance),(0,-1)
    distance-=.58
    if distance<math.pi*R*.5:
        angle=math.pi+distance/R
        return (-.28+R*math.cos(angle),-.26+R*math.sin(angle)),(-math.sin(angle),math.cos(angle))
    distance-=math.pi*R*.5
    if distance<.56:return (-.28+distance,-.32),(1,0)
    distance-=.56
    if distance<math.pi*R*.5:
        angle=math.pi*1.5+distance/R
        return (.28+R*math.cos(angle),-.26+R*math.sin(angle)),(-math.sin(angle),math.cos(angle))
    distance-=math.pi*R*.5
    return (.34,-.26+distance),(0,1)
# Polyline curve preserves exact circular sample positions without AUTO overshoot.
path=[(-.34,2.02,.355)]+[(rail(i/256)[0][0],2.02,rail(i/256)[0][1]) for i in range(257)]+[(.34,2.02,.355)]
c=bpy.data.curves.new('BearingRail','CURVE');c.dimensions='3D';c.bevel_depth=.009;c.bevel_resolution=3;c.use_fill_caps=True
spline=c.splines.new('POLY');spline.points.add(len(path)-1)
for point,at in zip(spline.points,path):point.co=(*p(at),1)
o=bpy.data.objects.new('RoundedCurtainRod',c);bpy.context.collection.objects.link(o);finish(o,o.name,nickel,fixed)
# The installed room selects one immutable support set. Every plate's back
# is on its declared wall plane, with stems/socket overlaps carrying the load.
for setback in [.36,.38,.40,.43,.44,.48]:
    mounts=group('WallMount%03d'%round(setback*1000))
    for x in [-.34,.34]:
        cyl('RodSocket',(x,2.02,.345),.014,.035,nickel,(0,0,1),mounts)
        pipe('RodWallStem',[(x,2.02,.35),(x,2.02,setback-.006)],.009,nickel,mounts)
        cyl('RodWallFlange',(x,2.02,setback-.005),.027,.010,nickel,(0,0,1),mounts)
        pipe('RodBrace',[(x,2.02,-.20),(x,2.19,setback-.007)],.005,nickel,mounts)
        cyl('BraceSocket',(x,2.19,setback-.016),.009,.025,nickel,(0,0,1),mounts)
        cyl('BraceWallPlate',(x,2.19,setback-.0045),.019,.009,nickel,(0,0,1),mounts)
        for dx in [-.018,.018]:
            cyl('RodPlateScrew',(x+dx,2.02,setback-.011),.003,.003,nickel,(0,0,1),mounts)
    for x in [-.095,.095]:
        pipe('SupplyWallStem',[(x,.98,.352),(x,.98,setback-.006)],.014,nickel,mounts)
        cyl('WallFlange',(x,.98,setback-.006),.027,.012,nickel,(0,0,1),mounts)
    for y in [1.18,1.65]:
        pipe('ClipStandoff',[(0,y,.325),(0,y,setback-.004)],.006,nickel,mounts)
        cyl('ClipWallPlate',(0,y,setback-.004),.021,.008,nickel,(0,0,1),mounts)


def cloth(name,gathered):
    parent=group(name);verts=[];faces=[];nx=144;ny=36
    for j in range(ny+1):
        v=j/ny
        for i in range(nx+1):
            u=i/nx
            if gathered:
                phase=u*math.pi*18+.16*v*math.sin(u*17+.4)
                x=.34+(.018+.022*v)*math.sin(phase)+.004*v*math.sin(u*19+v*4)
                z=.14+.18*u+.006*v*math.sin(u*23)
            else:
                (x,z),tangent=rail(u);normal=(-tangent[1],tangent[0])
                # Ring positions stay fixed. Fold depth/phase becomes less
                # regular down the weight of the cloth, never a tiled fold.
                phase=u*math.tau*18+.24*v*math.sin(u*23+.6)
                wave=(.018+.004*v+.003*v*math.sin(u*17))*math.sin(phase)+.002*v*math.sin(v*7+u*21)
                x+=normal[0]*wave;z+=normal[1]*wave
            # Lift both hems 75 mm: the deepest fold now clears the 129 mm
            # receptor rim by at least 25 mm, including cloth thickness.
            y=1.975-1.815*v+.005*math.sin(u*39)*v
            verts.append((x,y,z))
    for j in range(ny):
        for i in range(nx):
            a=j*(nx+1)+i;faces.append((a,a+1,a+nx+2,a+nx+1))
    # A two-sided cloth skin; the sewn hems/selvedges carry visible thickness.
    # Avoid inward solidify folds on this tightly gathered static textile.
    mesh('RubberizedDuck',verts,faces,duck,parent)
    # Turned hem and selvedges follow the physical folds in both poses.
    # The existing 25 mm receptor clearance stays above the hem thickness.
    for j in [ny]:
        edge=[(x,y+.005,z) for x,y,z in verts[j*(nx+1):(j+1)*(nx+1)]]
        pipe('SewnBottomHem',edge,.00075,duck,parent)
    for i in [0,nx]:
        pipe('SewnSelvedge',[verts[j*(nx+1)+i] for j in range(ny+1)],.0007,duck,parent)
    # Separate eyelets follow the unchanged gathered/drawn top edge.
    for i in range(19):
        u=i/18
        if gathered:x=.34;z=.14+.18*u;tangent=(0,1)
        else:(x,z),tangent=rail(u)
        bpy.ops.mesh.primitive_torus_add(major_radius=.020,minor_radius=.0025,major_segments=20,minor_segments=6,location=p((x,2.0115,z)))
        o=bpy.context.object;o.rotation_mode='QUATERNION'
        o.rotation_quaternion=Vector((0,0,1)).rotation_difference(p((tangent[0],0,tangent[1])))
        finish(o,'CurtainRing',nickel,parent)
        normal=(-tangent[1],tangent[0])
        pipe('CurtainHook',[(x,1.992,z),(x+normal[0]*.003,1.977,z+normal[1]*.003),(x,1.968,z),(x-normal[0]*.003,1.972,z-normal[1]*.003)],.0015,nickel,parent)
        bpy.ops.mesh.primitive_torus_add(major_radius=.0035,minor_radius=.0012,major_segments=12,minor_segments=4,location=p((x,1.9705,z)))
        eye=bpy.context.object;eye.rotation_mode='QUATERNION'
        eye.rotation_quaternion=Vector((0,0,1)).rotation_difference(p((normal[0],0,normal[1])))
        finish(eye,'SewnEyelet',nickel,parent)
    return parent
cloth('CurtainDrawn',False);cloth('CurtainGathered',True)
apply()
# Export only authored metric UV0, with no primitive's unit-square channel.
catalog=json.loads((ROOT/'art/data/runtime_material_sets.json').read_text(encoding='utf-8'))['materials']
for obj in bpy.context.scene.objects:
    if obj.type!='MESH':continue
    bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
    bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
    data=obj.data;bm=bmesh.new();bm.from_mesh(data);bmesh.ops.triangulate(bm,faces=list(bm.faces));bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(data);bm.free();data.calc_loop_triangles()
    points=np.asarray([[data.vertices[i].co[:] for i in tri.vertices] for tri in data.loop_triangles])
    _,_,charts,_=triangle_charts(points,np.zeros(3),catalog[data.materials[0].name]['meters_per_tile'])
    # Periodic chart offsets separate coincident UV islands for MikkTSpace.
    # Integer material repeats preserve the visible texture phase in metres.
    tile=catalog[data.materials[0].name]['meters_per_tile']
    charts[:,:,0]+=(np.arange(len(charts))%3)[:,None]*tile
    charts[:,:,1]+=(np.arange(len(charts))%5)[:,None]*tile
    while data.uv_layers:data.uv_layers.remove(data.uv_layers[0])
    layer=data.uv_layers.new(name='MetricSurface')
    for tri,values in zip(data.loop_triangles,charts):
        for loop,value in zip(tri.loops,values):layer.data[loop].uv=value
    # A few gathered-fold boundary normals cross an opposing face. Repair
    # only triangles with an invalid actual Mikk tangent/bitangent frame.
    changed=set()
    for iteration in range(3):
        data.calc_tangents(uvmap=layer.name);bad=set()
        for tri in data.loop_triangles:
            ids=list(tri.loops);points=np.asarray([data.vertices[i].co[:] for i in tri.vertices]);uv=np.asarray([layer.data[i].uv[:] for i in ids])
            e1=points[1]-points[0];e2=points[2]-points[0];a=uv[1]-uv[0];b=uv[2]-uv[0];det=a[0]*b[1]-a[1]*b[0]
            if abs(det)<=1e-12:bad.add(tri.polygon_index);continue
            du=(e1*b[1]-e2*a[1])/det;dv=(e2*a[0]-e1*b[0])/det
            for i in ids:
                loop=data.loops[i];normal=np.asarray(data.corner_normals[i].vector[:]);tangent=np.asarray(loop.tangent[:]);expected=du-normal*np.dot(du,normal)
                size=np.linalg.norm(expected)
                if np.linalg.norm(tangent)<.999 or size<1e-12 or np.dot(expected/max(size,1e-12),tangent)<=.999 or np.dot(np.cross(normal,tangent),dv)*loop.bitangent_sign<=0:bad.add(tri.polygon_index)
        if not bad:break
        for index in bad:data.polygons[index].use_smooth=False
        changed.update(bad);data.update()
    if changed:print('LOCAL TANGENT NORMAL REPAIR',obj.name,len(changed),'triangles; remaining',len(bad))
# Batch immutable meshes within each moving group by material.
for parent in [o for o in bpy.context.scene.objects if o.type=='EMPTY']:
    for mat in [nickel,enamel,duck,rubber]:
        parts=[o for o in parent.children if o.type=='MESH' and o.data.materials[0]==mat]
        if not parts:continue
        bpy.ops.object.select_all(action='DESELECT')
        for o in parts:o.select_set(True)
        bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join();bpy.context.object.name=parent.name+'_'+mat.name
class ExportUVHandedness:
    def gather_attribute_change(self,attribute,data,normalized,export_settings):
        if attribute=='TANGENT':data['data'][:,3]*=-1
import io_scene_gltf2
io_scene_gltf2.glTF2ExportUserExtension=ExportUVHandedness
save('bath_shower',curtain_skin=True)
print('SHOWER EXPORTED TANGENTS',validate_tangents(OUTPUT/'bath_shower.glb' if REVIEW_ONLY else ROOT/'game/assets/props/bath_shower.glb'))
if REVIEW_ONLY:
    # Native review uses the .40 m mounting set and drawn curtain. Export first.
    for obj in bpy.context.scene.objects:
        if obj.parent and (obj.parent.name.startswith('WallMount') and obj.parent.name!='WallMount400' or obj.parent.name=='CurtainGathered'):obj.hide_render=True
    bpy.ops.mesh.primitive_plane_add(size=5,location=p((0,1.2,.40)))
    wall=bpy.context.object;wall.rotation_euler.x=math.pi/2;wall.data.materials.append(material('Review plaster',(.22,.25,.23)))
    scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24
    scene.world=bpy.data.worlds.new('Shower review');scene.world.color=(.08,.08,.08)
    target=p((.20,2.035,.14))
    bpy.ops.object.light_add(type='AREA',location=p((-.7,2.5,-.7)));light=bpy.context.object;light.data.energy=35;light.data.shape='DISK';light.data.size=1.1;light.rotation_euler=(target-light.location).to_track_quat('-Z','Y').to_euler()
    bpy.ops.object.camera_add(location=p((.9,2.4,-.6)));camera=bpy.context.object;camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.type='ORTHO';camera.data.ortho_scale=1.05;scene.camera=camera
    scene.render.resolution_x=1000;scene.render.resolution_y=800;scene.render.resolution_percentage=100
    scene.render.filepath=str(OUTPUT/'native_mounts.png');bpy.ops.render.render(write_still=True)
    target=p((0,1.883,.18));camera.location=p((.18,1.99,-.08));camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.ortho_scale=.20
    light.data.energy=12
    scene.render.filepath=str(OUTPUT/'native_head_fitting.png');bpy.ops.render.render(write_still=True)
if '--shower-only' in sys.argv or os.environ.get('BATH_SHOWER_ONLY')=='1':
    sys.exit(0)

clear()
linen=material('linen',(.82,.80,.72),0,.9)
# Two sockets under the basin apron carry a rounded rail; nothing straps the base.
for x in [-.12,.12]:
    cyl('UnderApronSocket',(x,.673,-.165),.018,.015,nickel)
    pipe('RailBracket',[(x,.668,-.165),(x,.63,-.18),(x,.63,-.26)],.006,nickel)
pipe('TowelRail',[(-.135,.63,-.26),(0,.63,-.26),(.135,.63,-.26)],.007,nickel)
# Fold back over the rail in a continuous sheet, with rounded fold and soft hem.
verts=[];faces=[];nx=24;ny=32
for j in range(ny+1):
    t=j/ny
    if t<.45:y=.30+.33*t/.45;z=-.272
    elif t<.55:
        a=(t-.45)/.10*math.pi;y=.63+.012*math.sin(a);z=-.26-.012*math.cos(a)
    else:y=.63-.24*(t-.55)/.45;z=-.248
    for i in range(nx+1):
        u=i/nx;fold=math.sin(u*math.tau*4+.3)*.0035
        verts.append(((u-.5)*.215,y+.002*math.sin(u*17),z+fold))
for j in range(ny):
    for i in range(nx):
        a=j*(nx+1)+i;faces.append((a,a+1,a+nx+2,a+nx+1))
mesh('DrapedHandTowel',verts,faces,linen,solid=.001)
apply();save('bath_towel')
# Keep semantic supports and bounds in the existing bath-details contract;
# geometry is shared through one imported model rather than twelve JSON copies.
all_points=[]
for o in bpy.context.scene.objects:
    if o.type=='MESH':
        for vertex in o.data.vertices:
            v=o.matrix_world@vertex.co
            all_points.append([round(v.x,6),round(v.z,6),round(-v.y,6)])
path=ROOT/'game/data/orison_v2/bath_details.json';data=json.loads(path.read_text())
bounds=[[min(v[i] for v in all_points) for i in range(3)],[max(v[i] for v in all_points) for i in range(3)]]
for record in data['props']:
    if record['kind']=='hand_towel':
        record.pop('surfaces',None)
        record['model']='res://assets/props/bath_towel.glb'
        record['bounds']=bounds
path.write_text(json.dumps(data,separators=(',',':'))+'\n',newline='\n')

# Keep the independently authored operable closet as the single geometry source.
import runpy
runpy.run_path(str(ROOT/'art/blender/scripts/build_operable_water_closet.py'))

# The wall-mounted roller has its own source, also callable for this batch.
runpy.run_path(str(ROOT/'art/blender/scripts/build_bath_paper_holder.py'))

source=ROOT/'art/data/orison_v2/domestic_furniture_source.json'
data=json.loads(source.read_text())
for record in data['furniture']:
    if record['kind']=='toilet':
        record.pop('surfaces',None);record['model']='res://assets/props/bath_water_closet.glb'
        record['bounds']=[[-.27,0,-.4],[.27,.96,.36]]
source.write_text(json.dumps(data,separators=(',',':'))+'\n',newline='\n')
