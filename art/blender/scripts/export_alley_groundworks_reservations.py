"""INERT source-bound construction clearances for fitting the soil prototype.

These are deliberately labelled reservations, not native solid subtraction
volumes. Flat bedding bottoms are actual support datums; pipe air and the well
remain unfilled. No whole complex mesh AABB is claimed to be an exact solid.
"""
from pathlib import Path
import hashlib
import json
import bpy
import bmesh
from mathutils import Vector

root = next(path for path in Path(__file__).resolve().parents if (path/'game/project.godot').is_file())
base=root/'art/blender'
source=base/'alley_groundworks.blend'
meta_path=base/'alley_groundworks_construction.json'
meta=json.loads(meta_path.read_text(encoding='utf-8'))
asset=root/'game/assets/props/alley_groundworks.glb'
assert hashlib.sha256(asset.read_bytes()).hexdigest()==meta['asset_sha256']
bpy.ops.wm.open_mainfile(filepath=str(source))
construction=bpy.data.collections['AlleyGroundworksConstruction']
construction.hide_viewport=False
bpy.context.view_layer.update()
rows={r['id']:r for r in meta['closed_source_pieces']}
bounds={}
for name,row in rows.items():
    obj=construction.objects[name]
    bm=bmesh.new();bm.from_mesh(obj.data)
    assert all(e.is_manifold for e in bm.edges)
    assert abs(bm.calc_volume(signed=True)-row['volume_m3'])<1e-7
    points=[obj.matrix_world@v.co for v in bm.verts];bm.free()
    bounds[name]=[round(min(p.x for p in points),5),round(min(p.z for p in points),5),round(-max(p.y for p in points),5),
                  round(max(p.x for p in points),5),round(max(p.z for p in points),5),round(-min(p.y for p in points),5)]
def envelope(names):
    return [min(bounds[n][i] for n in names) for i in range(3)] + [max(bounds[n][i] for n in names) for i in range(3,6)]
well_names=[name for name in bounds if name.startswith('Well')]
well=envelope(well_names)
assert well[1]==-2.45,(well,[(n,bounds[n]) for n in well_names if bounds[n][1]<-2.4])
reservations=[{'owner':'BoilerWell/ConstructionAndAir','bounds':[well[0],well[1],well[2],well[3],.05,well[5]],
               'kind':'source_bound_well_construction_and_air_reservation',
               'note':'Retain soil below the actual well-wall bottoms. The floor bears into those sides; well air and concrete remain unfilled.'}]
for i in range(3):
    names=[name for name in bounds if name.startswith('Catch%d_'%i)]
    b=envelope(names);b[4]=.05
    reservations.append({'owner':'Catch%d/Construction'%i,'bounds':b,'kind':'source_bound_catch_construction_reservation'})
collector=meta['local_collector'];a,b=collector['main_axis']
reservations.append({'owner':'LocalCollector/Trench','bounds':[a[0]-.115,min(a[1],b[1])-.13,a[2]-.04,
                     a[0]+.115,max(a[1],b[1])+.13,b[2]],'kind':'source_bound_collector_service_clearance',
                     'note':'Clearance envelope around the hollow pipe and bells; not a solid-volume claim. Each saddle has its own seated bedding datum.'})
for branch in collector['branches']:
    x,z=branch['centre'];radius=.08
    reservations.append({'owner':'LocalCollector/'+branch['id'],'bounds':[x-radius,branch['collector_y']-.13,z-radius,
                         x+radius,branch['top_y']+.02,z+radius],'kind':'source_bound_drain_leg_clearance'})
for bed in collector['saddle_beds']:
    reservations.append({'owner':'LocalCollector/'+bed['id'],'bounds':bounds[bed['id']],
                         'kind':'source_bound_saddle_bedding_reservation',
                         'note':'Reserved construction envelope, with actual flat underside seated directly on the remaining native soil.'})
bindings={str(path.relative_to(root)).replace('\\','/'):hashlib.sha256(path.read_bytes()).hexdigest()
          for path in [source,asset,meta_path]}
result={'evidence_class':'INERT','reservations':reservations,'bindings':bindings,
        'well_wall_bottom':well[1],'well_mouth':meta['well'],
        'note':'Native closed-piece validation and explicit construction/air reservations only. Soil capacity and waterproofing are unaccepted.'}
(base/'alley_groundworks_reservations.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8',newline='\n')
print('INERT GROUNDWORKS SOIL RESERVATIONS:',len(reservations),'source-bound envelopes; actual wall bed',well[1],flush=True)
