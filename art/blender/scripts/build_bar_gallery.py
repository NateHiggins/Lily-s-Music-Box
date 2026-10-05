"""Fabricate source-bound framed prints, seated packers and embedded fixings."""
from pathlib import Path
import collections, hashlib, json, os, sys
import bpy, bmesh
from mathutils import Vector

ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
OUT=Path(os.environ.get('BAR_GALLERY_OUT',str(ROOT))).resolve()
PLAN=ROOT/'art/data/bar_gallery/source_fit.json';plan=json.loads(PLAN.read_bytes())
assert plan['classification']=='ADAPTATION' and len(plan['poses'])==22
def digest(path):
    raw=path.read_bytes()
    return hashlib.sha256(raw if path.suffix in ('.bin','.glb','.png','.blend') else raw.replace(b'\r\n',b'\n')).hexdigest()
for name,expected in plan['bindings'].items():assert digest(ROOT/name)==expected,(name,'source fit needs regeneration')
for folder in ['art/blender','game/assets/props','game/data/orison_v2','game/tests/fixtures']:(OUT/folder).mkdir(parents=True,exist_ok=True)
sys.path.insert(0,str(ROOT/'art/blender/scripts'))
from fabrication_uvs import chart_for_triangle
sets=json.loads((ROOT/'game/data/runtime_material_sets.json').read_bytes())['materials']
layout=json.loads((ROOT/'art/data/building_layout.json').read_bytes());floor=next(f for f in layout['floors'] if f['id']==plan['source_floor'])
rows={r['id']:r for r in floor['furniture']};m=plan['manufacture']
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
bpy.ops.import_scene.gltf(filepath=str(ROOT/'game/assets/building/floor_01_cells/shop_bar.gltf'))
context=list(bpy.context.scene.objects)
art_owner=next(o for o in context if o.type=='MESH' and o.name.endswith('furniture_art'))
assert len(art_owner.data.polygons)==88
materials={}
for key in ['art','wood_dark','paper']:
    owner=next(o for o in context if o.type=='MESH' and o.name.removesuffix('-col').endswith(('furniture_' if key in ['art','wood_dark'] else 'retail_bar_')+key))
    materials[key]=owner.data.materials[0]
    if key!='art':
        coord=materials[key].node_tree.nodes.new('ShaderNodeTexCoord');scale=materials[key].node_tree.nodes.new('ShaderNodeVectorMath');scale.operation='SCALE';scale.inputs['Scale'].default_value=1/sets[key]['meters_per_tile']
        materials[key].node_tree.links.new(coord.outputs['UV'],scale.inputs[0])
        for tex in materials[key].node_tree.nodes:
            if tex.type=='TEX_IMAGE':materials[key].node_tree.links.new(scale.outputs['Vector'],tex.inputs['Vector'])
materials['iron_blackened']=bpy.data.materials.new('M_iron_blackened');materials['iron_blackened'].use_nodes=True
spec=sets['iron_blackened'];node=materials['iron_blackened'].node_tree.nodes['Principled BSDF'];node.inputs['Metallic'].default_value=spec['metallic']
coord=materials['iron_blackened'].node_tree.nodes.new('ShaderNodeTexCoord');scale=materials['iron_blackened'].node_tree.nodes.new('ShaderNodeVectorMath');scale.operation='SCALE';scale.inputs['Scale'].default_value=1/spec['meters_per_tile']
materials['iron_blackened'].node_tree.links.new(coord.outputs['UV'],scale.inputs[0])
for index,target in enumerate(['Base Color','Roughness','Normal']):
    image=bpy.data.images.load(str(ROOT/'game/assets/building/textures'/spec['files'][index]),check_existing=True)
    tex=materials['iron_blackened'].node_tree.nodes.new('ShaderNodeTexImage');tex.image=image
    if index:image.colorspace_settings.name='Non-Color'
    materials['iron_blackened'].node_tree.links.new(scale.outputs['Vector'],tex.inputs['Vector'])
    if index==2:
        normal=materials['iron_blackened'].node_tree.nodes.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.35;materials['iron_blackened'].node_tree.links.new(tex.outputs['Color'],normal.inputs['Color']);materials['iron_blackened'].node_tree.links.new(normal.outputs[0],node.inputs[target])
    else:materials['iron_blackened'].node_tree.links.new(tex.outputs['Color'],node.inputs[target])
stocks=[];groups=collections.defaultdict(list);contacts=[];stock_checks=[];pictures=[]
construction=bpy.data.collections.new('EditableGalleryStocks');bpy.context.scene.collection.children.link(construction)
def finish(obj,name,key,closed=True):
    obj.name=name
    for collection in list(obj.users_collection):collection.objects.unlink(obj)
    construction.objects.link(obj);obj.data.materials.clear();obj.data.materials.append(materials[key]);stocks.append(obj);groups[key].append(obj)
    if closed:
        bm=bmesh.new();bm.from_mesh(obj.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-7);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
        assert all(e.is_manifold for e in bm.edges) and bm.calc_volume(signed=True)>0,name
        stock_checks.append({'name':name,'volume_m3':bm.calc_volume(signed=True),'nonmanifold_edges':0});bm.to_mesh(obj.data);bm.free()
    return obj
def box(name,centre,u,n,width,height,depth,key,bevel=0.):
    bpy.ops.mesh.primitive_cube_add(size=1,location=centre);obj=bpy.context.object
    obj.dimensions=(width,height,depth);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    # The horizontal tangent, vertical axis and inward normal form a right-handed basis.
    from mathutils import Matrix
    obj.rotation_euler=Matrix((u,Vector((0,0,1)),n)).transposed().to_euler();bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
    if bevel:
        mod=obj.modifiers.new('Worked frame edges','BEVEL');mod.width=bevel;mod.segments=1;bpy.ops.object.modifier_apply(modifier=mod.name)
    return finish(obj,name,key)
def pin(name,a,b,r):
    a,b=Vector(a),Vector(b);d=b-a
    bpy.ops.mesh.primitive_cylinder_add(vertices=16,radius=r,depth=d.length,location=(a+b)*.5);obj=bpy.context.object;obj.rotation_euler=d.to_track_quat('Z','Y').to_euler();bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
    return finish(obj,name,'iron_blackened')
def front_source(row):
    r=row['rect'];north=r[2]-r[0]>r[3]-r[1];axis=1 if north else 0;plane=r[1]-.004 if north else r[2]+.004
    faces=[]
    for face in art_owner.data.polygons:
        points=[art_owner.matrix_world@art_owner.data.vertices[i].co for i in face.vertices]
        if not all(abs(p[axis]-plane)<.00003 and r[0]-.00403<=p.x<=r[2]+.00403 and r[1]-.00403<=p.y<=r[3]+.00403 and row['z0']-.00003<=p.z<=row['z0']+row['h']+.00003 for p in points):continue
        faces.append((points,[tuple(art_owner.data.uv_layers.active.data[i].uv) for i in face.loop_indices]))
    assert len(faces)==2,(row['id'],len(faces))
    return faces,north
for pose in plan['poses']:
    row=rows[pose['id']];assert row==pose['source'];r=row['rect'];width=max(r[2]-r[0],r[3]-r[1]);height=row['h']
    n=Vector((0,-1,0)) if pose['wall']=='north' else Vector((1,0,0));u=Vector((1,0,0)) if pose['wall']=='north' else Vector((0,1,0));at=Vector((pose['x'],pose['y'],pose['height']))
    original_depth=min(r[2]-r[0],r[3]-r[1]);frame_depth=original_depth+.004
    bearing=Vector((at.x,rows['retail_bar_wall_n']['rect'][1],at.z)) if pose['wall']=='north' else Vector((rows['retail_bar_wall_w']['rect'][2],at.y,at.z))
    gap=(at-bearing).dot(n)-frame_depth;assert .001<gap<.020,(row['id'],gap)
    box(row['id']+'_Frame',at-n*(frame_depth*.5+m['print_thickness_m']),u,n,width,height,frame_depth,'wood_dark',.0008)
    # Preserve the original atlas cell and its point-to-UV correspondence;
    # the whole original image fits within a narrow dark frame border.
    source_faces,source_north=front_source(row);old_u=Vector((1,0,0)) if source_north else Vector((0,1,0));old_c=Vector(((r[0]+r[2])*.5,(r[1]+r[3])*.5,row['z0']+height*.5))
    vertices=[];triangles=[];uvs=[]
    for points,chart in source_faces:
        if source_north:points.reverse();chart.reverse()
        offset=len(vertices)
        for point,value in zip(points,chart):
            relative=point-old_c;vertices.append(at+u*relative.dot(old_u)*(width-2*m['border_m'])/width+Vector((0,0,relative.z*(height-2*m['border_m'])/height)));uvs.append(value)
        triangles.append(tuple(range(offset,offset+3)))
    mesh=bpy.data.meshes.new(row['id']+'_Image');mesh.from_pydata(vertices,[],triangles);mesh.update();uv=mesh.uv_layers.new(name='OriginalAtlasCell');uv.active_render=True
    for face in mesh.polygons:
        assert face.normal.dot(n)>.999,row['id']
        for loop in face.loop_indices:uv.data[loop].uv=uvs[mesh.loops[loop].vertex_index]
    obj=bpy.data.objects.new(mesh.name,mesh);bpy.context.scene.collection.objects.link(obj);finish(obj,mesh.name,'art',False)
    body=box(row['id']+'_PrintBody',at-n*m['print_thickness_m']*.5,u,n,width-2*m['border_m'],height-2*m['border_m'],m['print_thickness_m'],'paper')
    # Remove the coincident generic-paper front; the retained atlas face owns it.
    export_body=body.copy();export_body.data=body.data.copy();export_body.name=body.name+'_MaterialPartition';construction.objects.link(export_body);groups['paper'][-1]=export_body
    bm=bmesh.new();bm.from_mesh(export_body.data);front=[f for f in bm.faces if f.normal.dot(n)>.999];assert len(front)==1;bmesh.ops.delete(bm,geom=front,context='FACES');bm.to_mesh(export_body.data);bm.free()
    for index,(du,dz) in enumerate([(-width*.5+.05,height*.5-.035),(width*.5-.05,height*.5-.035),(0.,-height*.5+.035)]):
        wall=bearing+u*du+Vector((0,0,dz));packer_front=wall+n*(gap-m['print_thickness_m'])
        box(row['id']+'_Packer'+str(index),(wall+packer_front)*.5,u,n,m['packer_width_m'],m['packer_height_m'],(packer_front-wall).length,'wood_dark')
        pin(row['id']+'_Fixing'+str(index),wall-n*m['pin_embed_m'],packer_front+n*.003,m['pin_radius_m'])
        pin(row['id']+'_FixingHead'+str(index),packer_front-n*.0008,packer_front+n*.0002,.003)
        contacts.append({'picture':row['id'],'bearing':list(wall),'normal':list(n),'frame_back':list(packer_front),'gap_m':(packer_front-wall).length,'wall_owner':'F01_OWN_SHOP_BAR_retail_bar_bar_wall','packer_width_m':m['packer_width_m'],'packer_height_m':m['packer_height_m']})
    pictures.append({'id':row['id'],'source':row,'wall':pose['wall'],'position':list(at),'yaw':pose['yaw']})
# Original context is a fitting instrument only; production retains that owner.
for obj in context:bpy.data.objects.remove(obj,do_unlink=True)
bpy.ops.outliner.orphans_purge(do_local_ids=True,do_linked_ids=True,do_recursive=True)
parts=[];inventory=[];fallbacks=0
for key,objects in sorted(groups.items()):
    vertices=[];triangles=[];charts=[]
    for obj in objects:
        obj.data.calc_loop_triangles();offset=len(vertices);vertices.extend(obj.matrix_world@v.co for v in obj.data.vertices)
        for tri in obj.data.loop_triangles:
            triangles.append(tuple(offset+i for i in tri.vertices))
            if key=='art':charts.append([tuple(obj.data.uv_layers.active.data[i].uv) for i in tri.loops])
    mesh=bpy.data.meshes.new('Gallery__'+key);mesh.from_pydata(vertices,[],triangles);mesh.update();uv=mesh.uv_layers.new(name='OriginalAtlasCell' if key=='art' else 'Metres');uv.active_render=True
    for index,face in enumerate(mesh.polygons):
        if key=='art':values=charts[index]
        else:
            points=[mesh.vertices[mesh.loops[i].vertex_index].co for i in face.loop_indices];_,_,values,fallback=chart_for_triangle(points,Vector((0,0,0)),sets[key]['meters_per_tile']);fallbacks+=fallback
        for loop,value in zip(face.loop_indices,values):uv.data[loop].uv=value
    obj=bpy.data.objects.new(mesh.name,mesh);bpy.context.scene.collection.objects.link(obj);mesh.materials.append(materials[key]);parts.append(obj)
    inventory.append({'name':mesh.name,'key':key,'tile':1. if key=='art' else sets[key]['meters_per_tile'],'triangles':len(triangles),'collision':key in ['wood_dark','iron_blackened']})
construction.hide_render=True
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'art/blender/bar_gallery.blend'),compress=True)
bpy.ops.object.select_all(action='DESELECT')
for obj in parts:obj.select_set(True)
class ExportUVHandedness:
    def gather_attribute_change(self,attribute,data,normalized,export_settings):
        if attribute=='TANGENT':data['data'][:,3]*=-1
import io_scene_gltf2;io_scene_gltf2.glTF2ExportUserExtension=ExportUVHandedness
asset=OUT/'game/assets/props/bar_gallery.glb'
bpy.ops.export_scene.gltf(filepath=str(asset),export_format='GLB',use_selection=True,export_yup=True,export_tangents=True,export_materials='NONE')
runtime={'schema_version':1,'asset':'res://assets/props/bar_gallery.glb','pictures':pictures,'parts':[{k:p[k] for k in ['name','key','tile','collision']} for p in inventory],
    'inspectors':[{k:i[k] for k in ['zone','picture']} for i in plan['inspectors']]}
(OUT/'game/data/orison_v2/bar_gallery.json').write_text(json.dumps(runtime,indent=2)+'\n',newline='\n')
bindings=[PLAN,Path(__file__),ROOT/'art/blender/scripts/fabrication_uvs.py',ROOT/'art/data/material_catalog.json',ROOT/'game/data/runtime_material_sets.json']
fixture={'evidence_class':'INERT','asset_sha256':digest(asset),'parts':inventory,'pictures':pictures,'contacts':contacts,'stock_checks':stock_checks,'uv_fallbacks':fallbacks,
    'retired_partitions':{'art':88,'wood_dark':264},'original_inspectors':plan['inspectors'],'source_bindings':{p.relative_to(ROOT).as_posix():digest(p) for p in bindings},'retained_bindings':plan['bindings']}
(OUT/'game/tests/fixtures/orison_bar_gallery.json').write_text(json.dumps(fixture,indent=2)+'\n',newline='\n')
(OUT/'art/blender/bar_gallery_inventory.json').write_text(json.dumps({'classification':'ADAPTATION','stocks':stock_checks,'parts':inventory,'contacts':contacts,'uv_fallbacks':fallbacks},indent=2)+'\n',newline='\n')
print('BAR GALLERY:',len(pictures),'pictures;',len(parts),'batched partitions;',len(contacts),'wall/frame contacts;',len(stock_checks),'positive closed construction stocks')
