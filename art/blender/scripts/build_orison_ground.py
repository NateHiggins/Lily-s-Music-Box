"""Source-owned Orison roof/drainage construction.

Retained gameplay authorities remain; geometry and material validation are
independent of this source recipe. No drainage capacity acceptance.
"""
from pathlib import Path
import json
import math
import collections
import hashlib
import os
import subprocess
import sys
import bpy
import bmesh
import numpy as np
from mathutils import Vector

root = next(path for path in Path(__file__).resolve().parents if (path/'game/project.godot').is_file())
base = root / 'art/blender'
work = root/'tmp/orison-ground'; work.mkdir(parents=True,exist_ok=True)
plan = json.loads((root/'art/data/orison_ground/retained_grade_source.json').read_text(encoding='utf-8'))
sys.path.insert(0,str(root/'tools'))
from grade_source_snapshot import validate as validate_grade_snapshot
validate_grade_snapshot(plan,root)
sys.path.insert(0,str(Path(__file__).resolve().parent))
from city_ground_apron_geometry import profile_height,clip_profile_face,profile_roof_caps,profile_grid_volume,coalesced_grid_planes,parcel_transition_cells,street_cut_footprints,soil_cut_prisms,removed_flat_soil_volume,removed_profile_soil_volume,clip_soil_face,chunk_soil_faces
from city_street_geometry import overlap
from fabrication_chart_batch import triangle_charts
from fabrication_native_batch import export as export_native
relief_path=root/'art/data/city_ground_apron/source_plan.json'
relief=json.loads(relief_path.read_text(encoding='utf-8'))['relief']
roof_profile=relief['west_profile']
for path in [relief_path,Path(__file__).with_name('city_ground_apron_geometry.py')]:
    plan['bindings'][path.relative_to(root).as_posix()]=hashlib.sha256(path.read_bytes().replace(b'\r\n',b'\n')).hexdigest()
sets_path=root/'game/data/runtime_material_sets.json'
sets=json.loads(sets_path.read_text(encoding='utf-8'))['materials']
plan['bindings']['game/data/runtime_material_sets.json']=hashlib.sha256(sets_path.read_text(encoding='utf-8').replace('\r\n','\n').encode()).hexdigest()
plan['bindings']['art/blender/scripts/build_orison_ground.py']=hashlib.sha256((root/'art/blender/scripts/build_orison_ground.py').read_text(encoding='utf-8').replace('\r\n','\n').encode()).hexdigest()
packing_tool=root/'art/tools/repack_blend.cjs'
plan['bindings']['art/tools/repack_blend.cjs']=hashlib.sha256(packing_tool.read_bytes().replace(b'\r\n',b'\n')).hexdigest()
foundation_path=base/'city_foundations_construction.json'
foundation=json.loads(foundation_path.read_text(encoding='utf-8'))
if 'grade_envelope' in foundation:
    current=plan['region'];extent=foundation['grade_envelope']
    plan['region']=[min(current[0],extent[0]),min(current[1],extent[1]),max(current[2],extent[2]),max(current[3],extent[3])]
plan['retained_solids'].extend(foundation['components'])
plan['bindings'].update(foundation['bindings'])
plan['bindings']['art/blender/city_foundations_construction.json']=hashlib.sha256(foundation_path.read_text(encoding='utf-8').replace('\r\n','\n').encode()).hexdigest()
for profile in foundation['profiles']:
    x0,z0,x1,z1=profile['underside']
    plan['surface_exclusions'].append({'owner':profile['id'],'kind':'actual_planar_native_underside_projection','bounds':[x0,plan['soil_bottom'],z0,x1,0,z1]})
reservations_path=base/'alley_groundworks_reservations.json'
reservations=json.loads(reservations_path.read_text(encoding='utf-8'))
plan['occupation_reservations'].extend(reservations['reservations'])
plan['surface_exclusions'].append(next(r for r in reservations['reservations'] if r['owner']=='BoilerWell/ConstructionAndAir'))
plan['bindings'].update(reservations['bindings'])
plan['bindings']['art/blender/alley_groundworks_reservations.json']=hashlib.sha256(reservations_path.read_text(encoding='utf-8').replace('\r\n','\n').encode()).hexdigest()
bar_path=root/'art/data/orison_ground/bar_reservations.json'
bar=json.loads(bar_path.read_text(encoding='utf-8'))
plan['retained_solids'].extend(bar['retained_solids'])
plan['occupation_reservations'].extend(bar['reservations'])
plan['bindings'].update(bar['bindings'])
plan['bindings']['art/data/orison_ground/bar_reservations.json']=hashlib.sha256(bar_path.read_text(encoding='utf-8').replace('\r\n','\n').encode()).hexdigest()
receiver_path=root/'art/blender/roof_drainage_reservations.json'
receiver=json.loads(receiver_path.read_bytes())
plan['occupation_reservations'].extend(receiver['reservations'])
plan['bindings'].update(receiver['bindings'])
plan['bindings'][receiver_path.relative_to(root).as_posix()]=hashlib.sha256(receiver_path.read_bytes()).hexdigest()
plan['bindings'][Path(__file__).relative_to(root).as_posix()]=hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
union_helper=root/'art/blender/scripts/ground_closed_union.py'
plan['bindings'][union_helper.relative_to(root).as_posix()]=hashlib.sha256(union_helper.read_bytes()).hexdigest()
for filename in ['fabrication_native_batch.py','fabrication_chart_batch.py','fabrication_uvs.py','fabrication_grain.py','fabrication_normals.py','check_exported_tangents.py']:
    helper=Path(__file__).with_name(filename)
    plan['bindings'][helper.relative_to(root).as_posix()]=hashlib.sha256(helper.read_bytes().replace(b'\r\n',b'\n')).hexdigest()
street_paths=[root/p for p in ['art/data/city_streets/source_plan.json','art/blender/scripts/city_street_geometry.py','game/data/orison_v2/exterior/street_frame.json','game/data/orison_v2_blockout.json']]
street_specs=street_cut_footprints(*[json.loads(p.read_text(encoding='utf-8')) for p in [street_paths[0],street_paths[2],street_paths[3]]])
street_prisms=soil_cut_prisms(street_specs)
for path in street_paths:plan['bindings'][path.relative_to(root).as_posix()]=hashlib.sha256(path.read_bytes().replace(b'\r\n',b'\n')).hexdigest()
for relative, expected in plan['bindings'].items():
    path = root / relative
    raw = path.read_bytes() if path.suffix in ['.blend','.glb','.bin'] else path.read_text(encoding='utf-8').replace('\r\n', '\n').encode()
    assert hashlib.sha256(raw).hexdigest() == expected, relative
def native_coordinate(value):
    # Blender stores mesh coordinates as float32. Use their actual represented
    # planes in the cell proof, rather than compare rounded double coordinates
    # with a separately quantized saved mesh over a much larger site.
    return float(np.float32(round(value,5)))
a, b, c, d = [native_coordinate(value) for value in plan['region']]
low = native_coordinate(plan['soil_bottom']); asphalt_low, top = [native_coordinate(value) for value in plan['asphalt_y']]
roof_profile=[[native_coordinate(x),top if abs(float(h)-top)<1e-7 else native_coordinate(h)] for x,h in roof_profile]
profile_heights=[profile_height(a,roof_profile),profile_height(c,roof_profile)]+[h for x,h in roof_profile if a<x<c]
assert max(profile_heights)<=top+.000001 and min(profile_heights)>low+.1,'Ground cut must preserve finite buried foundation seats'
roof_cut=min(profile_heights)<top-.000001
masks = plan['retained_solids'] + plan['occupation_reservations']
limits = [(a, c), (low, top), (b, d)]
coordinates = []
for axis, (start, end) in enumerate(limits):
    values = {start, end}
    if axis == 1: values.add(asphalt_low)
    else: values.update(4 * index for index in range(math.ceil(start / 4), math.ceil(end / 4)) if start < 4 * index < end)
    if axis == 0 and roof_cut: values.update(native_coordinate(x) for x,_ in roof_profile if start<native_coordinate(x)<end)
    for row in masks + plan['surface_exclusions']:
        bounds = row['bounds']
        values.update(native_coordinate(value) for value in [bounds[axis], bounds[axis + 3]] if start < native_coordinate(value) < end)
    coordinates.append(sorted(values))
xs, ys, zs = coordinates
indexes = [{value: index for index, value in enumerate(values)} for values in coordinates]
size = tuple(len(values) - 1 for values in coordinates)
assert all(value > 0 for value in size)
solid = np.ones(size, dtype=bool)
retained = np.zeros(size, dtype=bool)

def slices(bounds):
    result = []
    for axis, (start, end) in enumerate(limits):
        lo = max(start, native_coordinate(bounds[axis])); hi = min(end, native_coordinate(bounds[axis + 3]))
        if hi <= lo: return None
        result.append(slice(indexes[axis][lo], indexes[axis][hi]))
    return tuple(result)

exact_kinds = {'authored_original_box', 'authored_union_component',
               'actual_axis_aligned_box', 'retained_continuous_paving_substrate'}
for row in masks:
    selection = slices(row['bounds'])
    if selection is None: continue
    solid[selection] = False
    if row.get('kind') in exact_kinds: retained[selection] = True
asphalt = np.zeros(size, dtype=bool)
asphalt[:, indexes[1][asphalt_low]:, :] = True
for row in plan['surface_exclusions']:
    bounds = row['bounds']
    lo_x = max(a, native_coordinate(bounds[0])); hi_x = min(c, native_coordinate(bounds[3]))
    lo_z = max(b, native_coordinate(bounds[2])); hi_z = min(d, native_coordinate(bounds[5]))
    if hi_x <= lo_x or hi_z <= lo_z: continue
    asphalt[indexes[0][lo_x]:indexes[0][hi_x], :, indexes[2][lo_z]:indexes[2][hi_z]] = False
asphalt &= solid
parcel_rects=[[native_coordinate(v) for v in row['underside']] for row in foundation['profiles']]
parcel_protection=np.zeros((size[0],size[2]),dtype=bool)
xm=(np.asarray(xs[:-1])+xs[1:])*.5;zm=(np.asarray(zs[:-1])+zs[1:])*.5
for x,z,X,Z in parcel_rects:parcel_protection[np.ix_((xm>x)&(xm<X),(zm>z)&(zm<Z))]=True
transitions=parcel_transition_cells(np.asarray(xs),np.asarray(ys),solid,roof_profile,parcel_protection) if roof_cut else 0
assert transitions==0,('Raised parcel needs an actual retaining wall',transitions)
np.savez_compressed(work / 'orison-ground-cells.npz', solid=solid,
                    asphalt=asphalt, xs=xs, ys=ys, zs=zs,
                    roof_cut=roof_cut,roof_profile=np.asarray(roof_profile,dtype=np.float64),
                    parcel_protection=parcel_protection,parcel_rects=np.asarray(parcel_rects,dtype=np.float64))
print('COURTYARD TRIAL GRID:', size, 'solid cells', int(solid.sum()), 'asphalt cells', int(asphalt.sum()), flush=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version = 0
source_collection = bpy.data.collections.new('OrisonGroundConstruction')
bpy.context.scene.collection.children.link(source_collection)
source_collection.hide_render = True; source_collection.hide_viewport = True
export_collection=bpy.data.collections.new('GroundExports');bpy.context.scene.collection.children.link(export_collection)
materials = {}
for name, color in [('soil', (.16, .12, .08, 1)), ('asphalt', (.18, .18, .17, 1))]:
    material = bpy.data.materials.new(name); material.diffuse_color = color
    materials[name] = material
groups = collections.defaultdict(list)
complete_faces = []
protected_faces=[];unprotected_faces=[]
buried = 0
site_base_omitted = 0
grid_boundary_cells=0

def rectangle_points(axis,direction,plane,rect):
    u,v=[i for i in range(3) if i!=axis]
    lo=[coordinates[axis][plane]]*3;hi=lo.copy()
    lo[u],lo[v]=coordinates[u][rect[0]],coordinates[v][rect[1]]
    hi[u],hi[v]=coordinates[u][rect[2]],coordinates[v][rect[3]]
    x0,y0,z0=lo;x1,y1,z1=hi
    if axis==0 and direction==-1:return [(x0,y0,z0),(x0,y0,z1),(x0,y1,z1),(x0,y1,z0)]
    if axis==0:return [(x1,y0,z0),(x1,y1,z0),(x1,y1,z1),(x1,y0,z1)]
    if axis==1 and direction==-1:return [(x0,y0,z0),(x1,y0,z0),(x1,y0,z1),(x0,y0,z1)]
    if axis==1:return [(x0,y1,z0),(x0,y1,z1),(x1,y1,z1),(x1,y1,z0)]
    if direction==-1:return [(x0,y0,z0),(x0,y1,z0),(x1,y1,z0),(x1,y0,z0)]
    return [(x0,y0,z1),(x1,y0,z1),(x1,y1,z1),(x0,y1,z1)]

for row in coalesced_grid_planes(solid,retained,asphalt,coordinates,chunk_m=4.,parcel_protection=parcel_protection):
    axis,direction,plane=row['axis'],row['direction'],row['plane']
    grid_boundary_cells+=row['boundary_cells'];buried+=row['buried_cells'];site_base_omitted+=row['base_cells']
    current_protected=[rectangle_points(axis,direction,plane,r) for r in row['source_protected']]
    current_unprotected=[rectangle_points(axis,direction,plane,r) for r in row['source_unprotected']]
    complete_faces.extend(current_protected+current_unprotected)
    protected_faces.extend(current_protected);unprotected_faces.extend(current_unprotected)
    for label,rect,key in row['render']:
        groups[(key,'asphalt' if label%2==0 else 'soil',label>2)].append(rectangle_points(axis,direction,plane,rect))
    if plane%200==0:print('GROUND COALESCED PLANE:',axis,direction,plane,'source rectangles',len(complete_faces),flush=True)
del retained,asphalt
source_rectangles=complete_faces
expected_volume=sum(float(np.einsum('i,k,ik->',np.diff(xs),np.diff(zs),solid[:,iy,:],dtype=np.float64))*float(ys[iy+1]-ys[iy]) for iy in range(size[1]))
roof_caps=[]
if roof_cut:
    roof_caps=profile_roof_caps(np.asarray(xs),np.asarray(ys),np.asarray(zs),solid,roof_profile,chunk_m=4.,parcel_protection=parcel_protection)
    source_rectangles=protected_faces+[part for face in unprotected_faces for part in clip_profile_face(face,roof_profile)]+roof_caps
    expected_volume=profile_grid_volume(np.asarray(xs),np.asarray(ys),np.asarray(zs),solid,roof_profile,parcel_protection=parcel_protection)
    print('EXTERIOR ROOF CUT:',len(roof_caps),'cap faces; independent cropped-cell volume',expected_volume,flush=True)
import sys
sys.path.insert(0,str(Path(__file__).resolve().parent))
from ground_closed_union import build_closed_ground,apply_soil_cuts
mesh,native_area,edge_contacts,split_fans=build_closed_ground(source_rectangles,source_collection,expected_volume,sloped=roof_cut)
closed_volume_proof={key:mesh.get(key) for key in ['pre_storage_volume_m3','represented_volume_error_m3']} if roof_cut else {}
street_cavity=[];street_proof={}
if street_specs:
    represented_masks=[{'bounds':[native_coordinate(v) for v in row['bounds']]} for row in masks]
    print('STREET SOIL CUT: independent retained-ground void integral begins',flush=True)
    if len(street_specs)==1 and all(abs(profile_height(x,roof_profile)-top)<1e-7 for spec in street_specs for p in spec['polygons'] for x,z in p):
        removed=removed_flat_soil_volume(street_specs,[a,b,c,d],top,represented_masks)
    else:
        assert all(min(h for x,h in spec['subgrade_profile_m'])>low for spec in street_specs),'Street cut would pass below the retained soil stock'
        removed=removed_profile_soil_volume(street_specs,[a,b,c,d],top,represented_masks,roof_profile,parcel_rects)
    print('STREET SOIL CUT: expected removal',removed,'m3; native Boolean begins',flush=True)
    source_obj=next(obj for obj in source_collection.objects if obj.data==mesh)
    street_cavity,street_proof=apply_soil_cuts(source_obj,source_collection,street_specs,removed)
    street_proof.update(expected_final_volume_m3=expected_volume-removed,source_region_m=[a,b,c,d],method='Sequential manifold Boolean of compact closed union-outline cutters; independent polygon/profile integral retains every original void. Existing render faces are clipped separately, preserving unrelated local precision.')
non_manifold=0;bad_edges=[None]*edge_contacts
print('COURTYARD CLOSED SOURCE:',len(complete_faces),'original cell faces;',len(source_rectangles),'exact conforming rectangles',flush=True)

parts = []; reports = []; render_groups=[]; chart_fallbacks=0
for ((ix, iz), family, reserved), faces in sorted(groups.items()):
    source_face_count = len(faces)
    name = '%s_%s_%s_%s' % ('Seat' if reserved else 'Court',family, 'P%d' % ix if ix >= 0 else 'N%d' % -ix,
                              'P%d' % iz if iz >= 0 else 'N%d' % -iz)
    if roof_cut and not reserved: faces=[part for face in faces for part in clip_profile_face(face,roof_profile)]
    local_prisms=[p for p in street_prisms if overlap([ix*4.,iz*4.,(ix+1)*4.,(iz+1)*4.],p['bounds'])]
    if local_prisms:faces=[part for face in faces for part in clip_soil_face(face,local_prisms)]
    if faces: render_groups.append((name,family,faces,source_face_count))
cap_groups=collections.defaultdict(list)
for face in roof_caps:
    ix=math.floor(sum(p[0] for p in face)/len(face)/4)
    iz=math.floor(sum(p[2] for p in face)/len(face)/4)
    cap_groups[(ix,iz)].append(face)
for (ix,iz),faces in sorted(cap_groups.items()):
    name='GradeCut_soil_%s_%s'%('P%d'%ix if ix>=0 else 'N%d'%-ix,'P%d'%iz if iz>=0 else 'N%d'%-iz)
    render_groups.append((name,'soil',faces,len(faces)))
for (ix,iz),faces in sorted(chunk_soil_faces(street_cavity).items()):
    render_groups.append(('StreetCut_soil_%s_%s'%('P%d'%ix if ix>=0 else 'N%d'%-ix,'P%d'%iz if iz>=0 else 'N%d'%-iz),'soil',faces,len(faces)))
for name,family,faces,source_face_count in render_groups:
    lo = [min(point[axis] for face in faces for point in face) for axis in range(3)]
    hi = [max(point[axis] for face in faces for point in face) for axis in range(3)]
    assert max(hi[axis] - lo[axis] for axis in range(3)) <= 4.000001
    center = [(lo[axis] + hi[axis]) / 2 for axis in range(3)]
    origin = Vector((center[0], -center[2], center[1]))
    # Preserve small roof intersections in local mesh space. Converting the
    # global point to float32 before subtraction can collapse both ends onto
    # the same 46m coordinate, even though the local chart can represent them.
    vertices = [Vector((point[0]-float(origin.x), -point[2]-float(origin.y), point[1]-float(origin.z))) for face in faces for point in face]
    polygons=[];offset=0
    for face in faces:
        polygons.append(tuple(range(offset,offset+len(face))));offset+=len(face)
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], polygons)
    mesh.update()
    # Roof clipping can make pentagons; glTF's tangent exporter requires their
    # final triangulation before it evaluates the authored UV derivatives.
    bm=bmesh.new();bm.from_mesh(mesh)
    bmesh.ops.triangulate(bm,faces=list(bm.faces))
    bm.to_mesh(mesh);bm.free();mesh.update()
    for face in mesh.polygons:
        assert face.area > 1e-12,(name,face.index,float(face.area),[tuple(mesh.vertices[i].co) for i in face.vertices],tuple(origin))
    coords=np.asarray([v.co[:] for v in mesh.vertices],dtype=np.float64)
    indices=np.asarray([loop.vertex_index for loop in mesh.loops],dtype=np.int32).reshape((-1,3))
    normals,tangents,charts,fallbacks=triangle_charts(coords[indices],np.asarray(origin,dtype=np.float64),float(sets[family]['meters_per_tile']))
    chart_fallbacks+=fallbacks
    uv=mesh.uv_layers.new(name='Metres');uv.active_render=True
    uv.data.foreach_set('uv',charts.astype(np.float32).ravel())
    mesh.normals_split_custom_set(np.repeat(normals,3,axis=0).tolist())
    guide=mesh.attributes.new(name='_tangent_guide',type='FLOAT_VECTOR',domain='CORNER')
    values=np.repeat(tangents[:,[0,2,1]],3,axis=0);values[:,2]*=-1
    guide.data.foreach_set('vector',values.astype(np.float32).ravel())
    mesh.materials.append(materials[family])
    obj = bpy.data.objects.new(name, mesh); obj.location = origin
    export_collection.objects.link(obj); parts.append(obj)
    reports.append({'id': name, 'material': family, 'bounds': lo + hi,
                    'source_quads': source_face_count, 'native_faces': len(mesh.polygons),
                    'internal_caps': False})
out = root/'art/blender/orison_ground.blend'
bpy.ops.outliner.orphans_purge(do_local_ids=True,do_linked_ids=True,do_recursive=True)
export_check=export_native(root,'orison_ground',export_collection,staged_output=True)
asset=root/'game/assets/props/orison_ground.glb'
packed=work/'orison-ground-zstd19.blend';packing_report=work/'orison-ground-packing.json'
assert packed.resolve().is_relative_to(root.resolve())
packed.unlink(missing_ok=True)
subprocess.run([os.environ.get('BLEND_ZSTD_NODE','node'),str(packing_tool),str(out),str(packed),str(packing_report)],check=True)
storage=json.loads(packing_report.read_text())
assert storage['decoded_bytes_identical'] and storage['target_bytes']<100*1024*1024
os.replace(packed,out)
metadata = {'evidence_class': 'INERT', 'source_plan': plan, 'parts': reports,
            'export_check':export_check,
            'street_soil_cut':street_proof,
            'exterior_roof_cut':{'active':roof_cut,'profile_m':roof_profile,'new_cap_faces':len(roof_caps),'expected_remaining_volume_m3':expected_volume,
                                 'protected_foundation_parcels':parcel_rects,'unretained_transition_cells':transitions,
                                 'volume_proof':closed_volume_proof,'method':'Remove soil above shared authored west profile; original cavities and foundation coordinates never move.'},
            'native_storage':{'format':'seekable_zstd','level':storage['zstd_level'],'decoded_sha256':storage['decoded_sha256'],'decoded_bytes':storage['decoded_bytes'],'frames':storage['frames']},
            'cell_coordinate_encoding':'Float32 represented native planes, after the existing five-decimal source rounding.',
            'surface_phase':'Shared fabrication metre charts with whole-tile global origins and checked local fallback for microscopic Boolean intersections.',
            'uv_local_fallback_triangles':chart_fallbacks,
            'local_coordinate_precision':'Subtract represented node origin in float64 before float32 mesh storage.',
            'closed_union_non_manifold_edges': non_manifold, 'buried_quads_omitted': buried, 'site_base_quads_omitted': site_base_omitted,
            'source_edge_contacts_split': len(bad_edges), 'source_vertex_fans_split': split_fans,
            'uncoalesced_boundary_cells':grid_boundary_cells,'coalesced_boundary_rectangles':len(complete_faces),
            'native_faces': sum(row['native_faces'] for row in reports),
            'source_native_sha256': hashlib.sha256(asset.read_bytes()).hexdigest(),
            'note': 'Installed bounded subgrade and original-datum courtyard surface. Drainage, operating glazing, broader city closure and weather findings remain open; no whole-shell acceptance.'}
(root/'art/blender/orison_ground_construction.json').write_text(json.dumps(metadata, indent=2) + '\n',encoding='utf-8',newline='\n')
print('COURTYARD GRADE TRIAL:', len(parts), 'bounded material parts;', metadata['native_faces'],
      'coalesced native faces;', buried, 'buried interface quads omitted; production ground construction.', flush=True)

(root/'game/tests/fixtures/orison_ground_construction.json').write_text(json.dumps(metadata,indent=2)+'\n',encoding='utf-8',newline='\n')

(root/'game/tests/fixtures/orison_ground_construction.json').write_bytes((root/'art/blender/orison_ground_construction.json').read_bytes())
print('SOURCE PROVIDER BUILD; INDEPENDENT VALIDATION REQUIRED')
