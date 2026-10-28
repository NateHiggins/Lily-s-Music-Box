"""Build closed mapped distant grade from the actual retained ground export."""
from pathlib import Path
import hashlib,json,sys,os
import bpy,bmesh
from mathutils import Matrix,Vector

ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
sys.path.insert(0,str(ROOT/'art/blender/scripts'))
from city_ground_apron_geometry import exported_bounds,apron_boxes,relief_stock,water_stock
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
finishes={'asphalt':finish,**plan['relief']['finishes']}
mats={key:material(ROOT,'Horizon_'+key,spec,catalog) for key,spec in finishes.items()}
sources=bpy.data.collections.new('EditableReliefStocks');bpy.context.scene.collection.children.link(sources)
sources.hide_render=True;sources.hide_viewport=True
buildings=json.loads((ROOT/'art/data/city_horizon/source_plan.json').read_text())['buildings']
parts=[]
for row in boxes:
    vertices,faces,keys=relief_stock(row['bounds'],plan['relief'])
    water_vertices,water_faces=water_stock(vertices,faces,plan['relief']['water_scene_y_m'])
    row['bounds'][1]=plan['relief']['solid_bottom_scene_y_m']
    # Nine spatially distributed exact source vertices, clear of retained city.
    row['exposed_samples']=[]
    candidates=[p for p in vertices if p[1]>plan['relief']['solid_bottom_scene_y_m']+.01 and not any(b['rect'][0]-.03<p[0]<b['rect'][2]+.03 and b['rect'][1]-.03<p[2]<b['rect'][3]+.03 for b in buildings)]
    for u in [.1,.5,.9]:
        for v in [.1,.5,.9]:
            target=(row['bounds'][0]+(row['bounds'][3]-row['bounds'][0])*u,row['bounds'][2]+(row['bounds'][5]-row['bounds'][2])*v)
            point=min(candidates,key=lambda p:(p[0]-target[0])**2+(p[2]-target[1])**2)
            row['exposed_samples'].append(point);candidates.remove(point)
    for suffix,vs,fs,ks in [('ground',vertices,faces,keys),('water',water_vertices,water_faces,['water_clear']*len(water_faces))]:
        if not vs:continue
        origin=Vector(((row['bounds'][0]+row['bounds'][3])/2,-(row['bounds'][2]+row['bounds'][5])/2,0))
        coords=[Vector((x,-z,y))-origin for x,y,z in vs]
        mesh=bpy.data.meshes.new(row['id']+'_'+suffix);mesh.from_pydata(coords,[],fs);mesh.update()
        bm=bmesh.new();bm.from_mesh(mesh);assert all(len(e.link_faces)==2 for e in bm.edges);assert bm.calc_volume(signed=True)>0;bm.free()
        source=bpy.data.objects.new(mesh.name,mesh);sources.objects.link(source);source.location=origin
        for key in sorted(set(ks)):mesh.materials.append(mats[key])
        for face,key in zip(mesh.polygons,ks):face.material_index=sorted(set(ks)).index(key)
        for key in sorted(set(ks)):
            selected=[f for f,k in zip(fs,ks) if k==key]
            patch=bpy.data.meshes.new('TemporaryFinish');patch.from_pydata(coords,[],selected);patch.update()
            # Keep breaklines/shore contours, remove redundant coplanar grid
            # edges before charting. The editable closed stock stays untouched.
            bm=bmesh.new();bm.from_mesh(patch)
            bmesh.ops.dissolve_limit(bm,angle_limit=1e-6,verts=list(bm.verts),edges=list(bm.edges),use_dissolve_boundaries=False)
            bm.to_mesh(patch);bm.free();patch.update()
            stock=bpy.data.objects.new('TemporaryFinish',patch)
            part=partition(collection,'Horizon_'+row['id']+'__'+key,[stock],finishes[key],mats[key],Matrix.Translation(origin),catalog)
            tile=float(catalog[key]['meters_per_tile'])
            for face in part.data.polygons:
                if face.normal.z<.999:continue
                for loop in face.loop_indices:
                    p=part.data.vertices[part.data.loops[loop].vertex_index].co
                    part.data.uv_layers.active.data[loop].uv=(p.x+origin.x%tile,1+p.y+origin.y%tile)
                    part.data.attributes['_tangent_guide'].data[loop].vector=(1,0,0)
            parts.append({'name':part.name,'finish':key,'triangles':len(part.data.polygons)})
            bpy.data.objects.remove(stock);bpy.data.meshes.remove(patch)
proof=export(ROOT,'city_ground_apron',collection)
actual=exported_bounds((ROOT/'game/assets/props/city_ground_apron.glb').read_bytes())
assert max(abs(a-b) for a,b in zip([actual[i] for i in [0,2,3,5]],plan['outer_rect']))<.0001
assert abs(actual[4]-bounds[4])<.0001
paths=[plan_path,retained_path,grade_path,finish_path,catalog_path,Path(__file__),ROOT/'game/scripts/building/orison_v2_ground.gd',ROOT/'art/data/city_horizon/source_plan.json']
paths += [ROOT/'art/blender/scripts'/p for p in ['city_ground_apron_geometry.py','fabrication_native_batch.py','fabrication_chart_batch.py','fabrication_grain.py','fabrication_normals.py','check_exported_tangents.py']]
paths += [ROOT/'game/assets/building/textures'/p for key in finishes for p in catalog[key]['files']]
projection={'schema':1,'frame':plan['frame'],'street_asl_m':plan['relief']['street_asl_m'],'water_scene_y_m':plan['relief']['water_scene_y_m'],
    'finishes':[{k:spec[k] for k in ['catalog_key','tint','normal','roughness']} for spec in finishes.values()]}
projection_path=ROOT/'game/data/orison_v2/exterior/city_ground_relief.json'
projection_path.write_text(json.dumps(projection,indent=2)+'\n',encoding='utf-8',newline='\n');paths.append(projection_path)
def sha(path):
    raw=path.read_bytes()
    return hashlib.sha256(raw if path.suffix in ['.glb','.blend','.png'] else raw.replace(b'\r\n',b'\n')).hexdigest()
report=dict(evidence_class='INERT',scope=plan['scope'],frame=plan['frame'],retained_ground_bounds=bounds,outer_bounds=actual,
    surface_phase='Registered metre axes, with each local origin reduced by whole asphalt tiles; matches retained ground.',
    boxes=boxes,parts=parts,relief=plan['relief'],retained_ground_sha256=sha(retained_path),asset_sha256=sha(ROOT/'game/assets/props/city_ground_apron.glb'),
    source_bindings={p.relative_to(ROOT).as_posix():sha(p) for p in paths},export_check=proof)
for relative in ['art/blender/city_ground_apron_construction.json','game/tests/fixtures/orison_city_ground_apron.json']:
    (ROOT/relative).write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8',newline='\n')
print('CITY GROUND RELIEF: four closed source stocks plus clipped water; retained ground unchanged; exported tangent check PASS',flush=True)
