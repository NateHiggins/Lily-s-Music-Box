"""Original counter recess; Blender CPU only, no render. Pass a fresh output directory after --."""
from pathlib import Path
import sys,json,hashlib,itertools,struct
import bpy,bmesh,numpy as np
from mathutils import Matrix
ROOT=Path(__file__).resolve().parents[3]; OUT=Path(sys.argv[sys.argv.index('--')+1]).resolve()
assert not (OUT/'game/assets/props/harukiya_pet_counter.glb').exists(), 'Use a fresh output directory'
sys.path.insert(0,str(ROOT/'art/blender/scripts'))
import fabrication_native_batch as native
for folder in ['art/blender','game/assets/props']:(OUT/folder).mkdir(parents=True,exist_ok=True)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
cell=ROOT/'game/assets/building/floor_01_cells/shop_bar.gltf'; g=json.loads(cell.read_text()); binary=cell.with_suffix('.bin'); data=binary.read_bytes()
def acc(i):
 a=g['accessors'][i];v=g['bufferViews'][a['bufferView']];dtype={5126:'<f4',5123:'<u2',5125:'<u4'}[a['componentType']];n={'VEC3':3,'SCALAR':1}[a['type']]
 return np.ndarray((a['count'],n),dtype=dtype,buffer=data,offset=v.get('byteOffset',0)+a.get('byteOffset',0),strides=(v.get('byteStride',np.dtype(dtype).itemsize*n),np.dtype(dtype).itemsize))
record=next(x for f in json.loads((ROOT/'game/data/building_layout.json').read_text())['floors'] if f['id']=='F01' for x in f['furniture'] if x['id']=='retail_bar_counter')
assert record=={'id':'retail_bar_counter','rect':[-5.1,-30.28,1.2,-29.6],'z0':-2.8,'h':1.02,'mat':'wood_dark'}
# Exact stock membership by its eight float32 original corners, NOT box erasure.
corners=set(tuple(np.float32(q)) for q in itertools.product([-5.1,1.2],[-2.8,-1.78],[30.28,29.6]))
selected=[];total=0
for node in g['nodes']:
 if node['name']!='F01_OWN_SHOP_BAR_retail_bar_wood_dark-col':continue
 assert not any(k in node for k in ['matrix','translation','rotation','scale'])
 for pi,p in enumerate(g['meshes'][node['mesh']]['primitives']):
  verts=acc(p['attributes']['POSITION']);indices=acc(p['indices']).reshape(-1,3);total+=len(indices)
  for ti,ids in enumerate(indices):
   tri=verts[ids]
   if all(tuple(v) in corners for v in tri):selected.append({'node':node['name'],'primitive':pi,'triangle_index':ti,'vertices_godot':tri.tolist()})
assert len(selected)==12,('expected exact original 12 triangles',len(selected))
assert len({tuple(sorted(tuple(v) for v in r['vertices_godot'])) for r in selected})==12
retire={'schema_version':1,'evidence_class':'INERT','stock_id':record['id'],'source_record':record,'cell_lf_sha256':hashlib.sha256(cell.read_text().replace('\r\n','\n').encode()).hexdigest(),'bin_sha256':sha(binary),'selection_method':'exact float32 stock corner membership,12 distinct original triangles; no bounding-box deletion','selected':selected,'original_partition_triangles':total,'remaining_partition_triangles':total-12,'runtime_requirement':'match exact triangle multiplicity in renderer AND imported collision; preserve every unselected element/channel transactionally; not a loaded adapter'}
(OUT/'retirement.json').write_text(json.dumps(retire,indent=2))
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
stocks=bpy.data.collections.new('EditableClosedStocks');bpy.context.scene.collection.children.link(stocks)
exports=bpy.data.collections.new('Export');bpy.context.scene.collection.children.link(exports)
catalog=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text())['materials']
finishes={k:{'catalog_key':k,'tint':[1,1,1,1],'roughness':1.,'normal':.35,'pigment':1.} for k in ['wood_dark','timber']}
mats={k:native.material(ROOT,k,f,catalog) for k,f in finishes.items()};images={im:Path(bpy.path.abspath(im.filepath)) for im in bpy.data.images if im.source=='FILE'}
checks=[];parts={}
def solid(name,vs,fs,key,volume):
 mesh=bpy.data.meshes.new(name);mesh.from_pydata(vs,[],fs);mesh.update()
 bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
 if bm.calc_volume(signed=True)<0:bmesh.ops.reverse_faces(bm,faces=list(bm.faces))
 actual=bm.calc_volume(signed=True);assert all(e.is_manifold for e in bm.edges),name
 assert abs(actual-volume)<1e-5,(name,actual,volume)
 bm.to_mesh(mesh);bm.free();mesh.materials.append(mats[key]);obj=bpy.data.objects.new(name,mesh);stocks.objects.link(obj);parts[key]=obj
 checks.append({'name':name,'closed_manifold':True,'volume_m3':actual,'expected_volume_m3':volume,'vertices':len(vs),'faces':len(fs)})
 return obj
# Boundary of occupied orthogonal cells; shared internal faces omitted, all
# boundary vertices welded. This is one closed solid, not overlapping boxes.
axes=[[-5.1,-.5,.4,1.2],[-30.28,-29.78,-29.6],[-2.8,-2.3,-1.78]]
cells=set(itertools.product(range(3),range(2),range(2)));cells.remove((1,0,0));vs=[];fs=[];lookup={}
for ijk in sorted(cells):
 for axis in range(3):
  other=[i for i in range(3) if i!=axis]
  for side in [0,1]:
   neighbor=list(ijk);neighbor[axis]+=1 if side else -1
   if tuple(neighbor) in cells:continue
   face=[]
   for a,b in [(0,0),(1,0),(1,1),(0,1)]:
    index=list(ijk);index[axis]+=side;index[other[0]]+=a;index[other[1]]+=b
    point=tuple(axes[d][index[d]] for d in range(3))
    if point not in lookup:lookup[point]=len(vs);vs.append(point)
    face.append(lookup[point])
   fs.append(face)
solid('CounterCarcassWithOpenFrontRecess',vs,fs,'wood_dark',6.3*.68*1.02-.9*.5*.5)
F=[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)]
solid('WarmBoard',list(itertools.product([-.5,.4],[-30.28,-29.78],[-2.8,-2.78])),[(0,1,3,2),(4,6,7,5),(0,4,5,1),(2,3,7,6),(0,2,6,4),(1,5,7,3)],'timber',.9*.5*.02)
for key,obj in parts.items():native.partition(exports,'CounterRecess__'+key,[obj],finishes[key],mats[key],Matrix.Identity(4),catalog)
stocks.hide_render=True;stocks.hide_viewport=True
# Establish the blend base before shared export converts texture paths.
# Without this, Blender interprets the new relative paths against no file.
bpy.context.view_layer.update()
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'art/blender/harukiya_pet_counter.blend'))
proof=native.export(OUT,'harukiya_pet_counter',exports,material_names_only=True,save_native=False)
# Export partitions are authoritative visual/collision faces; no convex hull
# across the opening is allowed. Source coordinates convert only on glTF export.
collision={o.name:{'vertices_source':[list(v.co) for v in o.data.vertices],'triangles':[list(p.vertices) for p in o.data.polygons]} for o in exports.objects}
(OUT/'collision_faces.json').write_text(json.dumps({'frame':'Blender source metres; b2g once','kind':'exact concave triangle faces, not convex hull','parts':collision},indent=2))
blend=OUT/'art/blender/harukiya_pet_counter.blend'
for im,path in images.items():im.filepath=bpy.path.relpath(str(path),start=str(blend.parent))
bpy.context.view_layer.update();bpy.ops.wm.save_as_mainfile(filepath=str(blend))
report={'status':'CPU_NATIVE_BUILT_NOT_RENDERED','blender':bpy.app.version_string,'stock_checks':checks,'export_derivatives':proof,'retired_triangles':12,'recess_source':[[-.5,-30.28,-2.8],[.4,-29.78,-2.3]],'board_top_z':-2.78,'remaining_clear_height':.48,'support_contacts':[{'parts':['WarmBoard','retained retail_bar_floor'],'plane_z':-2.8,'footprint':[-.5,-30.28,.4,-29.78]},{'parts':['new carcass','unchanged countertop'],'plane_z':-1.78,'footprint':[-5.1,-30.28,1.2,-29.6]}],'finishes':finishes,'hashes':{str(p):sha(p) for p in [cell,binary,Path(__file__),ROOT/'art/blender/scripts/fabrication_native_batch.py',ROOT/'art/blender/scripts/fabrication_chart_batch.py',ROOT/'art/blender/scripts/fabrication_grain.py',ROOT/'art/blender/scripts/fabrication_normals.py',ROOT/'art/blender/scripts/check_exported_tangents.py',ROOT/'game/data/runtime_material_sets.json',*images.values()]}}
(OUT/'construction.json').write_text(json.dumps(report,indent=2));print('COUNTER_NATIVE_PASS',json.dumps(checks))
