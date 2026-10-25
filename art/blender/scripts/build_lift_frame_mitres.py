"""Unscaled lift reveals with matching diagonal ends and retained brass grooves."""
from pathlib import Path
import ast, hashlib, json, sys
import bpy, bmesh, numpy as np
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(Path(__file__).parent))
from fabrication_chart_batch import triangle_charts
from check_exported_tangents import validate

profile_path=Path(__file__).with_name('build_millwork_profile.py')
profile=None
for node in ast.parse(profile_path.read_text(encoding='utf8')).body:
    if isinstance(node,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='lift' for t in node.targets):
        profile=ast.literal_eval(node.value)
assert profile and len(profile)==16
W,H,T,D,HEAD=.91,2.14,.09,.20,.14
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version=0
spec=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text())['materials']['brass']
material=bpy.data.materials.new('brass');material.use_nodes=True
bsdf=material.node_tree.nodes['Principled BSDF'];bsdf.inputs['Metallic'].default_value=spec['metallic']
coordinate=material.node_tree.nodes.new('ShaderNodeTexCoord')
scale=material.node_tree.nodes.new('ShaderNodeVectorMath');scale.operation='SCALE';scale.inputs[3].default_value=1/spec['meters_per_tile']
material.node_tree.links.new(coordinate.outputs['UV'],scale.inputs[0])
for index,socket in [(0,'Base Color'),(1,'Roughness'),(2,'Normal')]:
    image=bpy.data.images.load(str(ROOT/'game/assets/building/textures'/spec['files'][index]),check_existing=True)
    if index:image.colorspace_settings.name='Non-Color'
    texture=material.node_tree.nodes.new('ShaderNodeTexImage');texture.image=image
    material.node_tree.links.new(scale.outputs[0],texture.inputs['Vector'])
    if index==2:
        normal=material.node_tree.nodes.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.35
        material.node_tree.links.new(texture.outputs['Color'],normal.inputs['Color']);material.node_tree.links.new(normal.outputs[0],bsdf.inputs[socket])
    else:material.node_tree.links.new(texture.outputs['Color'],bsdf.inputs[socket])

cap_points={};parts=[]
for name in ['west','east','head']:
    vertices=[];n=len(profile)
    for end in [0,1]:
        for q,z in profile:
            x=(-1 if (end==0 if name=='head' else name=='west') else 1)*(W/2+T/2+q*T)
            y=H+T/2+q*T if name=='head' or end else 0
            vertices.append((x,y,z*D))
    cap_points[name]=list(vertices)
    faces=[tuple(reversed(range(n))),tuple(range(n,n*2))]
    faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    if name=='head':
        # Keep the existing 140mm head envelope. The lower90mm carries the
        # exact jamb section through each diagonal cap; the remaining50mm
        # is joined solid stock above it, with no square overlap into a jamb.
        faces.pop(2+n-2)
        offset=len(vertices);half=W/2+T;front=profile[-2][1]*D
        vertices += [(x,y,z) for y in [H+T,H+HEAD] for z in [-D/2,front] for x in [-half,half]]
        faces += [tuple(offset+i for i in f) for f in [(4,5,7,6),(0,4,6,2),(1,3,7,5),(0,1,5,4),(2,6,7,3)]]
    mesh=bpy.data.meshes.new('Landing_'+name)
    mesh.from_pydata([(x,-z,y) for x,y,z in vertices],[],faces);mesh.update()
    bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-8)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    assert all(edge.is_manifold for edge in bm.edges),name
    assert bm.calc_volume(signed=True)>0,name
    bmesh.ops.triangulate(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free();mesh.calc_loop_triangles()
    triangles=np.array([[mesh.vertices[v].co[:] for v in face.vertices] for face in mesh.loop_triangles])
    _,_,charts,_=triangle_charts(triangles,np.zeros(3),spec['meters_per_tile'])
    uv=mesh.uv_layers.new(name='Metres')
    for face,chart in zip(mesh.loop_triangles,charts):
        for loop,pair in zip(face.loops,chart):uv.data[loop].uv=pair
    mesh.materials.append(material);obj=bpy.data.objects.new(mesh.name,mesh);bpy.context.collection.objects.link(obj)
    parts.append({'name':obj.name,'member':name,'triangles':len(mesh.loop_triangles)})
assert cap_points['west'][16:]==cap_points['head'][:16]
assert cap_points['east'][16:]==cap_points['head'][16:]
for image in bpy.data.images:
    if image.source=='FILE':image.filepath=bpy.path.relpath(image.filepath,start=str(ROOT/'art/blender'))
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/lift_frame_mitres.blend'))
class ExportUVHandedness:
    def gather_attribute_change(self,attribute,data,normalized,export_settings):
        if attribute=='TANGENT':data['data'][:,3]*=-1
import io_scene_gltf2
io_scene_gltf2.glTF2ExportUserExtension=ExportUVHandedness
asset=ROOT/'game/assets/props/lift_frame_mitres.glb'
bpy.ops.export_scene.gltf(filepath=str(asset),export_format='GLB',export_tangents=True,export_image_format='NONE')
exported=validate(asset);assert exported['status']=='PASS',exported
runtime={'schema_version':1,'asset':'res://assets/props/lift_frame_mitres.glb','width':W,'height':H,'depth':D,'jamb_width':T,'head_width':HEAD,'catalog_key':'brass','parts':parts}
(ROOT/'game/data/orison_v2/lift_frame_mitres.json').write_bytes((json.dumps(runtime,indent=2)+'\n').encode())
sources=[Path(__file__),profile_path,ROOT/'game/data/runtime_material_sets.json']
report={'evidence_class':'INERT','scope':'Native lift reveal stock; not installed or runtime-qualified.','runtime':runtime,'interfaces_godot':{'west':cap_points['west'][16:],'east':cap_points['east'][16:]},'exported':exported,'asset_sha256':hashlib.sha256(asset.read_bytes()).hexdigest(),'source_bindings':{p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes().replace(b'\r\n',b'\n')).hexdigest() for p in sources}}
for path in ['art/blender/lift_frame_mitres_construction.json','game/tests/fixtures/v2_lift_frame_mitres.json']:
    (ROOT/path).write_bytes((json.dumps(report,indent=2)+'\n').encode())
print('LIFT MITRES',parts,'; matching sixteen-corner grooved caps')
