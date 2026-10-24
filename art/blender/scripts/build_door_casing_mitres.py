"""Native matching 45-degree architrave joints, retaining the existing profiles.

Review output is required: this builder does not publish over the installed
millwork library. Runtime integration follows native and imported validation.
"""
import ast, bpy, bmesh, hashlib, json, math, os, sys
from pathlib import Path
from mathutils import Vector
import numpy as np

ROOT=Path(__file__).resolve().parents[3]
OUT=Path(os.environ.get('CASING_MITRE_OUT',str(ROOT/'tmp/casing-mitre-review')))
assert OUT.resolve().is_relative_to((ROOT/'tmp').resolve()), 'Review output must stay below repository tmp/'
sys.path.insert(0,str(ROOT/'art/blender/scripts'))
from fabrication_chart_batch import triangle_charts
from repair_surface_uvs import repair_scene
from check_exported_tangents import validate

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version=0
source=ROOT/'art/blender/scripts/build_millwork_profile.py'
profiles={}
for node in ast.parse(source.read_text(encoding='utf-8')).body:
    if isinstance(node,ast.Assign):
        for target in node.targets:
            if isinstance(target,ast.Name) and target.id in ['casing','service']:
                profiles[target.id]=ast.literal_eval(node.value)
assert set(profiles)=={'casing','service'}
catalog=json.loads((ROOT/'art/data/runtime_material_sets.json').read_text())['materials']
materials={}
for key in ['door_paint','cast_iron']:
    m=bpy.data.materials.new(key);m.use_nodes=True;materials[key]=m
    bsdf=m.node_tree.nodes.get('Principled BSDF');bsdf.inputs['Metallic'].default_value=catalog[key]['metallic']
    for index,socket in [(0,'Base Color'),(1,'Roughness'),(2,'Normal')]:
        tex=m.node_tree.nodes.new('ShaderNodeTexImage')
        tex.image=bpy.data.images.load(str(next((ROOT/'game/assets').rglob(catalog[key]['files'][index]))),check_existing=True)
        if index:tex.image.colorspace_settings.name='Non-Color'
        if index==2:
            normal=m.node_tree.nodes.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.2
            m.node_tree.links.new(tex.outputs['Color'],normal.inputs['Color']);m.node_tree.links.new(normal.outputs['Normal'],bsdf.inputs[socket])
        else:m.node_tree.links.new(tex.outputs['Color'],bsdf.inputs[socket])

def native(v):return (v[0],-v[2],v[1])

def stock(name,section,width,height,part,material):
    # Physical section width/depth agree with the retained .09/.018 envelope.
    W=.09;D=.018;points=[];n=len(section)
    for end in [0,1]:
        for q,z in section:
            if part=='head':
                x=(-1 if end==0 else 1)*(width*.5+W*.5+q*W);y=height+W*.5+q*W
            else:
                x=(-1 if part=='left' else 1)*(width*.5+W*.5+q*W)
                y=0 if end==0 else height+W*.5+q*W
            points.append((x,y,z*D))
    faces=[tuple(range(n-1,-1,-1)),tuple(range(n,n*2))]
    faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    data=bpy.data.meshes.new(name);data.from_pydata([native(v) for v in points],[],faces);data.update()
    obj=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(obj);data.materials.append(material)
    bm=bmesh.new();bm.from_mesh(data);bmesh.ops.triangulate(bm,faces=list(bm.faces));bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(data);bm.free();data.calc_loop_triangles()
    triangles=np.array([[data.vertices[i].co[:] for i in t.vertices] for t in data.loop_triangles])
    _,_,charts,_=triangle_charts(triangles,np.zeros(3),catalog[material.name]['meters_per_tile'])
    layer=data.uv_layers.new(name='Metres')
    for tri,uvs in zip(data.loop_triangles,charts):
        for loop,uv in zip(tri.loops,uvs):layer.data[loop].uv=uv
    return obj,points

layout=json.loads((ROOT/'game/data/orison_v2_blockout.json').read_text())
dimensions=sorted({(round(float(r['width']),6),round(float(r['height']),6)) for r in layout['doors']})
records=[];all_variants=[]
for width,height in dimensions:
    for style,profile in [('domestic',profiles['casing']),('service',profiles['service'])]:
        key=('D' if style=='domestic' else 'S')+f'{round(width*1000):04}_{round(height*1000):04}'
        parts=[];clouds={}
        for part in ['left','head','right']:
            obj,points=stock(key+'_'+part,profile,width,height,part,materials['door_paint' if style=='domestic' else 'cast_iron'])
            parts.append(obj);clouds[part]=points
        # Matching native cap vertices, rather than overlapping square stocks.
        n=len(profile)
        head_left=clouds['head'][:n];head_right=clouds['head'][n:]
        left_top=clouds['left'][n:];right_top=clouds['right'][n:]
        error=max(max(math.dist(a,b) for a,b in zip(head_left,left_top)),max(math.dist(a,b) for a,b in zip(head_right,right_top)))
        assert error<1e-9,(key,error)
        records.append({'id':key,'width':width,'height':height,'style':style,'joint_max_error_m':error,'parts':len(parts)})
        all_variants.append((key,parts))
repair_scene();OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'door_casing_mitres.blend'))
for key,parts in all_variants:
    bpy.ops.object.select_all(action='DESELECT')
    copies=[]
    for obj in parts:
        duplicate=obj.copy();duplicate.data=obj.data.copy();bpy.context.collection.objects.link(duplicate)
        duplicate.select_set(True);copies.append(duplicate)
    bpy.context.view_layer.objects.active=copies[0];bpy.ops.object.join();bpy.context.object.name=key
class ExportUVHandedness:
    def gather_attribute_change(self,attribute,data,normalized,export_settings):
        if attribute=='TANGENT':data['data'][:,3]*=-1
import io_scene_gltf2
io_scene_gltf2.glTF2ExportUserExtension=ExportUVHandedness
asset=OUT/'door_casing_mitres.glb'
bpy.ops.export_scene.gltf(filepath=str(asset),export_format='GLB',export_yup=True,export_apply=True,export_tangents=True,export_image_format='NONE')
report={'evidence_class':'INERT','scope':'Uninstalled native miter candidate; no runtime qualification','variants':records,'exported_tangents':validate(asset),'source_profile_sha256':hashlib.sha256(source.read_bytes().replace(b'\r\n',b'\n')).hexdigest(),'asset_sha256':hashlib.sha256(asset.read_bytes()).hexdigest()}
(OUT/'construction.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print('NATIVE MITRES',len(records),'front frames; all cap vertices match at 45 degrees')

# Native corner review, separate from the exported library.
chosen=next(r['id'] for r in records if r['style']=='domestic' and abs(r['width']-.81)<.001)
selected=bpy.data.objects[chosen];info=next(r for r in records if r['id']==chosen)
for obj in bpy.context.scene.objects:obj.hide_render=obj!=selected
bpy.ops.mesh.primitive_plane_add(size=6,location=(0,.009,1.5));wall=bpy.context.object;wall.rotation_euler.x=math.pi*.5
wallmat=bpy.data.materials.new('Review plaster only');wallmat.diffuse_color=(.25,.28,.25,1);wall.data.materials.append(wallmat)
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24
scene.world=bpy.data.worlds.new('Native review');scene.world.color=(.02,.02,.02)
scene.view_settings.exposure=-1.0
target=Vector((-.81*.5-.04,0,info['height']+.04))
for at,power,size in [((-1,-.5,2.6),5,.5),((.3,-.6,2.1),1.5,.4)]:
    bpy.ops.object.light_add(type='AREA',location=at);lamp=bpy.context.object;lamp.data.energy=power;lamp.data.size=size
    lamp.rotation_euler=(target-lamp.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=target+Vector((-.12,-.65,.10)));camera=bpy.context.object
camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.type='ORTHO';camera.data.ortho_scale=.32;scene.camera=camera
scene.render.resolution_x=900;scene.render.resolution_y=900;scene.render.resolution_percentage=100
scene.render.filepath=str(OUT/'native_mitre.png');bpy.ops.render.render(write_still=True)
