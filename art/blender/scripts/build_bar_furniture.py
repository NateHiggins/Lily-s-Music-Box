"""Native passive stage furniture and the source-owned Rainbow Round target.

Retirement records contain actual shipping triangles, never edited glTF.
The original gameplay owners, authored scoring and lettering stay elsewhere.
"""
from pathlib import Path
import collections, hashlib, json, math, sys
import bpy, bmesh, numpy as np
from mathutils import Vector, Matrix

ROOT = next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
sys.path.insert(0, str(ROOT/'art/blender/scripts'))
from fabrication_chart_batch import triangle_charts
from fabrication_grain import stock_grain_frame
from fabrication_normals import stock_corner_normals
from check_exported_tangents import validate as validate_export

PLAN = ROOT/'art/data/bar_furniture/source_plan.json'
plan = json.loads(PLAN.read_text(encoding='utf-8'))
catalog = json.loads((ROOT/'game/data/runtime_material_sets.json').read_text())['materials']
layout = json.loads((ROOT/'art/data/building_layout.json').read_text(encoding='utf-8'))
rows = {r['id']: r for f in layout['floors'] if f['id']=='F01' for r in f['furniture']}
assert all(rows[r['id']]==r for r in plan['source_records'])
def digest(p):
    data=p.read_bytes()
    return hashlib.sha256(data if p.suffix in ['.glb','.blend','.png','.bin'] else data.replace(b'\r\n',b'\n')).hexdigest()

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version=0
stocks=bpy.data.collections.new('ClosedConstruction');bpy.context.scene.collection.children.link(stocks)
exports=bpy.data.collections.new('RuntimePartitions');bpy.context.scene.collection.children.link(exports)
stocks.hide_render=True
materials={};pieces=collections.defaultdict(list);checks=[];contacts=[];joins=[]
current='';origin=Vector((0,0,0));basis=Matrix.Identity(3)
def frame(identity,at,rotation=None):
    global current,origin,basis
    current=identity;origin=Vector(at);basis=Matrix.Identity(3) if rotation is None else rotation
def world(point):return origin+basis@Vector(point)
def material(key):
    if key in materials:return materials[key]
    finish=plan['finishes'][key];spec=catalog[finish['catalog_key']]
    mat=bpy.data.materials.new(key);mat.use_nodes=True;node=mat.node_tree.nodes['Principled BSDF']
    node.inputs['Metallic'].default_value=finish.get('metallic',spec['metallic'])
    uv=mat.node_tree.nodes.new('ShaderNodeTexCoord');scale=mat.node_tree.nodes.new('ShaderNodeVectorMath');scale.operation='SCALE';scale.inputs['Scale'].default_value=1/spec['meters_per_tile'];mat.node_tree.links.new(uv.outputs['UV'],scale.inputs[0])
    for i,target in enumerate(['Base Color','Roughness','Normal']):
        image=bpy.data.images.load(str(ROOT/'game/assets/building/textures'/spec['files'][i]),check_existing=True)
        if i:image.colorspace_settings.name='Non-Color'
        texture=mat.node_tree.nodes.new('ShaderNodeTexImage');texture.image=image;mat.node_tree.links.new(scale.outputs[0],texture.inputs[0])
        if i==2:
            normal=mat.node_tree.nodes.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=finish['normal'];mat.node_tree.links.new(texture.outputs[0],normal.inputs['Color']);mat.node_tree.links.new(normal.outputs[0],node.inputs[target])
        elif i==1:
            mul=mat.node_tree.nodes.new('ShaderNodeMath');mul.operation='MULTIPLY';mul.inputs[1].default_value=finish['roughness'];mat.node_tree.links.new(texture.outputs[0],mul.inputs[0]);mat.node_tree.links.new(mul.outputs[0],node.inputs[target])
        else:
            mul=mat.node_tree.nodes.new('ShaderNodeMixRGB');mul.blend_type='MULTIPLY';mul.inputs[0].default_value=1.
            mul.inputs[2].default_value=[v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in finish['tint'][:3]]+[1.]
            pigment=mat.node_tree.nodes.new('ShaderNodeMixRGB');pigment.inputs[0].default_value=finish['pigment']
            pixels=np.empty(len(image.pixels),dtype=np.float32);image.pixels.foreach_get(pixels)
            sample=pixels.reshape((image.size[1],image.size[0],4))[::max(1,image.size[1]//32),::max(1,image.size[0]//32),:3]
            sample=np.where(sample<=.04045,sample/12.92,((sample+.055)/1.055)**2.4)
            mean=sample.mean(axis=(0,1));assert np.isfinite(mean).all(),key
            pigment.inputs[1].default_value=(*mean,1.)
            mat.node_tree.links.new(texture.outputs[0],pigment.inputs[2]);mat.node_tree.links.new(pigment.outputs[0],mul.inputs[1]);mat.node_tree.links.new(mul.outputs[0],node.inputs[target])
    materials[key]=mat;return mat
def solid(name,vertices,faces,key,bevel=0):
    # Keep fine geometry near its assembly origin; do not round sub-mm bevels
    # by baking vertices thirty metres from the Blender origin.
    mesh=bpy.data.meshes.new(current+'__'+name);mesh.from_pydata(vertices,[],faces);mesh.update()
    obj=bpy.data.objects.new(mesh.name,mesh);stocks.objects.link(obj);obj.location=origin;obj.rotation_euler=basis.to_euler();mesh.materials.append(material(key))
    bpy.context.view_layer.objects.active=obj
    if bevel:
        mod=obj.modifiers.new('Worked arris','BEVEL');mod.width=bevel;mod.segments=3;bpy.ops.object.modifier_apply(modifier=mod.name)
    bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    if bm.calc_volume(signed=True)<0:bmesh.ops.reverse_faces(bm,faces=list(bm.faces))
    assert all(e.is_manifold for e in bm.edges) and bm.calc_volume(signed=True)>1e-14,obj.name
    checks.append({'name':obj.name,'assembly':current,'key':key,'volume_m3':bm.calc_volume(signed=True)});bm.to_mesh(mesh);bm.free()
    pieces[(current,key)].append(obj);return obj
def box(name,low,high,key='case',bevel=.001):
    return solid(name,[(x,y,z) for z in [low[2],high[2]] for y in [low[1],high[1]] for x in [low[0],high[0]]],[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)],key,min(bevel,min(high[i]-low[i] for i in range(3))*.2))
def rod(name,a,b,r,key='iron',n=32,top=None):
    a,b=Vector(a),Vector(b);axis=(b-a).normalized();u=axis.cross(Vector((0,0,1)) if abs(axis.z)<.9 else Vector((1,0,0))).normalized();v=axis.cross(u)
    vertices=[p+radius*(u*math.cos(i*math.tau/n)+v*math.sin(i*math.tau/n)) for p,radius in [(a,r),(b,r if top is None else top)] for i in range(n)]
    return solid(name,vertices,[tuple(reversed(range(n)))]+[(i,(i+1)%n,n+(i+1)%n,n+i) for i in range(n)]+[tuple(range(n,2*n))],key)
def ring(name,a,b,outer,inner,key='brass',n=96):
    a,b=Vector(a),Vector(b);axis=(b-a).normalized();u=axis.cross(Vector((0,0,1)) if abs(axis.z)<.9 else Vector((1,0,0))).normalized();v=axis.cross(u)
    vertices=[p+r*(u*math.cos(i*math.tau/n)+v*math.sin(i*math.tau/n)) for p,r in [(a,outer),(b,outer),(b,inner),(a,inner)] for i in range(n)]
    return solid(name,vertices,[(j*n+i,j*n+(i+1)%n,((j+1)%4)*n+(i+1)%n,((j+1)%4)*n+i) for j in range(4) for i in range(n)],key)
def screw(name,at,axis=(0,1,0),radius=.003):
    at=Vector(at);axis=Vector(axis);obj=rod(name,at-axis*.002,at,radius,'brass',24)
    bpy.ops.mesh.primitive_cube_add(size=1);cut=bpy.context.object;cut.dimensions=(radius*2.4,.0012,.00065)
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    cut.rotation_euler=axis.to_track_quat('Z','Y').to_euler();cut.location=at-axis*.0002
    bpy.context.view_layer.update()
    cut.matrix_world=obj.matrix_world@cut.matrix_world
    bpy.context.view_layer.objects.active=obj;mod=obj.modifiers.new('Slotted head','BOOLEAN');mod.operation='DIFFERENCE';mod.object=cut;bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(cut,do_unlink=True)
def contact(name,point,normal,owner):
    p=world(point);n=basis@Vector(normal)
    contacts.append({'id':current+'_'+name,'point':[p.x,p.z,-p.y],'normal':[n.x,n.z,-n.y],'owner':owner})

exec(compile((ROOT/'art/blender/scripts/bar_furniture_geometry.py').read_text(encoding='utf-8'),'bar_furniture_geometry.py','exec'))

parts=[]
for (assembly,key),objects in pieces.items():
    location=objects[0].location.copy();rotation=objects[0].rotation_euler.to_matrix()
    vertices=[];faces=[];frames=[]
    for obj in objects:
        points=[v.co[:] for v in obj.data.vertices];offset=len(vertices);vertices.extend(points)
        spec=catalog[plan['finishes'][key]['catalog_key']]
        grain=stock_grain_frame(points,spec['files'][0]) if plan['finishes'][key]['catalog_key'] in ['wood_dark','timber'] else None
        frames.extend([grain]*len(points));faces.extend(tuple(offset+i for i in f.vertices) for f in obj.data.polygons)
    mesh=bpy.data.meshes.new(assembly+'__'+key);mesh.from_pydata(vertices,[],faces);mesh.update();mesh.materials.append(materials[key])
    bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.triangulate(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
    coords=np.array([v.co[:] for v in mesh.vertices]);idx=np.array([l.vertex_index for l in mesh.loops]).reshape((-1,3));f=[frames[i] for i in idx[:,0]]
    assert np.all(np.linalg.norm(np.cross(coords[idx[:,1]]-coords[idx[:,0]],coords[idx[:,2]]-coords[idx[:,0]]),axis=1)>0),mesh.name
    rotations=np.stack([x[0] if x is not None else np.eye(3) for x in f]);grain=np.array([x is not None and x[1]==0 for x in f])
    ns,us,charts,_=triangle_charts(coords[idx],np.zeros(3),1.,rotations,grain)
    uv=mesh.uv_layers.new(name='Metres');uv.data.foreach_set('uv',charts.astype(np.float32).ravel())
    guide=mesh.attributes.new(name='_tangent_guide',type='FLOAT_VECTOR',domain='CORNER');g=np.repeat(us[:,[0,2,1]],3,axis=0);g[:,2]*=-1;guide.data.foreach_set('vector',g.astype(np.float32).ravel())
    mesh.normals_split_custom_set(stock_corner_normals(mesh))
    obj=bpy.data.objects.new(mesh.name,mesh);exports.objects.link(obj);obj.location=location;obj.rotation_euler=rotation.to_euler()
    finish=plan['finishes'][key];parts.append({'name':obj.name,'assembly':assembly,'triangles':len(mesh.polygons),'key':key,'tile':catalog[finish['catalog_key']]['meters_per_tile'],**finish})
for record in checks:
    obj=bpy.data.objects[record['name']];bm=bmesh.new();bm.from_mesh(obj.data)
    assert all(e.is_manifold for e in bm.edges) and bm.calc_volume(signed=True)>1e-14,obj.name
    record['volume_m3']=bm.calc_volume(signed=True);bm.free()
for image in bpy.data.images:
    if image.source=='FILE':image.filepath=bpy.path.relpath(image.filepath,start=str(ROOT/'art/blender'))
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/bar_furniture.blend'))
bpy.ops.object.select_all(action='DESELECT')
for obj in exports.objects:obj.select_set(True)
class ExportUVHandedness:
    def gather_mesh_hook(self,mesh,blender_data,blender_object,vertex_groups,modifiers,materials,export_settings):
        from io_scene_gltf2.io.exp.binary_data import BinaryData
        from io_scene_gltf2.io.com.constants import BufferViewTarget
        for primitive in mesh.primitives:
            def values(key):return np.frombuffer(primitive.attributes[key].buffer_view.data,dtype='<f4').reshape((-1,3)).astype(float)
            n=values('NORMAL');n/=np.linalg.norm(n,axis=1)[:,None];g=values('_TANGENT_GUIDE');t=g-n*np.sum(g*n,axis=1)[:,None];t/=np.linalg.norm(t,axis=1)[:,None]
            primitive.attributes['TANGENT'].buffer_view=BinaryData(np.column_stack((t,-np.ones(len(t)))).astype('<f4').tobytes(),BufferViewTarget.ARRAY_BUFFER)
            del primitive.attributes['_TANGENT_GUIDE']
import io_scene_gltf2
io_scene_gltf2.glTF2ExportUserExtension=ExportUVHandedness
asset=ROOT/'game/assets/props/bar_furniture.glb'
bpy.ops.export_scene.gltf(filepath=str(asset),export_format='GLB',use_selection=True,export_yup=True,export_tangents=True,export_attributes=True,export_materials='PLACEHOLDER')
exported=validate_export(asset)
runtime={'schema_version':1,'asset':'res://assets/props/bar_furniture.glb','source_records':plan['source_records'],'retirement':plan['retirement'],'parts':parts}
(ROOT/'game/data/orison_v2/bar_furniture.json').write_text(json.dumps(runtime,indent=2)+'\n',newline='\n')
bindings=[PLAN,Path(__file__),ROOT/'art/blender/scripts/bar_furniture_geometry.py',ROOT/'game/data/runtime_material_sets.json',ROOT/'game/assets/building/floor_01_cells/shop_bar.gltf',ROOT/'game/assets/building/floor_01_cells/shop_bar.bin']
bindings.extend(ROOT/'art/blender/scripts'/p for p in ['fabrication_chart_batch.py','fabrication_grain.py','fabrication_normals.py','check_exported_tangents.py'])
bindings.extend(ROOT/'art/blender/scripts'/p for p in ['prepare_bar_furniture.py','inspect_bar_furniture.py','render_bar_furniture.py'])
bindings.extend(ROOT/'game'/p for p in ['scripts/minigames/darts_game.gd','scripts/minigames/trivia_darts.gd','scripts/ui/darts_panel.gd','data/trivia_darts.json','assets/props/bar_furniture.glb.import'])
bindings.extend(ROOT/'game/assets/building/textures'/f for spec in plan['finishes'].values() for f in catalog[spec['catalog_key']]['files'])
report={'evidence_class':'INERT','classification':'ADAPTATION','runtime':runtime,'asset_sha256':digest(asset),'closed_stocks':checks,'contacts':contacts,'joins':joins,'exported_tangents':exported,'source_bindings':{p.relative_to(ROOT).as_posix():digest(p) for p in bindings}}
for p in ['art/blender/bar_furniture_construction.json','game/tests/fixtures/orison_bar_furniture.json']:(ROOT/p).write_text(json.dumps(report,indent=2)+'\n',newline='\n')
print('BAR FURNITURE',len(checks),'closed stocks',len(parts),'partitions;',exported)
