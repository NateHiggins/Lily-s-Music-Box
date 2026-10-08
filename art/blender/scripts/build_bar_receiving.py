"""Fit existing native receiver stock to the two bar actors, never clone actors."""
from pathlib import Path
import bpy,bmesh,collections,hashlib,json,math,sys
from mathutils import Matrix,Vector
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file());sys.path.insert(0,str(ROOT/'art/blender/scripts'))
from fabrication_native_batch import material,partition,export
PLAN=ROOT/'art/data/bar_receiving/source_plan.json';plan=json.loads(PLAN.read_text(encoding='utf-8'))
catalog=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text(encoding='utf-8'))['materials']
def digest(path):
    data=path.read_bytes();return hashlib.sha256(data if path.suffix in ['.blend','.glb','.bin','.png'] else data.replace(b'\r\n',b'\n')).hexdigest()
def frame(row):return Matrix.Translation(Vector([*row['at'],row.get('z0',0)]))@Matrix.Rotation(math.radians(row['yaw']),4,'Z')
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
stocks=bpy.data.collections.new('ClosedConstruction');bpy.context.scene.collection.children.link(stocks);stocks.hide_render=True
exports=bpy.data.collections.new('RuntimePartitions');bpy.context.scene.collection.children.link(exports)
finishes={}
for key in ['bakelite','bakelite_black','brass_dull','enamel_appliance','milk_glass','paper','fabric_warm','copper_aged','iron_blackened']:
    finishes[key]={'catalog_key':key,'tint':[.72,.70,.67,1.],'normal':.025,'roughness':.6,'pigment':.30}
finishes['bakelite'].update(tint=[.42,.37,.33,1.],roughness=.48,pigment=.20)
finishes['bakelite_black'].update(tint=[.56,.56,.54,1.],roughness=.38,pigment=.22)
finishes['brass_dull'].update(tint=[.68,.62,.52,1.],roughness=.48,pigment=.32)
finishes['fabric_warm'].update(normal=.10,roughness=.84,pigment=.65)
finishes['paper'].update(tint=[.81,.78,.70,1.],normal=.01,roughness=.90,pigment=.12)
finishes['milk_glass'].update(normal=.007,roughness=.3,pigment=.04)
materials={k:material(ROOT,k,f,catalog) for k,f in finishes.items()}
pieces=collections.defaultdict(list);checks=[];contacts=[];frames={};source_hashes={}
floor_top=plan['floor']['z0']+plan['floor']['h']
for spec in plan['native_sources']:
    family=spec['family'];source_file=ROOT/'art/blender'/f'{family}.blend';report_file=ROOT/'art/blender'/f'{family}_construction.json'
    report=json.loads(report_file.read_text(encoding='utf-8'));source=next(r for r in report['original_records'] if r['id']==spec['source']);target=next(r for r in plan['source_records'] if r['id']==spec['target']);identity=target['id'];frames[identity]=frame(target)
    by_name={r['name']:r for r in report['closed_stocks'] if r['assembly']==source['id']}
    with bpy.data.libraries.load(str(source_file),link=False) as (src,dst):dst.objects=list(by_name)
    assert len(dst.objects)==len(by_name) and all(dst.objects)
    for obj in dst.objects:stocks.objects.link(obj)
    bpy.context.view_layer.update()
    for obj in dst.objects:
        old=obj.name;record=by_name[old];key=record['key'];transform=frame(source).inverted()@obj.matrix_world
        obj.data.transform(transform);obj.name=old.replace(source['id'],identity);obj.matrix_world=frames[identity];obj.hide_render=False
        if '_FloorFoot' in obj.name:
            key='iron_blackened'
            for vertex in obj.data.vertices:vertex.co.z=(vertex.co.z-.01)/(.085-.01)*(.085-(floor_top-target['z0']))+(floor_top-target['z0'])
            center=Vector((sum(v.co.x for v in obj.data.vertices)/len(obj.data.vertices),sum(v.co.y for v in obj.data.vertices)/len(obj.data.vertices),floor_top-target['z0']))
            at=frames[identity]@center;contacts.append({'assembly':identity,'point':[at.x,at.z,-at.y],'normal':[0,1,0],'owner':plan['floor']['id']})
        obj.data.materials.clear();obj.data.materials.append(materials[key]);pieces[(identity,key)].append(obj)
        checks.append({'name':obj.name,'assembly':identity,'key':key,'source':old})
    source_hashes[source_file]=digest(source_file);source_hashes[report_file]=digest(report_file)
    # Foot discs spread the extended posts on the retained tile. Original
    # cabinet height/scope and actor transforms are unchanged.
    for i,(x,y) in enumerate((x,y) for x in [-.27,.27] for y in [-.30,.30]):
        n=48;z=floor_top-target['z0'];vertices=[(x+.045*math.cos(j*math.tau/n),y+.045*math.sin(j*math.tau/n),zz) for zz in [z,z+.012] for j in range(n)]
        faces=[tuple(reversed(range(n)))]+[(j,(j+1)%n,n+(j+1)%n,n+j) for j in range(n)]+[tuple(range(n,2*n))]
        mesh=bpy.data.meshes.new(identity+'_FootPad'+str(i));mesh.from_pydata(vertices,[],faces);mesh.update();mesh.materials.append(materials['iron_blackened'])
        obj=bpy.data.objects.new(mesh.name,mesh);stocks.objects.link(obj);obj.matrix_world=frames[identity];pieces[(identity,'iron_blackened')].append(obj)
        checks.append({'name':obj.name,'assembly':identity,'key':'iron_blackened','source':'new fitted floor pad'})
for record in checks:
    obj=bpy.data.objects[record['name']];bm=bmesh.new();bm.from_mesh(obj.data)
    assert all(e.is_manifold for e in bm.edges),obj.name
    volume=bm.calc_volume(signed=True);assert volume>1e-12,obj.name;record['volume_m3']=volume;bm.free()
parts=[]
for (identity,key),objects in pieces.items():
    finish=finishes[key];obj=partition(exports,identity+'__'+key,objects,finish,materials[key],frames[identity],catalog)
    parts.append({'name':obj.name,'assembly':identity,'key':key,'triangles':len(obj.data.polygons),'tile':catalog[key]['meters_per_tile'],**finish})
exported=export(ROOT,'bar_receiving',exports)
runtime={'schema_version':1,'asset':'res://assets/props/bar_receiving.glb','source_records':plan['source_records'],'floor':plan['floor'],'retirement':plan['retirement'],'parts':parts}
(ROOT/'game/data/orison_v2/bar_receiving.json').write_text(json.dumps(runtime,indent=2)+'\n',encoding='utf-8',newline='\n')
bindings=[PLAN,Path(__file__),ROOT/'game/data/runtime_material_sets.json',ROOT/'game/assets/building/floor_01_cells/shop_bar.gltf',ROOT/'game/assets/building/floor_01_cells/shop_bar.bin']
bindings.extend(ROOT/'art/blender/scripts'/name for name in ['prepare_bar_receiving.py','inspect_bar_receiving.py','fabrication_native_batch.py','fabrication_chart_batch.py','fabrication_grain.py','fabrication_normals.py','check_exported_tangents.py'])
bindings.extend(ROOT/'game/assets/building/textures'/file for key in finishes for file in catalog[key]['files'])
bindings.extend([*source_hashes,ROOT/'game/assets/props/bar_receiving.glb.import'])
report={'evidence_class':'INERT','classification':'ADAPTATION','runtime':runtime,'asset_sha256':digest(ROOT/'game/assets/props/bar_receiving.glb'),'closed_stocks':checks,'contacts':contacts,'exported_tangents':exported,'source_bindings':{p.relative_to(ROOT).as_posix():digest(p) for p in bindings}}
for name in ['art/blender/bar_receiving_construction.json','game/tests/fixtures/orison_bar_receiving.json']:(ROOT/name).write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8',newline='\n')
print('BAR RECEIVING',len(checks),'closed stocks',len(parts),'partitions',exported)
