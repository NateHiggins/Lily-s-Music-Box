"""Closed commercial replacement bodies; near geometry retains collision authority."""
from pathlib import Path
import ast,collections,hashlib,json,math,struct,sys
import bpy,bmesh,numpy as np
from mathutils import Vector,Matrix
from mathutils.bvhtree import BVHTree
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
sys.path.insert(0,str(ROOT/'art/blender/scripts'))
from city_commercial_architecture import CommercialFronts
from fabrication_native_batch import material,partition,export

source=ROOT/'art/blender/scripts/build_city_elevations.py'
# These geometry functions belong to the elevation producer. Extract definitions
# explicitly; importing that executable would rebuild the entire high city.
names={'box','local_box','profile_stock','arch_stock','turned_stock','roof_panel','clip_roof_polygon','roof_metric_charts','wood_stock_charts','facade','facade_frames','curtain_panel','retained_facade'}
tree=ast.parse(source.read_text(encoding='utf-8'))
definitions=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in names]
assert {n.name for n in definitions}==names
buffers=collections.defaultdict(lambda:([],[]));stocks=[];roof_samples=[];window_rows=[];portal_rows=[]
def add(name,key,verts,faces):
    vv,ff=buffers[name,key];offset=len(vv);vv.extend(verts);ff.extend(tuple(offset+i for i in f) for f in faces)
    stocks.append((name,key,verts,faces))
exec(compile(ast.Module(body=definitions,type_ignores=[]),str(source),'exec'))
plans=json.loads((ROOT/'art/data/city_elevations/source_plan.json').read_text())
profiles={r['id']:r for r in plans['buildings'] if r.get('architecture',{}).get('type')=='commercial_front'}
assert profiles
records=json.loads((ROOT/'art/blender/city_closure_construction.json').read_text())['original_records']
runtime=json.loads((ROOT/'game/data/orison_v2/exterior/city_elevations.json').read_text())
programme=runtime['body_lod'];assert programme['parts'] and float(programme['error_m'])>0.
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/city_closure.blend'))
original={o.name.removesuffix('__RetainedStock'):o for o in bpy.data.collections['ClosedConstruction'].objects}
rings={o.name.removesuffix('__JoinedParapet'):o for o in bpy.data.collections['ClosedParapets'].objects}
owner=CommercialFronts(profiles,records,original,rings,dict(add=add,box=box,retained_facade=retained_facade,profile_stock=profile_stock,arch_stock=arch_stock,turned_stock=turned_stock,roof_panel=roof_panel,clip_roof_polygon=clip_roof_polygon),detail_level=1)
for identity in profiles:owner.build(identity)
vertices=[];faces=[]
for index,(name,key,vv,ff) in enumerate(stocks):
    mesh=bpy.data.meshes.new('StockProof');mesh.from_pydata(vv,[],ff);mesh.update()
    bm=bmesh.new();bm.from_mesh(mesh)
    assert all(e.is_manifold for e in bm.edges),(index,name,key,'open stock')
    assert bm.calc_volume(signed=True)>1e-10,(index,name,key,'nonpositive stock')
    bm.free();bpy.data.meshes.remove(mesh)
    offset=len(vertices);vertices.extend(vv);faces.extend(tuple(offset+i for i in f) for f in ff)
bvh=BVHTree.FromPolygons(vertices,faces);bearings=0;panes=0
for family in ['masts','aerials','tanks']:
    data=json.loads((ROOT/f'game/tests/fixtures/orison_city_{family}.json').read_text())
    for contact in data['contacts']:
        if not any(contact['owner'].startswith(n+'_') for n in profiles):continue
        normal=Vector(contact['normal'])
        for sample in [contact['point']]+contact['footprint']:
            point=Vector(sample);hit,*_=bvh.ray_cast(point+normal*.03,-normal,.06);bearings+=1
            assert hit is not None and (hit-point).length<.0001,contact['id']
for sample in owner.window_samples:
    point=Vector(sample['point']);normal=Vector(sample['normal']);hit,*_=bvh.ray_cast(point+normal*.1,-normal,.2);panes+=1
    assert hit is not None and (hit-point).length<.0001,sample
raw=(ROOT/'game/assets/props/city_elevations.glb').read_bytes()
doc=json.loads(raw[20:20+struct.unpack_from('<I',raw,12)[0]])
frames={n['name']:n.get('translation',[0,0,0]) for n in doc['nodes'] if 'mesh' in n}
for obj in list(bpy.data.objects):bpy.data.objects.remove(obj,do_unlink=True)
bpy.data.orphans_purge(do_recursive=True)
exports=bpy.data.collections.new('V2CityElevationReplacementBodies');bpy.context.scene.collection.children.link(exports)
catalog=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text())['materials'];parts=[]
for (name,key),(vv,ff) in sorted(buffers.items()):
    profile=profiles[name];tint=profile['wall_tint'] if key==profile['wall_key'] else profile['frame_tint'] if key=='door_paint' else [.18,.23,.25,1] if key=='mirror_aged' else [1,1,1,1]
    finish=dict(catalog_key=key,tint=tint,pigment=1.,normal=.65,roughness=1.)
    if key=='mirror_aged':finish.update(metallic=0.,roughness=.45,normal=.12)
    mat=material(ROOT,name+'__'+key,finish,catalog)
    if key=='mirror_aged':
        bsdf=mat.node_tree.nodes['Principled BSDF'];bsdf.inputs['Alpha'].default_value=.28;bsdf.inputs['Transmission Weight'].default_value=.5;bsdf.inputs['IOR'].default_value=1.52
    identity=name+'__'+key;assert identity in programme['parts'] and identity in frames
    t=frames[identity];center=Vector((t[0],-t[2],t[1]))
    mesh=bpy.data.meshes.new('Raw');mesh.from_pydata(vv,[],ff);mesh.update()
    for v in mesh.vertices:v.co-=center
    # Match the near producer's exact-zero cleanup at its float32 export frame.
    # Retained bevel/parapet stock may contain a triangle that collapses here;
    # source manifold/volume and bearing checks above remain unchanged.
    bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.triangulate(bm,faces=list(bm.faces))
    zero=[f for f in bm.faces if (f.verts[1].co-f.verts[0].co).cross(f.verts[2].co-f.verts[0].co).length_squared==0]
    if zero:bmesh.ops.delete(bm,geom=zero,context='FACES_ONLY')
    bm.to_mesh(mesh);bm.free()
    stock=bpy.data.objects.new('Raw',mesh)
    obj=partition(exports,identity,[stock],finish,mat,Matrix.Translation(center),catalog)
    if key in ['city_slate','city_roof_clay']:roof_metric_charts(obj)
    if name in ['site_ne1','site_nbr_w','site_nbr_e','site_sw2','site_back_w','site_back_e'] and key=='wood_dark':wood_stock_charts(obj,catalog[key]['files'][0])
    bpy.data.objects.remove(stock);bpy.data.meshes.remove(mesh)
    parts.append({'name':identity,'triangles':len(obj.data.polygons),'near_translation_gltf':t})
assert {r['name'] for r in parts}==set(programme['parts'])
proof=export(ROOT,'city_elevations_lod1',exports,staged_output=True)
def sha(path):
    raw=path.read_bytes();return hashlib.sha256(raw.replace(b'\r\n',b'\n') if path.suffix in ['.json','.py','.gd'] else raw).hexdigest()
paths=[Path(__file__),source,ROOT/'art/blender/scripts/city_commercial_architecture.py',ROOT/'art/blender/scripts/fabrication_native_batch.py',ROOT/'art/blender/scripts/fabrication_uvs.py',ROOT/'art/blender/scripts/fabrication_normals.py',ROOT/'art/data/city_elevations/source_plan.json',ROOT/'art/blender/city_closure.blend',ROOT/'art/blender/city_closure_construction.json',ROOT/'game/assets/props/city_elevations.glb',ROOT/'game/data/orison_v2/exterior/city_elevations.json',ROOT/'game/data/runtime_material_sets.json']
paths.extend(ROOT/f'game/tests/fixtures/orison_city_{family}.json' for family in ['masts','aerials','tanks'])
paths.append(ROOT/'art/blender/scripts/frame_mitre_geometry.py')
paths.append(ROOT/'art/blender/scripts/fabrication_grain.py')
paths.extend(ROOT/'game/assets/building/textures'/file for key in {key for name,key in buffers} for file in catalog[key]['files'])
paths.extend(ROOT/p for p in ['game/data/orison_v2/exterior/regions.json','game/data/orison_v2/exterior/exterior_geometry.json'])
report={'evidence_class':'INERT','scope':'Complete closed lower commercial bodies with authored UVs, retained panes/blinds/doors/roofs and original near export frames. Near city meshes retain all collision. No runtime transition, rendering-cost or artistic acceptance.','buildings':owner.building_rows,'parts':parts,'closed_stocks':len(stocks),'bearing_samples':bearings,'pane_samples':panes,'error_m':programme['error_m'],'triangles':sum(r['triangles'] for r in parts),'export_check':proof,'asset_sha256':sha(ROOT/'game/assets/props/city_elevations_lod1.glb'),'source_bindings':{p.relative_to(ROOT).as_posix():sha(p) for p in paths},'failures':[]}
for relative in ['art/blender/city_elevations_lod1_construction.json','game/tests/fixtures/orison_city_elevations_lod1.json']:(ROOT/relative).write_text(json.dumps(report,indent=2)+'\n',newline='\n')
print('CITY COMPLETE BODY LOD',len(parts),report['triangles'],bearings,panes,flush=True)
