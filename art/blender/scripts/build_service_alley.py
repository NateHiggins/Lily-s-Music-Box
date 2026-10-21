"""Rear receiving apron and street-connected alley in the V2 building frame.

Blender axes are converted from Godot metres. The production root registers
this whole assembly with the existing named front-door street connection.
"""
from pathlib import Path
import json
import math
import sys
import bpy
import bmesh
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'tools'))
from plan_v2_retained_grade import subtract as subtract_source_box
catalog=json.loads((ROOT/'game/data/runtime_material_sets.json').read_bytes())['materials']
source = json.loads((ROOT / 'game/data/orison_v2_blockout.json').read_text())
spaces = {r['id']: r for r in source['spaces']}
doors = {r['id']: r for r in source['doors']}
front = doors['F01_DOOR_06']['center'][1]
rear = doors['F01_REAR_SERVICE_DOOR']['center'][1]
core = spaces['F01_SERVICE_CORE']['rect']
east = spaces['F01_D_MAIN']['rect']
apron = spaces['F01_REAR_APRON']['rect']
outer = east[2] + 2.35
back = core[3] + 4.30
wall = .24
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
mats = {}
for role, color in {'Paving': (.34,.33,.30), 'Brick': (.30,.18,.12),
                    'Coping': (.48,.46,.40), 'Iron': (.12,.12,.11)}.items():
    mat = bpy.data.materials.new(role)
    mat.diffuse_color = (*color, 1)
    mats[role] = mat

def box(name, rect, low, high, role, bevel=0):
    x0,z0,x1,z1 = rect
    bpy.ops.mesh.primitive_cube_add(size=1, location=((x0+x1)/2,-(z0+z1)/2,(low+high)/2))
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = (x1-x0,z1-z0,high-low)
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    obj.data.materials.append(mats[role])
    if bevel:
        mod = obj.modifiers.new('Worked edge', 'BEVEL')
        mod.width=bevel; mod.segments=2
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return obj

# Disjoint paving fields follow the stepped ground-floor perimeter. The old
# review apron is excluded only in production, so it cannot overlap the stair.
fields = [(east[2]+.07, front, outer, east[3]+.07),
          (core[2]+.07, east[3]+.07, outer, core[3]+.07),
          (apron[0], core[3]+.07, outer, back),
          (apron[0], rear, core[0]-.07, core[3]+.07)]
for index, rect in enumerate(fields):
    # Individual slabs with a 3 mm recessed joint over continuous substrate.
    box('PavingFoundation',rect,-.30,-.04,'Paving')
    x0,z0,x1,z1=rect
    nx=math.ceil((x1-x0)/1.20); nz=math.ceil((z1-z0)/1.20)
    for ix in range(nx):
        for iz in range(nz):
            a=x0+(x1-x0)*ix/nx; b=x0+(x1-x0)*(ix+1)/nx
            c=z0+(z1-z0)*iz/nz; d=z0+(z1-z0)*(iz+1)/nz
            box('PavingSlab',(a+.0015,c+.0015,b-.0015,d-.0015),-.04,0,'Paving',.001)

# Boundary walls seat below paving, with short buttresses and jointed caps.
# The street mouth stays fully open. The west rear return meets the door wall.
walls=[(outer,front,outer+wall,back+wall),
       (apron[0]-wall,back,outer,back+wall),
       (apron[0]-wall,rear,apron[0],back)]
for index, rect in enumerate(walls):
    box('BoundaryMasonry',rect,-.30,2.35,'Brick')
    x0,z0,x1,z1=rect
    along_z=(z1-z0)>(x1-x0)
    length=(z1-z0) if along_z else (x1-x0)
    count=math.ceil(length/1.0)
    for n in range(count):
        a=n*length/count; b=(n+1)*length/count
        cap=(x0-.035,z0+a+.002,x1+.035,z0+b-.002) if along_z else (x0+a+.002,z0-.035,x0+b-.002,z1+.035)
        box('StoneCoping',cap,2.35,2.44,'Coping',.009)
    for n in range(math.ceil(length/3.0)+1):
        t=min(length-.12,max(.12,n*3.0))
        pier=(x0-.08,z0+t-.18,x1+.08,z0+t+.18) if along_z else (x0+t-.18,z0-.08,x0+t+.18,z1+.08)
        box('BondedPier',pier,-.1,2.35,'Brick',.005)

# Drain gratings beside the travel line. Slots expose a recessed iron bed;
# their tops sit flush with paving and match the exported collision triangles.
for z in [front+1.2,2.0,back-.65]:
    x=outer-.25
    cutter=box('DrainPocketCutter',(x-.151,z-.258,x+.151,z+.258),-.025,.02,'Iron')
    for slab in [o for o in bpy.context.scene.objects if o.name.startswith('PavingSlab')]:
        bounds=[slab.matrix_world@Vector(c) for c in slab.bound_box]
        if max(v.x for v in bounds)<x-.151 or min(v.x for v in bounds)>x+.151:continue
        if max(v.y for v in bounds)<-z-.258 or min(v.y for v in bounds)>-z+.258:continue
        mod=slab.modifiers.new('Recessed drain pocket','BOOLEAN');mod.operation='DIFFERENCE';mod.object=cutter
        bpy.context.view_layer.objects.active=slab;bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.data.objects.remove(cutter,do_unlink=True)
    box('DrainRecess',(x-.15,z-.25,x+.15,z+.25),-.018,-.005,'Iron')
    for i in range(11):
        a=z-.25+i*.05
        box('DrainBar',(x-.15,a-.007,x+.15,a+.007),-.005,.002,'Iron',.001)

# Wall plates and cantilever arms support the retained production cage lamps.
for x,z,side in [(outer-.20,-9,1),(outer-.20,2,1),(outer-.20,12.5,1),(apron[0]+.20,11,-1)]:
    face=outer if side==1 else apron[0]
    box('LampPlate',(face-.015,z-.07,face+.015,z+.07),2.12,2.34,'Iron',.004)
    box('LampArm',(min(x,face),z-.018,max(x,face),z+.018),2.322,2.358,'Iron',.003)
    for y in [2.15,2.31]:
        box('LampBolt',(face-.023,z-.012,face+.023,z+.012),y-.012,y+.012,'Iron',.002)

for obj in list(bpy.context.scene.objects):
    # The stove stack replaces the old rear boundary masonry and paving in
    # this footprint. Cut the actual retained stocks, not just their collision.
    if obj.type=='MESH':
        for shaft in source['risers']:
            if shaft['id']!='C_STOVE_FLUE':continue
            x0,z0,x1,z1=shaft['rect'];points=[obj.matrix_world@Vector(p) for p in obj.bound_box]
            if max(p.x for p in points)<=x0 or min(p.x for p in points)>=x1 or -min(p.y for p in points)<=z0 or -max(p.y for p in points)>=z1:continue
            if obj.name.startswith(('PavingFoundation','BoundaryMasonry')):
                bounds=[min(p.x for p in points),min(p.z for p in points),-max(p.y for p in points),max(p.x for p in points),max(p.z for p in points),-min(p.y for p in points)]
                obj['source_box_components_json']=json.dumps(subtract_source_box(bounds,[x0,float(shaft['from_y']),z0,x1,float(shaft['to_y'])+2.2,z1]))
            cutter=box('StoveStackSourceVoid',(x0,z0,x1,z1),float(shaft['from_y']),float(shaft['to_y'])+2.2,'Brick')
            bpy.context.view_layer.objects.active=obj;mod=obj.modifiers.new('StoveStackReservation','BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=cutter
            bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(cutter,do_unlink=True)
    bpy.context.view_layer.objects.active=obj;bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    bm=bmesh.new();bm.from_mesh(obj.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-6);bmesh.ops.triangulate(bm,faces=list(bm.faces));bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-6)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(obj.data);bm.free();obj.data.update()
    while obj.data.uv_layers:obj.data.uv_layers.remove(obj.data.uv_layers[0])
    uv=obj.data.uv_layers.new(name='Metres');uv.active_render=True
    role=obj.data.materials[0].name;key={'Brick':'brick','Coping':'limestone','Paving':'concrete','Iron':'iron_neutral'}[role];tile=float(catalog[key]['meters_per_tile'])
    for poly in obj.data.polygons:
        n=poly.normal.normalized();seed=Vector((0,0,1)) if abs(n.z)<.9 else Vector((1,0,0));u=n.cross(seed).normalized();v=n.cross(u)
        first=obj.data.vertices[obj.data.loops[poly.loop_indices[0]].vertex_index].co
        origin=[math.fsum(float(first[i])*float(axis[i]) for i in range(3))%tile for axis in [u,v]]
        for loop in poly.loop_indices:
            p=obj.data.vertices[obj.data.loops[loop].vertex_index].co-first;uv.data[loop].uv=(origin[0]+p.dot(u),origin[1]+p.dot(v))
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/service_alley.blend'))
for role,mat in mats.items():
    parts=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.data.materials[0]==mat]
    bpy.ops.object.select_all(action='DESELECT')
    for obj in parts:obj.select_set(True)
    bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join()
    obj=bpy.context.object;obj.name=role
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
bpy.ops.object.select_all(action='SELECT')
class ExportUVHandedness:
    def gather_attribute_change(self,attribute,data,normalized,export_settings):
        if attribute=='TANGENT':data['data'][:,3]*=-1
import io_scene_gltf2
io_scene_gltf2.glTF2ExportUserExtension=ExportUVHandedness
bpy.ops.export_scene.gltf(filepath=str(ROOT/'game/assets/props/service_alley.glb'),export_format='GLB',export_yup=True,export_apply=True,export_tangents=True)
