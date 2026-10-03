"""Source-fitted east roof landing transfer on the retained F06 slabs."""
from pathlib import Path
import json,math
import bpy,bmesh,numpy as np
from mathutils import Vector

ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
OUT=ROOT/'art/blender';OUT.mkdir(parents=True,exist_ok=True)
layout_path=ROOT/'game/data/orison_v2_blockout.json'
layout=json.loads(layout_path.read_text(encoding='utf-8'))
platform=next(r for r in layout['platforms'] if r['id']=='ROOF_PUBLIC_LANDING_E')
assert platform['rect']==[4.5,-1.9,5.4,1.65]
assert {r['id']:r['y'] for r in layout['levels']}['F06']==16.
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.context.preferences.filepaths.save_version=0
materials={}
for key,color in [('cast_iron',(.065,.065,.059,1)),('metal',(.25,.27,.27,1))]:
    mat=bpy.data.materials.new(key);mat.use_nodes=True;bsdf=mat.node_tree.nodes['Principled BSDF']
    bsdf.inputs['Base Color'].default_value=color;bsdf.inputs['Metallic'].default_value=.65;bsdf.inputs['Roughness'].default_value=.5
    materials[key]=mat
def point(p):
    return Vector((p[0], -p[2], p[1]))

def solid(name, vertices, faces, key):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([point(p) for p in vertices], [], faces)
    mesh.update()
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    assert all((e.is_manifold for e in bm.edges)) and bm.calc_volume(signed=True) > 0, name
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.data.materials.append(materials[key])
    return obj

def box(name, at, size, key, bevel=0.001):
    x, y, z = at
    a, b, c = [v * 0.5 for v in size]
    obj = solid(name, [(x + i * a, y + j * b, z + k * c) for k in [-1, 1] for j in [-1, 1] for i in [-1, 1]], [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)], key)
    if bevel:
        mod = obj.modifiers.new('Worked edge', 'BEVEL')
        mod.width = bevel
        mod.segments = 2
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return obj

def rod(name, a, b, radius, key, sides=12):
    start, end = (point(a), point(b))
    axis = (end - start).normalized()
    seed = Vector((0, 0, 1)) if abs(axis.z) < 0.85 else Vector((1, 0, 0))
    u = axis.cross(seed).normalized()
    v = axis.cross(u).normalized()
    vertices = []
    for centre in [start, end]:
        for i in range(sides):
            p = centre + radius * (u * math.cos(2 * math.pi * i / sides) + v * math.sin(2 * math.pi * i / sides))
            vertices.append((p.x, p.z, -p.y))
    faces = [tuple(reversed(range(sides))), tuple(range(sides, sides * 2))]
    faces += [(i, (i + 1) % sides, (i + 1) % sides + sides, i + sides) for i in range(sides)]
    return solid(name, vertices, faces, key)

def join(parts, name):
    if len(parts) == 1:
        parts[0].name = name
        return parts[0]
    bpy.ops.object.select_all(action='DESELECT')
    for obj in parts:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    obj = parts[0]
    obj.name = name
    return obj

def map_metres(obj):
    mesh = obj.data
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.triangulate(bm, faces=list(bm.faces))
    bm.to_mesh(mesh)
    bm.free()
    mesh.update()
    uv = mesh.uv_layers.active or mesh.uv_layers.new(name='Metres')
    uv.active_render = True
    for face in mesh.polygons:
        face.use_smooth = False
        normal = Vector(face.normal).normalized()
        seed = Vector((0, 1, 0)) if abs(normal.y) < 0.85 else Vector((1, 0, 0))
        u = (seed - normal * seed.dot(normal)).normalized()
        v = normal.cross(u).normalized()
        for loop in face.loop_indices:
            p = mesh.vertices[mesh.loops[loop].vertex_index].co
            uv.data[loop].uv = (p.dot(u), p.dot(v))
    if 'custom_normal' in mesh.attributes:
        mesh.attributes.remove(mesh.attributes['custom_normal'])
    mesh.update()

parts=[];columns=[]
for z in [-2.06,1.82]:
    x=4.625;label='RoofCourtBridgePost_'+str(z)
    parts.append(box(label+'Base',(x,16.006,z),(.12,.012,.12),'metal',.001))
    parts.append(box(label,(x,(16.012+18.8)*.5,z),(.08,2.788,.08),'cast_iron',.001))
    for dx in [-.045,.045]:parts.append(rod(label+'Fixing',(x+dx,16.012,z),(x+dx,16.022,z),.005,'metal'))
    columns.append({'id':label,'base':[x,16.,z],'top':[x,18.8,z],
                    'floor_owner':'F06_PUBLIC_LANDING_S' if z<0 else 'F06_PUBLIC_LANDING_N'})
low,high=18.8,19.0;half=.0625;web=.004;flange=.008;x=4.625
profile=[(-half,low),(half,low),(half,low+flange),(web,low+flange),
    (web,high-flange),(half,high-flange),(half,high),(-half,high),
    (-half,high-flange),(-web,high-flange),(-web,low+flange),(-half,low+flange)]
n=len(profile);vertices=[(x+offset,y,z) for z in [-2.12,1.88] for offset,y in profile]
faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
parts.append(solid('EastLandingSeatedBeam',vertices,faces,'cast_iron'))
groups={key:[o for o in parts if o.data.materials[0].name==key] for key in materials}
for key,group in groups.items():
    obj=join(group,'RoofCourtBridgeTransfer_'+key);map_metres(obj)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'court_roof_bridge.blend'))
class ExportMetricBasis:
    def gather_attribute_change(self,attribute,data,normalized,export_settings):
        if attribute=='NORMAL':self.normals=np.asarray(data['data'],dtype=np.float64).reshape(-1,3)
        elif attribute=='TANGENT':
            result=np.zeros((len(self.normals),4),dtype=np.float32)
            for i,n in enumerate(self.normals):
                seed=np.array((0,0,-1) if abs(n[2])<.85 else (1,0,0),dtype=np.float64)
                u=seed-n*np.dot(seed,n);u/=np.linalg.norm(u);result[i,:3]=u;result[i,3]=-1
            data['data']=result
import io_scene_gltf2
io_scene_gltf2.glTF2ExportUserExtension=ExportMetricBasis
bpy.ops.export_scene.gltf(filepath=str(ROOT/'game/assets/props/court_roof_bridge.glb'),export_format='GLB',export_yup=True,export_tangents=True,export_animations=False)
(ROOT/'game/tests/fixtures/orison_court_roof_bridge.json').write_text(json.dumps({'evidence_class':'INERT','platform':platform,
    'columns':columns,'beam_x':x,'beam_z':[-2.12,1.88],'beam_top':19.0,'note':'Source-fitted geometric load path only. No engineering capacity or requirement acceptance.'},indent=2)+'\n',encoding='utf-8',newline='\n')
print('ROOF COURT BRIDGE: 900mm clear east landing, two posts on retained F06 landings, 4m seated I-section')
