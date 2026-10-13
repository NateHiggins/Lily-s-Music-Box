"""Fabricate a riveted studio-style roof tank on the retained service footings.

The old rectangular fixture records retain identity and service anchors. Native
curved surfaces replace their collision at mount; collector and footings stay.
Owner direction 2026-10-13: classic Warner Bros. tower silhouette, no branding."""
from pathlib import Path
import json, math
import bpy, bmesh
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3]
layout=json.loads((ROOT/'game/data/orison_v2_blockout.json').read_text())
records=[r for r in layout['fixtures'] if r.get('fabrication')=='house_tank']
body=next(r for r in records if r['fabrication_part']=='body')
origin=Vector((body['position'][0],0,body['position'][2]))
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
groups={key:[] for key in ['Timber','Iron','Fasteners','Shell','Structure']}
materials={}
for name,color,metal in [('timber',(.30,.20,.12),0),('cast_iron',(.16,.17,.15),.65),('metal',(.30,.31,.29),.8),('enamel',(.82,.80,.72),0)]:
    mat=bpy.data.materials.new(name); mat.use_nodes=True
    shader=mat.node_tree.nodes['Principled BSDF']; shader.inputs['Base Color'].default_value=(*color,1)
    shader.inputs['Roughness'].default_value=.65; shader.inputs['Metallic'].default_value=metal
    materials[name]=mat

def keep(obj,name,group):
    obj.name=name; groups[group].append(obj)
    obj.data.materials.append(materials[{'Timber':'timber','Iron':'cast_iron','Fasteners':'metal','Shell':'enamel','Structure':'cast_iron'}[group]])
    return obj

def box(name,at,size,group,bevel=0):
    bpy.ops.mesh.primitive_cube_add(size=1,location=(at[0],-at[2],at[1]))
    obj=bpy.context.object; obj.dimensions=(size[0],size[2],size[1])
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        mod=obj.modifiers.new('Fabricated edge','BEVEL'); mod.width=bevel; mod.segments=2
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return keep(obj,name,group)

def cylinder(name,at,radius,depth,normal,vertices=24):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=radius,depth=depth,location=(at.x,-at.z,at.y))
    obj=bpy.context.object; obj.rotation_mode='QUATERNION'
    obj.rotation_quaternion=Vector((0,0,1)).rotation_difference(Vector((normal.x,-normal.z,normal.y)))
    return keep(obj,name,'Fasteners')

for record in records:
    role=record['fabrication_part']; at=Vector(record['position'])-origin; size=Vector(record['size'])
    if role in ['body','lid','binding']:
        continue  # Replaced below by the round native vessel and its seams.
    elif role=='support':
        box('SupportColumn',at,size,'Iron',.005)
        # Recessed seam plates and visible rivets on the two exposed faces.
        for normal in [Vector((1,0,0)),Vector((0,0,1))]:
            for fraction in [-.38,.38]:
                point=at+Vector((0,size.y*fraction,0))+normal*(size.x*.5+.004)
                cylinder('ColumnRivet',point,.012,.008,normal)
    elif role=='collector_floor':
        box('CollectorFloor',at,size,'Timber',.002)
    elif role=='collector_wall':
        # X cheeks own all four corners; Z ends terminate at their inner faces.
        along_x=size.x>size.z
        collector=[r for r in records if r['fabrication_part']=='collector_floor'][0]
        collector_at=Vector(collector['position'])-origin
        wall=min(size.x,size.z)
        span=(size.x-2*wall) if along_x else size.z
        count=math.ceil(span/.16); pitch=span/count
        for i in range(count):
            offset=-span*.5+(i+.5)*pitch
            plank_at=at+Vector((offset if along_x else 0,-.015,0 if along_x else offset))
            plank_size=(pitch-.002,size.y-.03,wall) if along_x else (wall,size.y-.03,pitch-.002)
            box('CollectorStave',plank_at,plank_size,'Timber',.0006)
        cap_span=span-.006 if along_x else span+.006
        cap_size=(cap_span,.03,wall+.006) if along_x else (wall+.006,.03,cap_span)
        box('CollectorRim',at+Vector((0,size.y*.5-.015,0)),cap_size,'Iron',.001)
        normal=Vector((0,0,1 if at.z>collector_at.z else -1)) if along_x else Vector((1 if at.x>collector_at.x else -1,0,0))
        strap_span=size.x if along_x else size.z+.012
        strap_size=(strap_span,.05,.006) if along_x else (.006,.05,strap_span)
        strap_at=at+Vector((0,-size.y*.5+.14,0))+normal*(wall*.5+.003)
        box('CollectorBinding',strap_at,strap_size,'Iron',.001)
        along=Vector((1,0,0)) if along_x else Vector((0,0,1))
        for hand in [-1,1]:
            cylinder('CollectorRivet',strap_at+along*(span*.3*hand)+normal*.005,.008,.004,normal)


def rod(name,a,b,width,group='Structure'):
    a,b=Vector(a),Vector(b)
    obj=box(name,(a+b)*.5,(width,(b-a).length,width),group,.001)
    direction=b-a
    obj.rotation_mode='QUATERNION'
    obj.rotation_quaternion=Vector((0,0,1)).rotation_difference(Vector((direction.x,-direction.z,direction.y)))
    return obj

def lathe(name,profile,group='Shell',segments=128,gap=False):
    # Profile is (radius, roof-relative height). Open ends connect to adjacent
    # plates. The small central opening mates to the retained fire standpipe.
    if group=='Structure':profile=profile+[profile[0]]
    verts=[];faces=[];arc=[0.]
    for i,(r,y) in enumerate(profile):
        if i: arc.append(arc[-1]+math.dist(profile[i-1],profile[i]))
        for j in range(segments+1):
            t=j*math.tau/segments
            verts.append((r*math.cos(t),-r*math.sin(t),y))
    for i in range(len(profile)-1):
        for j in range(segments):
            if gap and abs((j+.5)/segments*360-270)<10:continue
            a=i*(segments+1)+j
            faces.append((a,a+1,a+segments+2,a+segments+1))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
    obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj)
    uv=mesh.uv_layers.new(name='Metres')
    for poly in mesh.polygons:
        poly.use_smooth=True
        for li in poly.loop_indices:
            vi=mesh.loops[li].vertex_index;i,j=divmod(vi,segments+1)
            uv.data[li].uv=(j/segments*math.tau*max(profile[i][0],.0565),arc[i])
    return keep(obj,name,group)

# Rounded dish carries the vessel above the trestle and converges on the
# original 113 mm fire-feed bore at y=1.60. Tank diameter remains 2.20 m.
lathe('DishedTank',[(.0565,1.60),(.22,1.63),(.48,1.76),(.74,1.99),(.95,2.27),(1.10,2.55),(1.10,3.90),
    (1.088,3.90),(1.088,2.555),(.940,2.277),(.731,1.999),(.474,1.771),(.218,1.642),(.0565,1.612),(.0565,1.60)])
# Closed sheet with a returned eave and an actual inner cone. The underside
# has downward normals; do not hide missing geometry with double-sided paint.
lathe('ConicalCap',[(1.14,3.90),(1.14,3.94),(.055,4.50),(.055,4.56),(.025,4.56),
    (.025,4.548),(.043,4.548),(.043,4.493),(1.128,3.933),(1.128,3.912),(1.10,3.912),(1.10,3.90),(1.14,3.90)],'Shell')
lathe('CrownVent',[(.025,4.56),(.025,4.63),(.09,4.63),(.09,4.64),(.025,4.70),(.001,4.70),(.001,4.56),(.025,4.56)],'Shell',64)
# Raised lap seams and individually modeled rivet heads catch grazing light.
for y in [2.56,3.23,3.88]:
    lathe('RivetedCourse',[(1.101,y-.020),(1.108,y-.016),(1.108,y+.016),(1.101,y+.020)])
    for i in range(64):
        angle=math.tau*i/64;n=Vector((math.cos(angle),0,math.sin(angle)))
        obj=cylinder('PlateRivet',n*1.112+Vector((0,y,0)),.007,.008,n,8)
        groups['Fasteners'].remove(obj);groups['Shell'].append(obj);obj.data.materials.clear();obj.data.materials.append(materials['enamel'])
# Keep the original posts and weather boots unchanged. Upper uprights, ring
# bearers and low diagonal ties clear the suspended dished bottom.
corners=[Vector((x,0,z)) for x,z in [(-1.05,-.75),(1.05,-.75),(1.05,.75),(-1.05,.75)]]
for i,a in enumerate(corners):
    b=corners[(i+1)%4]
    rod('UpperPost',a+Vector((0,1.60,0)),a+Vector((0,2.52,0)),.14)
    for y in [.42,1.48]:
        rod('RingBearer',a+Vector((0,y,0)),b+Vector((0,y,0)),.065)
    for low,high in [(.44,1.46)]:
        rod('DiagonalTie',a+Vector((0,low,0)),b+Vector((0,high,0)),.027)
        rod('DiagonalTie',b+Vector((0,low,.035)),a+Vector((0,high,.035)),.027)
    box('BearerGusset',a+Vector((0,2.46,0)),(.23,.22,.035),'Structure',.003)
# Narrow circumferential service walk, folded edge, uprights and handrail.
lathe('Catwalk',[(1.11,2.48),(1.43,2.48),(1.43,2.53),(1.11,2.53)],'Structure')
for y in [2.62,3.04,3.47]:
    lathe('CatwalkRail',[(1.42,y-.012),(1.44,y-.012),(1.44,y+.012),(1.42,y+.012)],'Structure',gap=True)
for i in range(16):
    if i==12:continue
    t=math.tau*i/16;a=Vector((1.43*math.cos(t),0,1.43*math.sin(t)))
    rod('GuardPost',a+Vector((0,2.5,0)),a+Vector((0,3.48,0)),.025)
# A fixed maintenance ladder on the north side leaves the playable south
# ballcock stance and overflow collector clear. No invented climb action.
for x in [-.23,.23]:rod('LadderStringer',(x,.15,-1.51),(x,3.49,-1.51),.036)
for i in range(12):rod('LadderRung',(-.25,.26+i*.27,-1.51),(.25,.26+i*.27,-1.51),.026)
for y in [.55,1.55,2.49]:
    for x in [-.23,.23]:rod('LadderBracket',(x,y,-1.51),(x,y,-.77 if y<2 else -1.10),.025)
# Fixed lower-service mounting plate and two balance pipes meet the dish.
# Existing ballcock remains at (-1, 1.3, 1.15), including overflow and save.
box('ServiceBracket',(-1.05,1.35,1.04),(.13,.34,.035),'Structure',.004)
for y,seat in [(1.645,(-1.05,1.645,.75)),(3.405,(-1.011,3.405,1.011))]:
    band=lathe('ChamberMount',[(.101,y-.013),(.109,y-.013),(.109,y+.013),(.101,y+.013)],'Structure',64)
    band.location.x=-1.14;band.location.y=-1.245
    rod('ChamberStay',seat,(-1.14,y,1.14),.025)
for y,end in [(1.65,(-.14,1.65,0)),(3.40,(-.60,3.40,.60))]:
    a,b=Vector((-1.14,y,1.09)),Vector(end)
    cylinder('BalanceConnection',(a+b)*.5,.026,(b-a).length,(b-a).normalized(),32)
a,b=Vector((-1.34,3.455,1.24)),Vector((-.70,3.455,.65))
cylinder('OverflowTakeoff',(a+b)*.5,.042,(b-a).length,(b-a).normalized(),32)

for obj in list(bpy.context.scene.objects):
    bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if obj.name.startswith(('ConicalCap','DishedTank','CrownVent')):
        bm=bmesh.new();bm.from_mesh(obj.data)
        bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.000001)
        bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
        assert all(e.is_manifold for e in bm.edges),obj.name
        assert bm.calc_volume(signed=True)>0,obj.name
        bm.to_mesh(obj.data);bm.free()
    bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.normals_make_consistent(inside=False);bpy.ops.object.mode_set(mode='OBJECT')
    if obj.data.uv_layers.active and obj.data.uv_layers.active.name=='Metres':continue
    # World-length face charts: stock never stretches to fill a normalized box.
    uv=obj.data.uv_layers.active or obj.data.uv_layers.new(name='Metres')
    uv.name='Metres'
    for poly in obj.data.polygons:
        n=poly.normal;drop=max(range(3),key=lambda i:abs(n[i]));axes=[i for i in range(3) if i!=drop]
        for li in poly.loop_indices:
            v=obj.data.vertices[obj.data.loops[li].vertex_index].co
            uv.data[li].uv=(v[axes[0]],v[axes[1]])
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/house_tank.blend'))
for name,objects in groups.items():
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects: obj.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]; bpy.ops.object.join()
    obj=bpy.context.object; obj.name=name
    assert len(obj.data.uv_layers)==1,(name,[uv.name for uv in obj.data.uv_layers])
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
bpy.ops.export_scene.gltf(filepath=str(ROOT/'game/assets/props/house_tank.glb'),export_format='GLB',export_yup=True,export_apply=True,export_materials='EXPORT')
