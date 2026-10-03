"""Source-fitted light-court guards and basement slab transfers."""
from pathlib import Path
import json, math
import bpy, bmesh
import numpy as np
from mathutils import Vector

ROOT = next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
OUT = ROOT/'art/blender'
OUT.mkdir(parents=True, exist_ok=True)
layout_path = ROOT/'game/data/orison_v2_blockout.json'
layout = json.loads(layout_path.read_text(encoding='utf-8'))
levels = {r['id']: r['y'] for r in layout['levels']}
well = next(r for r in layout['platforms'] if r['id']=='F01_LIGHT_COURT_BASE')
assert well['rect'] == [2.45,-1.9,3.45,-.25]
assert next(r for r in layout['platforms'] if r['id']=='B1_PRIMARY_STAIR_BASE')['rect'] == [1.4,-1.9,4.5,1.65]
assert levels['B1']==-3.2 and levels['F01']==0 and layout['dimensions']['slab_thickness']==.2
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
bpy.context.preferences.filepaths.save_version=0
materials={}
for key, color, metallic, rough in [
    ('cast_iron',(.065,.065,.059,1),.65,.55),
    ('metal',(.25,.27,.27,1),.8,.45),
    ('wood_dark',(.095,.052,.025,1),0,.35)]:
    mat=bpy.data.materials.new(key); mat.use_nodes=True
    bsdf=mat.node_tree.nodes['Principled BSDF']
    bsdf.inputs['Base Color'].default_value=color
    bsdf.inputs['Metallic'].default_value=metallic
    bsdf.inputs['Roughness'].default_value=rough
    materials[key]=mat

def point(p): return Vector((p[0],-p[2],p[1]))
def solid(name, vertices, faces, key):
    mesh=bpy.data.meshes.new(name); mesh.from_pydata([point(p) for p in vertices],[],faces); mesh.update()
    bm=bmesh.new(); bm.from_mesh(mesh); bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    assert all(e.is_manifold for e in bm.edges) and bm.calc_volume(signed=True)>0, name
    bm.to_mesh(mesh); bm.free()
    obj=bpy.data.objects.new(name,mesh); bpy.context.scene.collection.objects.link(obj)
    obj.data.materials.append(materials[key]); return obj

def box(name, at, size, key, bevel=.001):
    x,y,z=at; a,b,c=[v*.5 for v in size]
    obj=solid(name,[(x+i*a,y+j*b,z+k*c) for k in [-1,1] for j in [-1,1] for i in [-1,1]],
              [(0,1,3,2),(4,6,7,5),(0,4,5,1),(2,3,7,6),(0,2,6,4),(1,5,7,3)],key)
    if bevel:
        mod=obj.modifiers.new('Worked edge','BEVEL'); mod.width=bevel; mod.segments=2
        bpy.context.view_layer.objects.active=obj
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return obj

def rod(name,a,b,radius,key,sides=12):
    start,end=point(a),point(b); axis=(end-start).normalized()
    seed=Vector((0,0,1)) if abs(axis.z)<.85 else Vector((1,0,0))
    u=axis.cross(seed).normalized(); v=axis.cross(u).normalized()
    vertices=[]
    for centre in [start,end]:
        for i in range(sides):
            p=centre+radius*(u*math.cos(2*math.pi*i/sides)+v*math.sin(2*math.pi*i/sides))
            vertices.append((p.x,p.z,-p.y))
    faces=[tuple(reversed(range(sides))),tuple(range(sides,sides*2))]
    faces += [(i,(i+1)%sides,(i+1)%sides+sides,i+sides) for i in range(sides)]
    return solid(name,vertices,faces,key)

def join(parts,name):
    if len(parts)==1:
        parts[0].name=name
        return parts[0]
    bpy.ops.object.select_all(action='DESELECT')
    for obj in parts: obj.select_set(True)
    bpy.context.view_layer.objects.active=parts[0]
    bpy.ops.object.join(); obj=parts[0]; obj.name=name
    return obj

def map_metres(obj):
    mesh=obj.data
    bm=bmesh.new(); bm.from_mesh(mesh)
    bmesh.ops.triangulate(bm,faces=list(bm.faces)); bm.to_mesh(mesh); bm.free(); mesh.update()
    uv=mesh.uv_layers.active or mesh.uv_layers.new(name='Metres'); uv.active_render=True
    for face in mesh.polygons:
        face.use_smooth=False; normal=Vector(face.normal).normalized()
        seed=Vector((0,1,0)) if abs(normal.y)<.85 else Vector((1,0,0))
        u=(seed-normal*seed.dot(normal)).normalized(); v=normal.cross(u).normalized()
        for loop in face.loop_indices:
            p=mesh.vertices[mesh.loops[loop].vertex_index].co
            uv.data[loop].uv=(p.dot(u),p.dot(v))
    if 'custom_normal' in mesh.attributes: mesh.attributes.remove(mesh.attributes['custom_normal'])
    mesh.update()

def guard_template(span):
    groups={k:[] for k in materials}; feet=[]
    count=math.ceil((span-.05)/.105)
    for i in range(count+1):
        x=.025+(span-.05)*i/count
        heavy=i in [0,count]; size=.025 if heavy else .014
        groups['cast_iron'].append(box('ForgedUpright',(x,.540,0),(size,1.02,size),'cast_iron'))
        if heavy:
            groups['cast_iron'].append(box('SeatedFoot',(x,.014,0),(.050,.028,.065),'cast_iron',.003))
            feet.append([x,0,0])
            for dz in [-.023,.023]:
                groups['metal'].append(rod('FootRivet',(x,.028,dz),(x,.036,dz),.004,'metal'))
        groups['cast_iron'].append(box('SquareCollar',(x,.155,0),(size+.01,.026,size+.01),'cast_iron'))
    for y in [.18,.985]:
        groups['cast_iron'].append(rod('ForgedRail',(0,y,0),(span,y,0),.009,'cast_iron'))
    groups['wood_dark'].append(rod('TimberGrip',(0,1.025,0),(span,1.025,0),.025,'wood_dark',16))
    templates=[]
    for key,parts in groups.items():
        obj=join(parts,'Template_'+key); map_metres(obj); templates.append(obj)
    return templates,feet

guards=[]; meshes=[]
for kind,span in [('North',3.1),('South',1.),('CourtStop',1.)]:
    templates,feet=guard_template(span)
    floors=['F01','F02','F03','F04','F05','F06','ROOF'] if kind=='North' else (
        ['F02','F03','F04','F05','F06','ROOF'] if kind=='South' else ['F01'])
    for level in floors:
        x,z=(1.4,1.70) if kind=='North' else ((2.45,-1.945) if kind=='South' else (2.45,-.58))
        y=levels[level]; prefix=f'{level}_LightCourtGuard_{kind}'
        for source in templates:
            obj=source.copy(); obj.data=source.data
            bpy.context.scene.collection.objects.link(obj); obj.name=prefix+'_'+obj.data.materials[0].name
            obj.location=point((x,y,z)); meshes.append(obj)
        guards.append({'id':prefix,'level':level,'kind':kind,'bounds':[x,y,z-.0325,x+span,y+1.05,z+.0325],
            'foot_contacts':[[x+p[0],y,z] for p in feet],
            'floor_owner':level+'_PUBLIC_LANDING_'+('N' if kind=='North' else 'S') if kind!='CourtStop' else well['id']})
    for obj in templates: bpy.data.objects.remove(obj,do_unlink=True)

# Four columns and two closed I-section beams seat the new slab on B1.
supports=[]; contacts=[]
for x in [2.55,3.35]:
    for z in [-1.8,-.55]:
        name='CourtColumn_'+str(x)+'_'+str(z)
        supports.append(box(name+'Base',(x,-3.194,z),(.12,.012,.12),'metal',.001))
        supports.append(box(name,(x,(-3.188-.38)*.5,z),(.08,2.808,.08),'cast_iron',.001))
        for dx in [-.045,.045]:
            supports.append(rod(name+'Fixing',(x+dx,-3.188,z),(x+dx,-3.178,z),.005,'metal'))
        contacts.append({'id':name,'base':[x,-3.2,z],'top':[x,-.38,z],'floor_owner':'B1_PRIMARY_STAIR_BASE'})
for z in [-1.8,-.55]:
    # One watertight section per beam, without hidden web/flange overlap.
    low,high=-.38,-.2; half=.05; web=.004; flange=.008
    profile=[(-half,low),(half,low),(half,low+flange),(web,low+flange),
             (web,high-flange),(half,high-flange),(half,high),(-half,high),
             (-half,high-flange),(-web,high-flange),(-web,low+flange),(-half,low+flange)]
    n=len(profile); vertices=[(x,y,z+offset) for x in [2.49,3.41] for offset,y in profile]
    faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]
    faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    supports.append(solid('CourtCrossBeam_'+str(z),vertices,faces,'cast_iron'))
support_groups={key:[o for o in supports if o.data.materials[0].name==key] for key in ['cast_iron','metal']}
for key,group in support_groups.items():
    obj=join(group,'LightCourtTransfer_'+key)
    map_metres(obj); meshes.append(obj)

construction={'evidence_class':'INERT','classification':'ADAPTATION',
    'authority':'art/data/orison_v2/vertical_services_source.json and projected layout', 'guards':guards,'columns':contacts,
    'well':well, 'note':'Native fit and geometric load path only. No engineering capacity or runtime acceptance.'}
(ROOT/'game/tests/fixtures/orison_light_court_structure.json').write_text(json.dumps(construction,indent=2)+'\n',encoding='utf-8',newline='\n')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'light_court_structure.blend'))

class ExportMetricBasis:
    def gather_attribute_change(self,attribute,data,normalized,export_settings):
        if attribute=='NORMAL': self.normals=np.asarray(data['data'],dtype=np.float64).reshape(-1,3)
        elif attribute=='TANGENT':
            result=np.zeros((len(self.normals),4),dtype=np.float32)
            for i,n in enumerate(self.normals):
                seed=np.array((0,0,-1) if abs(n[2])<.85 else (1,0,0),dtype=np.float64)
                u=seed-n*np.dot(seed,n); u/=np.linalg.norm(u)
                result[i,:3]=u; result[i,3]=-1
            data['data']=result
import io_scene_gltf2
io_scene_gltf2.glTF2ExportUserExtension=ExportMetricBasis
bpy.ops.export_scene.gltf(filepath=str(ROOT/'game/assets/props/light_court_structure.glb'),export_format='GLB',
    export_yup=True,export_tangents=True,export_animations=False)
print('COURT STRUCTURE TRIAL:',len(guards),'guards, four seated columns, two I-section crossbeams,',len(meshes),'draws')

(ROOT/'game/data/orison_v2/light_court_guards.json').write_text(json.dumps({'guards':[{k:r[k] for k in ['id','bounds']} for r in guards]},indent=2)+'\n',encoding='utf-8',newline='\n')
