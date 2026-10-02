"""Supported screwed steel lighting conduit in the registered bodega frame."""
from pathlib import Path
import math
import sys
import bpy
import bmesh
from mathutils import Vector

sys.path.insert(0,str(Path(__file__).resolve().parent))
from bodega_services_geometry import ROOT, dimensions

dim=dimensions()
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
materials={}
parts={}
for key,color in {'metal':(.28,.28,.25),'cast_iron':(.12,.12,.10),
                  'brass_dull':(.46,.34,.15)}.items():
    material=bpy.data.materials.new(key)
    material.diffuse_color=(*color,1)
    materials[key]=material

def point(value): return Vector((value[0],-value[2],value[1]))

def finish(obj,name,key):
    obj.name=name
    obj.data.materials.append(materials[key])
    parts.setdefault(key,[]).append(obj)
    return obj

def box(name,at,size,key='metal',bevel=.001):
    bpy.ops.mesh.primitive_cube_add(size=1,location=point(at))
    obj=bpy.context.object
    obj.dimensions=(size[0],size[2],size[1])
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        modifier=obj.modifiers.new('Worked arris','BEVEL')
        modifier.width=bevel
        modifier.segments=1
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    return finish(obj,name,key)

def tube(name,a,b,radius=.009,key='metal',thickness=.0012):
    a,b=point(a),point(b)
    tangent=(b-a).normalized()
    seed=Vector((0,0,1)) if abs(tangent.z)<.9 else Vector((1,0,0))
    u=tangent.cross(seed).normalized()
    v=tangent.cross(u).normalized()
    vertices=[]
    for r in [radius,radius-thickness]:
        for at in [a,b]:
            for i in range(16):
                angle=i*math.tau/16
                vertices.append(at+r*(u*math.cos(angle)+v*math.sin(angle)))
    faces=[]
    for i in range(16):
        j=(i+1)%16
        faces.extend([(i,j,16+j,16+i),(32+i,48+i,48+j,32+j),
                      (i,32+i,32+j,j),(16+i,16+j,48+j,48+i)])
    mesh=bpy.data.meshes.new(name)
    mesh.from_pydata(vertices,[],faces)
    mesh.update()
    obj=bpy.data.objects.new(name,mesh)
    bpy.context.collection.objects.link(obj)
    return finish(obj,name,key)

def pin(name,a,b,radius,key='brass_dull'):
    # Small fasteners are solid, with eight sides; no invisible hollow screws.
    a,b=point(a),point(b)
    direction=(b-a).normalized()
    seed=Vector((0,0,1)) if abs(direction.z)<.9 else Vector((1,0,0))
    u=direction.cross(seed).normalized()
    v=direction.cross(u).normalized()
    vertices=[at+radius*(u*math.cos(i*math.tau/8)+v*math.sin(i*math.tau/8))
        for at in [a,b] for i in range(8)]
    faces=[(i,(i+1)%8,(i+1)%8+8,i+8) for i in range(8)]
    faces.extend([tuple(reversed(range(8))),tuple(range(8,16))])
    mesh=bpy.data.meshes.new(name)
    mesh.from_pydata(vertices,[],faces)
    mesh.update()
    obj=bpy.data.objects.new(name,mesh)
    bpy.context.collection.objects.link(obj)
    return finish(obj,name,key)

def empty(name,at):
    obj=bpy.data.objects.new(name,None)
    bpy.context.collection.objects.link(obj)
    obj.location=point(at)
    obj.empty_display_size=.035
    return obj

def support(at,bearing):
    # Screwed saddle and short stand-off; every bearing is actual fabric.
    at=Vector(at)
    bearing=Vector(bearing)
    delta=bearing-at
    if abs(delta.y)>.02:
        box('CeilingBearing',bearing-Vector((0,.002,0)),(.06,.004,.05),'cast_iron')
        tube('SaddleStandOff',at+Vector((0,.009,0)),bearing-Vector((0,.004,0)),.0035,'cast_iron',.001)
        box('Saddle',at+Vector((0,.008,0)),(.032,.003,.018),'cast_iron',.0005)
        for dx in [-.022,.022]:
            pin('FixingScrew',bearing+Vector((dx,-.006,0)),bearing+Vector((dx,.012,0)),.0028)
    else:
        box('WallBearing',bearing+Vector((0,0,.002)),(.055,.06,.004),'cast_iron')
        tube('SaddleStandOff',at-Vector((0,0,.009)),bearing+Vector((0,0,.004)),.0035,'cast_iron',.001)
        box('Saddle',at-Vector((0,0,.008)),(.026,.025,.003),'cast_iron',.0005)
        for dy in [-.021,.021]:
            pin('WallFixingScrew',bearing+Vector((0,dy,-.012)),bearing+Vector((0,dy,.008)),.0028)
    empty('Bearing_%03d'%support.count,bearing)
    support.count+=1
support.count=0

def run(name,a,b,ceiling_support=True):
    a,b=Vector(a),Vector(b)
    assert (b-a).length>.015
    tube(name,a,b)
    direction=(b-a).normalized()
    for at in [a,b]:
        tube('ThreadedSocket',at-direction*.014,at+direction*.014,.013,'cast_iron',.004)
    if ceiling_support:
        count=max(1,math.ceil((b-a).length/1.15))
        for index in range(count+1):
            at=a.lerp(b,index/count)
            key=tuple(round(v,5) for v in at)
            if key in run.supported: continue
            run.supported.add(key)
            support(at,(at.x,dim['ceiling'],at.z))
run.supported=set()

x,y,end=dim['x'],dim['height'],dim['end']
cabinet=Vector(dim['box'])
# Blank screwed service cutout enclosure; existing shop controls remain authority.
box('ServiceCutoutBody',cabinet,(.28,.40,.12),'cast_iron',.003)
box('ScrewedServiceCover',cabinet+Vector((0,0,.063)),(.25,.37,.006),'metal')
box('ServiceWallFlange',(x,1.70,end+.003),(.31,.42,.006),'cast_iron')
for dx in [-.105,.105]:
    for dy in [-.16,.16]:
        pin('CoverScrew',cabinet+Vector((dx,dy,.058)),cabinet+Vector((dx,dy,.075)),.004)
        bearing=Vector((x+dx,1.70+dy,end))
        pin('EnclosureWallScrew',bearing-Vector((0,0,.012)),bearing+Vector((0,0,.009)),.003)
        empty('CabinetBearing_%d_%d'%(int(dx>0),int(dy>0)),bearing)
incoming=Vector((x,1.70,end-.166))
tube('IndependentIncoming',incoming,cabinet,.012,'metal',.0015)
empty('IndependentIncoming',incoming)
empty('RearWallPort',dim['rear_port'])
empty('PartitionPort',dim['partition_port'])
tube('EntryBushing',(x,1.70,end-.006),(x,1.70,end+.010),.023,'cast_iron',.011)
tube('ServiceRise',(x,1.895,end+.065),(x,y,end+.065))
for height in [2.05,2.62]: support((x,height,end+.065),(x,height,end))
run('MainLightingConduit',(x,y,end+.065),(x,y,dim['endpoints']['front'][2]))
box('ScrewedServiceHeadJunction',(x,y,end+.065),(.068,.062,.068),'cast_iron')
for name,endpoint in dim['endpoints'].items():
    target=Vector(endpoint)
    corner=Vector((target.x,y,target.z))
    run('LightingBranch_'+name,(x,y,target.z),corner)
    if (target-corner).length>.015: tube('FixtureDrop_'+name,corner,target)
    box('ScrewedJunction_'+name,(x,y,target.z),(.068,.062,.068),'cast_iron')
    empty('Fixture_'+name,target)
    # A threaded connector enters the existing fitting; no replacement light.
    axis=Vector((1,0,0)) if name=='receiving' else Vector((0,1,0))
    tube('FixtureConnector_'+name,target+axis*.018,target-axis*.003,.012,'cast_iron',.003)
port=Vector(dim['partition_port'])
tube('PartitionSleeve',port-Vector((0,0,.09)),port+Vector((0,0,.09)),.019,'cast_iron',.006)
for dz in [-.086,.086]:
    tube('PortEscutcheon',port+Vector((0,0,dz-.002)),port+Vector((0,0,dz+.002)),.027,'cast_iron',.008)

# Physical UVs on each planar worked face, with stable edge-based orientation.
for objects in parts.values():
    for obj in objects:
        bm=bmesh.new()
        bm.from_mesh(obj.data)
        bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
        bmesh.ops.triangulate(bm,faces=[face for face in bm.faces if len(face.verts)>4])
        bm.to_mesh(obj.data)
        bm.free()
        mesh=obj.data
        for layer in list(mesh.uv_layers): mesh.uv_layers.remove(layer)
        uv=mesh.uv_layers.new(name='Metres')
        uv.active_render=True
        for face in mesh.polygons:
            positions=[obj.matrix_world@mesh.vertices[mesh.loops[i].vertex_index].co for i in face.loop_indices]
            normal=(obj.matrix_world.to_3x3()@face.normal).normalized()
            seed=Vector((0,0,1)) if abs(normal.z)<.9 else Vector((0,1,0))
            axis=normal.cross(seed).normalized()
            other=normal.cross(axis).normalized()
            for loop,position in zip(face.loop_indices,positions):
                uv.data[loop].uv=(position.dot(axis),position.dot(other))

bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/bodega_power.blend'))
for key,objects in parts.items():
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects: obj.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    bpy.ops.object.join()
    bpy.context.object.name='BodegaPower__'+key
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
bpy.ops.object.select_all(action='SELECT')
# This bundled exporter flips UV V but retains Blender's bitangent sign.
# Preserve its correct Mikk tangent direction and flip the sign in the official
# pre-serialization hook. The imported derivative check verifies every triangle.
class ExportUVHandedness:
    partitions=0
    def gather_attribute_change(self,attribute,data,normalized,export_settings):
        if attribute=='TANGENT':
            data['data'][:,3]*=-1
            type(self).partitions+=1
import io_scene_gltf2
io_scene_gltf2.glTF2ExportUserExtension=ExportUVHandedness
bpy.ops.export_scene.gltf(filepath=str(ROOT/'game/assets/props/bodega_power.glb'),
    export_format='GLB',export_yup=True,export_apply=True,export_tangents=True)
assert ExportUVHandedness.partitions==len(parts)
print('BODEGA POWER:',len(parts),'partitions;',support.count,'fabric bearings;',len(dim['endpoints']),'existing fittings')
