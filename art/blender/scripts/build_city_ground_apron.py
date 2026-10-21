"""Build closed mapped distant grade from the actual retained ground export."""
from pathlib import Path
import hashlib,json,sys,os
import bpy,bmesh
from mathutils import Matrix,Vector

ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
sys.path.insert(0,str(ROOT/'art/blender/scripts'))
from city_ground_apron_geometry import exported_bounds,apron_boxes
from fabrication_native_batch import material,partition,export

plan_path=ROOT/'art/data/city_ground_apron/source_plan.json'
plan=json.loads(plan_path.read_text());assert plan['schema']=='orison.city-ground-apron.v1'
retained_path=ROOT/'game/assets/props/orison_ground.glb'
grade_path=ROOT/'art/blender/orison_ground_construction.json'
grade=json.loads(grade_path.read_text())
assert hashlib.sha256(retained_path.read_bytes()).hexdigest()==grade['source_native_sha256']
bounds=exported_bounds(retained_path.read_bytes())
region=grade['source_plan']['region'];top=grade['source_plan']['asphalt_y'][1]
assert max(abs(a-b) for a,b in zip([bounds[i] for i in [0,2,3,5]],region))<.0001
assert abs(bounds[4]-top)<.0001
boxes=apron_boxes(bounds,plan['outer_rect'],plan['slab_depth'])
finish_path=ROOT/'game/data/orison_v2/ground_finish.json'
finish=json.loads(finish_path.read_text())
finish.update(catalog_key=plan['catalog_key'],pigment=1.0)
catalog_path=ROOT/'game/data/runtime_material_sets.json'
catalog=json.loads(catalog_path.read_text())['materials']
bpy.ops.wm.read_factory_settings(use_empty=True)
collection=bpy.data.collections.new('DistantGroundApron');bpy.context.scene.collection.children.link(collection)
mat=material(ROOT,'Horizon_asphalt',finish,catalog)
for row in boxes:
    x,y,z,X,Y,Z=row['bounds']
    # Godot X,Y,Z -> Blender X,-Z,Y, matching the retained native grade.
    lo=Vector((x,-Z,y));hi=Vector((X,-z,Y));origin=(lo+hi)*.5
    vertices=[(a,b,c) for a,b,c in [(lo.x,lo.y,lo.z),(hi.x,lo.y,lo.z),(hi.x,hi.y,lo.z),(lo.x,hi.y,lo.z),
        (lo.x,lo.y,hi.z),(hi.x,lo.y,hi.z),(hi.x,hi.y,hi.z),(lo.x,hi.y,hi.z)]]
    faces=[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
    mesh=bpy.data.meshes.new(row['id']);mesh.from_pydata([Vector(v)-origin for v in vertices],[],faces);mesh.update()
    bm=bmesh.new();bm.from_mesh(mesh);assert all(len(e.link_faces)==2 for e in bm.edges);bm.free()
    stock=bpy.data.objects.new(row['id'],mesh)
    part=partition(collection,'Horizon_asphalt_'+row['id'],[stock],finish,mat,Matrix.Translation(origin),catalog)
    # The finite ground uses registered metre axes. Keep the distant stock's
    # top in that same phase, instead of restarting the texture at each apron
    # box's local centre. The glTF export flips V, hence the authored +1.
    tile=float(catalog[plan['catalog_key']]['meters_per_tile'])
    for face in part.data.polygons:
        if face.normal.z<.999:continue
        for loop in face.loop_indices:
            p=part.data.vertices[part.data.loops[loop].vertex_index].co
            part.data.uv_layers.active.data[loop].uv=(p.x+origin.x%tile,1+p.y+origin.y%tile)
            part.data.attributes['_tangent_guide'].data[loop].vector=(1,0,0)
    bpy.data.objects.remove(stock);bpy.data.meshes.remove(mesh)
proof=export(ROOT,'city_ground_apron',collection)
actual=exported_bounds((ROOT/'game/assets/props/city_ground_apron.glb').read_bytes())
assert max(abs(a-b) for a,b in zip([actual[i] for i in [0,2,3,5]],plan['outer_rect']))<.0001
assert abs(actual[4]-bounds[4])<.0001
paths=[plan_path,retained_path,grade_path,finish_path,catalog_path,Path(__file__),ROOT/'game/scripts/building/orison_v2_ground.gd']
paths += [ROOT/'art/blender/scripts'/p for p in ['city_ground_apron_geometry.py','fabrication_native_batch.py','fabrication_chart_batch.py','fabrication_grain.py','fabrication_normals.py','check_exported_tangents.py']]
paths += [ROOT/'game/assets/building/textures'/p for p in catalog[plan['catalog_key']]['files']]
def sha(path):
    raw=path.read_bytes()
    return hashlib.sha256(raw if path.suffix in ['.glb','.blend','.png'] else raw.replace(b'\r\n',b'\n')).hexdigest()
report=dict(evidence_class='INERT',scope=plan['scope'],frame=plan['frame'],retained_ground_bounds=bounds,outer_bounds=actual,
    surface_phase='Registered metre axes, with each local origin reduced by whole asphalt tiles; matches retained ground.',
    boxes=boxes,retained_ground_sha256=sha(retained_path),asset_sha256=sha(ROOT/'game/assets/props/city_ground_apron.glb'),
    source_bindings={p.relative_to(ROOT).as_posix():sha(p) for p in paths},export_check=proof)
for relative in ['art/blender/city_ground_apron_construction.json','game/tests/fixtures/orison_city_ground_apron.json']:
    (ROOT/relative).write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8',newline='\n')
print('CITY GROUND APRON: four closed mapped stocks; retained ground unchanged; exported tangent check PASS',flush=True)
