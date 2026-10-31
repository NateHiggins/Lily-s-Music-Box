"""Build closed mapped distant grade from the actual retained ground export."""
from pathlib import Path
import hashlib,json,sys,os
import bpy,bmesh
from mathutils import Matrix,Vector

ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
sys.path.insert(0,str(ROOT/'art/blender/scripts'))
from city_ground_apron_geometry import exported_bounds,apron_boxes,relief_stock,water_stock,street_cut_footprints,soil_cut_prisms,removed_flat_soil_volume,clip_soil_face,chunk_soil_faces,relief_height
from ground_closed_union import apply_soil_cuts
from city_street_geometry import overlap
from fabrication_native_batch import material,partition,export

plan_path=ROOT/'art/data/city_ground_apron/source_plan.json'
plan=json.loads(plan_path.read_text());assert plan['schema']=='orison.city-ground-apron.v1'
street_paths=[ROOT/p for p in ['art/data/city_streets/source_plan.json','art/blender/scripts/city_street_geometry.py','game/data/orison_v2/exterior/street_frame.json','game/data/orison_v2_blockout.json']]
street_specs=street_cut_footprints(*[json.loads(p.read_text()) for p in [street_paths[0],street_paths[2],street_paths[3]]])
street_prisms=soil_cut_prisms(street_specs)
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
def horizontal_phase(part,origin,key):
    tile=float(catalog[key]['meters_per_tile'])
    for face in part.data.polygons:
        if face.normal.z<.999:continue
        for loop in face.loop_indices:
            p=part.data.vertices[part.data.loops[loop].vertex_index].co
            part.data.uv_layers.active.data[loop].uv=(p.x+origin.x%tile,1+p.y+origin.y%tile)
            part.data.attributes['_tangent_guide'].data[loop].vector=(1,0,0)
parts=[];street_proofs=[];street_cavity=[]
for row in boxes:
    vertices,faces,keys=relief_stock(row['bounds'],plan['relief'])
    water_vertices,water_faces=water_stock(vertices,faces,plan['relief']['water_scene_y_m'])
    row['bounds'][1]=plan['relief']['solid_bottom_scene_y_m']
    # Nine spatially distributed exact source vertices, clear of retained city.
    row['exposed_samples']=[]
    candidates=[p for p in vertices if p[1]>plan['relief']['solid_bottom_scene_y_m']+.01 and not any(b['rect'][0]-.03<p[0]<b['rect'][2]+.03 and b['rect'][1]-.03<p[2]<b['rect'][3]+.03 for b in buildings)
                and not any(q['bounds'][0]-1e-7<=p[0]<=q['bounds'][2]+1e-7 and q['bounds'][1]-1e-7<=p[2]<=q['bounds'][3]+1e-7 and all(nx*p[0]+nz*p[2]+d<=1e-7 for nx,ny,nz,d in q['planes'][:-1]) for q in street_prisms)]
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
        local_prisms=[p for p in street_prisms if overlap([row['bounds'][0],row['bounds'][2],row['bounds'][3],row['bounds'][5]],p['bounds'])] if suffix=='ground' else []
        if local_prisms:
            assert all(abs(relief_height(x,z,top,plan['relief'])-top)<1e-7 for spec in street_specs for p in spec['polygons'] for x,z in p),'Street cut volume proof requires flat original eastern soil'
            print('APRON STREET CUT: independent void integral begins',row['id'],flush=True)
            removed=removed_flat_soil_volume(street_specs,[row['bounds'][0],row['bounds'][2],row['bounds'][3],row['bounds'][5]],top,[])
            print('APRON STREET CUT:',row['id'],'expected removal',removed,'m3; native Boolean begins',flush=True)
            cavity,cut_proof=apply_soil_cuts(source,sources,street_specs,removed)
            street_cavity.extend(cavity);street_proofs.append({'id':row['id'],**cut_proof})
        for key in sorted(set(ks)):
            selected=[f for f,k in zip(fs,ks) if k==key]
            patch=bpy.data.meshes.new('TemporaryFinish')
            if local_prisms:
                clipped=[part for face in selected for part in clip_soil_face([vs[i] for i in face],local_prisms)]
                points=[];indices=[];lookup={}
                for face in clipped:
                    polygon=[]
                    for x,y,z in face:
                        p=(x-float(origin.x),-z-float(origin.y),y-float(origin.z))
                        if p not in lookup:lookup[p]=len(points);points.append(p)
                        polygon.append(lookup[p])
                    indices.append(polygon)
                if not indices:bpy.data.meshes.remove(patch);continue
                patch.from_pydata(points,[],indices)
            else:patch.from_pydata(coords,[],selected)
            patch.update()
            # Keep breaklines/shore contours, remove redundant coplanar grid
            # edges before charting. The editable closed stock stays untouched.
            bm=bmesh.new();bm.from_mesh(patch)
            bmesh.ops.dissolve_limit(bm,angle_limit=1e-6,verts=list(bm.verts),edges=list(bm.edges),use_dissolve_boundaries=False)
            bm.to_mesh(patch);bm.free();patch.update()
            stock=bpy.data.objects.new('TemporaryFinish',patch)
            part=partition(collection,'Horizon_'+row['id']+'__'+key,[stock],finishes[key],mats[key],Matrix.Translation(origin),catalog)
            horizontal_phase(part,origin,key)
            parts.append({'name':part.name,'finish':key,'triangles':len(part.data.polygons)})
            bpy.data.objects.remove(stock);bpy.data.meshes.remove(patch)
for (ix,iz),faces in sorted(chunk_soil_faces(street_cavity).items()):
    origin=Vector(((ix+.5)*4.,-(iz+.5)*4.,0.))
    vertices=[];indices=[]
    for face in faces:
        first=len(vertices);vertices.extend((x-float(origin.x),-z-float(origin.y),y) for x,y,z in face)
        indices.append(tuple(range(first,len(vertices))))
    mesh=bpy.data.meshes.new('TemporaryStreetCut');mesh.from_pydata(vertices,[],indices);mesh.update()
    stock=bpy.data.objects.new(mesh.name,mesh)
    part=partition(collection,'Horizon_StreetCut_%d_%d__soil'%(ix,iz),[stock],finishes['soil'],mats['soil'],Matrix.Translation(origin),catalog)
    horizontal_phase(part,origin,'soil')
    parts.append({'name':part.name,'finish':'soil','triangles':len(part.data.polygons)})
    bpy.data.objects.remove(stock);bpy.data.meshes.remove(mesh)
proof=export(ROOT,'city_ground_apron',collection)
actual=exported_bounds((ROOT/'game/assets/props/city_ground_apron.glb').read_bytes())
assert max(abs(a-b) for a,b in zip([actual[i] for i in [0,2,3,5]],plan['outer_rect']))<.0001
assert abs(actual[4]-bounds[4])<.0001
paths=[plan_path,retained_path,grade_path,finish_path,catalog_path,Path(__file__),ROOT/'game/scripts/building/orison_v2_ground.gd',ROOT/'art/data/city_horizon/source_plan.json']
paths += [ROOT/'art/blender/scripts'/p for p in ['city_ground_apron_geometry.py','ground_closed_union.py','fabrication_native_batch.py','fabrication_chart_batch.py','fabrication_grain.py','fabrication_normals.py','check_exported_tangents.py']]+street_paths
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
    street_soil_cuts=street_proofs,
    source_bindings={p.relative_to(ROOT).as_posix():sha(p) for p in paths},export_check=proof)
for relative in ['art/blender/city_ground_apron_construction.json','game/tests/fixtures/orison_city_ground_apron.json']:
    (ROOT/relative).write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8',newline='\n')
print('CITY GROUND RELIEF: closed source stocks, source-owned street cuts and clipped water; original bounds retained; exported tangent check PASS',flush=True)
