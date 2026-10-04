"""Source-fitted Harukiya fixture mounts; retained actors keep all authority."""
from pathlib import Path
import collections, hashlib, json, math, os, sys
import bpy, bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree
root=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
plan_path=root/'art/data/bar_fixture_mounts/source_plan.json';plan=json.loads(plan_path.read_text())
assert plan['classification']=='ADAPTATION'
out=Path(os.environ.get('BAR_FIXTURE_OUT',str(root))).resolve()
for folder in ['art/blender','game/assets/props','game/data/orison_v2','game/tests/fixtures']:(out/folder).mkdir(parents=True,exist_ok=True)
def digest(path):
    data=path.read_bytes();return hashlib.sha256(data if path.suffix in ['.blend','.glb','.png','.bin'] else data.replace(b'\r\n',b'\n')).hexdigest()
def godot(value):return [value[0],value[2],-value[1]]
sys.path.insert(0,str(root/'art/blender/scripts'))
from fabrication_uvs import chart_for_triangle
layout=json.loads((root/'art/data/building_layout.json').read_text());floor=next(x for x in layout['floors'] if x['id']==plan['source_floor'])
rows={r['id']:r for r in floor['furniture']};markers=[r for r in floor['markers'] if r['id'].startswith(plan['marker_prefix'])]
sets=json.loads((root/'game/data/runtime_material_sets.json').read_text())['materials']
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
bpy.ops.import_scene.gltf(filepath=str(root/'game/assets/building/floor_01_cells/shop_bar.gltf'))
context=bpy.data.collections.new('ReadOnlyRetainedContext');bpy.context.scene.collection.children.link(context)
vertices=[];faces=[];owners=[]
for obj in list(bpy.context.scene.objects):
    for c in list(obj.users_collection):c.objects.unlink(obj)
    context.objects.link(obj)
    if obj.type!='MESH':continue
    if not any(key in obj.name for key in ['retail_bar_soot','retail_bar_bar_wall','retail_bar_stairwell_teal','retail_bar_common_brick','retail_bar_plaster_stained','retail_bar_fabric_warm','furnish_rubber_aged']):continue
    offset=len(vertices);vertices.extend(obj.matrix_world@v.co for v in obj.data.vertices)
    for face in obj.data.polygons:faces.append(tuple(offset+i for i in face.vertices));owners.append(obj.name)
tree=BVHTree.FromPolygons(vertices,faces,all_triangles=False)
construction=bpy.data.collections.new('FittedFixtureConstruction');bpy.context.scene.collection.children.link(construction)
materials={}
for key in plan['runtime_keys']:
    material=bpy.data.materials.new(key);material.use_nodes=True;spec=sets[key];node=material.node_tree.nodes['Principled BSDF']
    node.inputs['Metallic'].default_value=spec['metallic'];coord=material.node_tree.nodes.new('ShaderNodeTexCoord')
    scale=material.node_tree.nodes.new('ShaderNodeVectorMath');scale.operation='SCALE';scale.inputs['Scale'].default_value=1/spec['meters_per_tile'];material.node_tree.links.new(coord.outputs['UV'],scale.inputs[0])
    for i,target in enumerate(['Base Color','Roughness','Normal']):
        image=bpy.data.images.load(str(root/'game/assets/building/textures'/spec['files'][i]),check_existing=True)
        tex=material.node_tree.nodes.new('ShaderNodeTexImage');tex.image=image
        if i:image.colorspace_settings.name='Non-Color'
        material.node_tree.links.new(scale.outputs['Vector'],tex.inputs['Vector'])
        if i==2:
            normal=material.node_tree.nodes.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.35
            material.node_tree.links.new(tex.outputs['Color'],normal.inputs['Color']);material.node_tree.links.new(normal.outputs[0],node.inputs[target])
        else:material.node_tree.links.new(tex.outputs['Color'],node.inputs[target])
    materials[key]=material
stocks=[];groups=collections.defaultdict(list);contacts=[];original_rods=[];stock_checks=[]
def finish(obj,name,key,group):
    obj.name=name
    for c in list(obj.users_collection):c.objects.unlink(obj)
    construction.objects.link(obj);obj.data.materials.append(materials[key]);obj['assembly']=group;obj['key']=key
    bm=bmesh.new();bm.from_mesh(obj.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));assert all(e.is_manifold for e in bm.edges) and bm.calc_volume(signed=True)>0,name
    stock_checks.append({'name':name,'assembly':group,'key':key,'nonmanifold_edges':sum(not e.is_manifold for e in bm.edges),'volume_m3':bm.calc_volume(signed=True)})
    bm.to_mesh(obj.data);bm.free();stocks.append(obj);groups[(group,key)].append(obj);return obj
def cylinder(name,a,b,r,key,group):
    a,b=Vector(a),Vector(b);direction=b-a;assert direction.length>.0001
    bpy.ops.mesh.primitive_cylinder_add(vertices=24,radius=r,depth=direction.length,location=(a+b)*.5)
    obj=bpy.context.object;obj.rotation_euler=direction.to_track_quat('Z','Y').to_euler();bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
    return finish(obj,name,key,group)
def plate(name,center,normal,width,height,depth,key,group):
    normal=Vector(normal).normalized();bpy.ops.mesh.primitive_cube_add(size=1,location=center)
    obj=bpy.context.object;obj.dimensions=(width,height,depth);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    obj.rotation_euler=normal.to_track_quat('Z','Y').to_euler();bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
    mod=obj.modifiers.new('Worked arris','BEVEL');mod.width=.0006;mod.segments=1;bpy.ops.object.modifier_apply(modifier=mod.name)
    return finish(obj,name,key,group)
def fit(identity,start,direction,flex=False):
    start=Vector(start);direction=Vector(direction).normalized()
    hit,normal,index,distance=tree.ray_cast(start+direction*.002,direction,5.)
    assert hit is not None,(identity,'missing original bearing')
    span=(hit-start).dot(direction);assert span>.01,(identity,span)
    assert normal.dot(direction)<-.99,(identity,normal,direction)
    cylinder(identity+'_Stem',start+direction*.012,hit-direction*.004,plan['flex_radius_m'] if flex else plan['stem_radius_m'],'rubber_aged' if flex else 'iron_blackened',identity)
    cylinder(identity+'_LowerCollar',start,start+direction*.018,.012,'brass_dull',identity)
    cylinder(identity+'_UpperCollar',hit-direction*.016,hit-direction*.004,.016,'iron_blackened',identity)
    plate(identity+'_BearingPlate',hit-direction*plan['bearing_plate_thickness_m']*.5,direction,plan['bearing_plate_m'],plan['bearing_plate_m'],plan['bearing_plate_thickness_m'],'iron_blackened',identity)
    seed=Vector((1,0,0)) if abs(direction.z)>.9 else Vector((0,0,1));other=direction.cross(seed)
    for i in range(4):
        angle=math.pi*.25+i*math.pi*.5;at=hit+seed*.037*math.cos(angle)+other*.037*math.sin(angle)
        cylinder(identity+'_Fixing'+str(i),at-direction*.007,at-direction*.004,.003,'brass_dull',identity)
    contacts.append({'id':identity,'fixture_endpoint':list(start),'bearing':list(hit),'direction':list(direction),'gap':span,'owner':owners[index]})
for marker in markers:
    at=Vector(marker['pos']);identity=marker['id'];kind=marker['kind']
    if kind=='sconce_globe':
        yaw=math.radians(marker['yaw_deg']);direction=Vector((-math.sin(yaw),math.cos(yaw),0));at+=direction*plan['sconce_rear_face_m']
        if identity in ['F01_BAR_LT_WEST0','F01_BAR_LT_WEST1']:
            # Keep the original globe station. The gallery and dart board are
            # decorations, never structural bearings. Carry the back of the
            # fitting upward in free space to the clear wall above them.
            upper=Vector((at.x,at.y,plan['west_clear_wall_height_m']))
            cylinder(identity+'_OffsetRiser',at+Vector((0,0,.012)),upper,plan['stem_radius_m'],'iron_blackened',identity)
            cylinder(identity+'_RiserFoot',at,at+Vector((0,0,.018)),.012,'brass_dull',identity)
            cylinder(identity+'_RiserHead',upper-Vector((0,0,.018)),upper+Vector((0,0,.008)),.013,'iron_blackened',identity)
            fit(identity,upper,direction)
            contacts[-1]['original_fixture_endpoint']=list(at)
            contacts[-1]['free_offset_riser']=[list(at),list(upper)]
            assert 'bar_wall' in contacts[-1]['owner'],contacts[-1]
        else:fit(identity,at,direction)
    elif identity in ['F01_BAR_LT_TAB1','F01_BAR_LT_TAB2']:
        rod=rows['retail_bar_tabrod'+identity[-1]];assert rod['id'] in plan['retained_rods'] and (Vector(rod['p1'])-at).length<.00001
        original_rods.append({'marker':marker,'rod':rod})
    elif identity=='F01_BAR_LT_WELL':
        direction=Vector((0,0,1));flex=rows[plan['inline_flex']];hit=Vector(flex['p1'])
        assert abs(hit.x-at.x)<.00001 and abs(hit.y-at.y)<.00001 and (hit-at).z>.02
        cylinder(identity+'_InlineFlex',at+direction*.010,hit-direction*.006,plan['flex_radius_m'],'rubber_aged',identity)
        cylinder(identity+'_LowerStrainRelief',at,at+direction*.014,.012,'brass_dull',identity)
        cylinder(identity+'_UpperStrainRelief',hit-direction*.014,hit+direction*.006,.012,'brass_dull',identity)
        contacts.append({'id':identity,'fixture_endpoint':list(at),'bearing':list(hit),'direction':list(direction),'gap':(hit-at).z,'owner':'F01_OWN_SHOP_BAR_furnish_rubber_aged','inline_source':flex,'bearing_radius_m':plan['flex_radius_m']})
    else:fit(identity,at,(0,0,1),kind=='cage_bulb')
canopy=rows[plan['canopy']];a,b,c,d=canopy['rect'];height=canopy['z0']+canopy['h']
for i,(x,y) in enumerate([(a+plan['canopy_stay_inset_m'],b+plan['canopy_stay_inset_m']),(a+plan['canopy_stay_inset_m'],d-plan['canopy_stay_inset_m']),(c-plan['canopy_stay_inset_m'],b+plan['canopy_stay_inset_m']),(c-plan['canopy_stay_inset_m'],d-plan['canopy_stay_inset_m'])]):fit('CanopyStay'+str(i),(x,y,height),(0,0,1))
parts=[];inventory=[];fallbacks=0;total_triangles=0
for (group,key),objects in sorted(groups.items()):
    vertices=[];triangles=[]
    for obj in objects:
        obj.data.calc_loop_triangles();offset=len(vertices);vertices.extend(obj.matrix_world@v.co for v in obj.data.vertices)
        triangles.extend(tuple(offset+i for i in tri.vertices) for tri in obj.data.loop_triangles)
    origin=Vector(tuple(round(sum(v[i] for v in vertices)/len(vertices),3) for i in range(3)))
    mesh=bpy.data.meshes.new(group+'__'+key);mesh.from_pydata([v-origin for v in vertices],[],triangles);mesh.update()
    uv=mesh.uv_layers.new(name='Metres');uv.active_render=True
    for face in mesh.polygons:
        points=[mesh.vertices[mesh.loops[i].vertex_index].co for i in face.loop_indices]
        n,u,values,fallback=chart_for_triangle(points,origin,sets[key]['meters_per_tile']);fallbacks+=fallback
        for loop,value in zip(face.loop_indices,values):uv.data[loop].uv=value
    obj=bpy.data.objects.new(mesh.name,mesh);bpy.context.scene.collection.objects.link(obj);obj.location=origin;mesh.materials.append(materials[key]);parts.append(obj)
    total_triangles+=len(triangles);inventory.append({'name':mesh.name,'assembly':group,'key':key,'tile':sets[key]['meters_per_tile'],'triangles':len(triangles)})
construction.hide_render=True
# Imported context is a read-only fitting instrument, never duplicated in the shipped native.
for obj in list(context.objects):bpy.data.objects.remove(obj,do_unlink=True)
bpy.data.collections.remove(context)
# Discard orphaned imported meshes/materials/images; the editable stocks keep
# their own three catalogue materials and real external shipping maps.
bpy.ops.outliner.orphans_purge(do_local_ids=True,do_linked_ids=True,do_recursive=True)
native=out/'art/blender/bar_fixture_mounts.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(native),compress=True)
bpy.ops.object.select_all(action='DESELECT')
for obj in parts:obj.select_set(True)
class ExportUVHandedness:
    def gather_attribute_change(self,attribute,data,normalized,export_settings):
        if attribute=='TANGENT':data['data'][:,3]*=-1
import io_scene_gltf2
io_scene_gltf2.glTF2ExportUserExtension=ExportUVHandedness
bpy.ops.export_scene.gltf(filepath=str(out/'game/assets/props/bar_fixture_mounts.glb'),export_format='GLB',use_selection=True,export_yup=True,export_tangents=True,export_materials='PLACEHOLDER')
runtime={'schema_version':1,'asset':'res://assets/props/bar_fixture_mounts.glb','parts':[{k:row[k] for k in ['name','key','tile']} for row in inventory]}
(out/'game/data/orison_v2/bar_fixture_mounts.json').write_text(json.dumps(runtime,indent=2)+'\n',newline='\n')
bindings=[plan_path,root/'art/data/building_layout.json',Path(__file__),root/'art/blender/scripts/fabrication_uvs.py',root/'art/data/material_catalog.json',root/'game/data/runtime_material_sets.json',root/'game/assets/building/floor_01_cells/shop_bar.gltf',root/'game/assets/building/floor_01_cells/shop_bar.bin',root/'game/scripts/props/light_fixture_prop.gd',root/'game/assets/props/bar_fixture_mounts.glb.import',root/'game/assets/building/floor_01_cells/shop_bar.gltf.import']
for key in plan['runtime_keys']:bindings.extend(root/'game/assets/building/textures'/name for name in sets[key]['files'])
report={'evidence_class':'INERT','classification':'ADAPTATION','original_markers':markers,'retained_rods':original_rods,'closed_stocks':stock_checks,'parts':inventory,'triangles':total_triangles,'contacts':[{**row,'fixture_endpoint':godot(row['fixture_endpoint']),'bearing':godot(row['bearing']),'direction':godot(row['direction']),**({'original_fixture_endpoint':godot(row['original_fixture_endpoint']),'free_offset_riser':[godot(x) for x in row['free_offset_riser']]} if 'free_offset_riser' in row else {})} for row in contacts],'runtime':runtime,'precision_chart_fallbacks':fallbacks,'native_sha256':digest(native),'asset_sha256':digest(out/'game/assets/props/bar_fixture_mounts.glb'),'source_bindings':{path.relative_to(root).as_posix():digest(path) for path in bindings},'open_work':plan['open_work']}
for path in ['art/blender/bar_fixture_mounts_construction.json','game/tests/fixtures/orison_bar_fixture_mounts.json']:(out/path).write_text(json.dumps(report,indent=2)+'\n',newline='\n')
print('BAR FIXTURE MOUNTS:',len(stocks),'closed stocks;',len(contacts),'fitted supports;',len(original_rods),'original rods retained;',len(parts),'parts;',total_triangles,'triangles',flush=True)
