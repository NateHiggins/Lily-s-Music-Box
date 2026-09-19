"""Six-home sanitary/appliance source batch. No engine or Blender execution."""
import argparse
import copy
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[4]
OUT=Path(__file__).resolve().parent
BASE='7fe366c'
LAYOUT='game/data/orison_v2_blockout.json'
FURNITURE='game/data/orison_v2/domestic_furniture.json'
FITTINGS='game/data/orison_v2/domestic_fittings.json'
PROGRAM='game/data/orison_v2/upper_floor_programs.json'
PROBES='game/tests/data/v2_upper_floor_probes.json'
UNITS=['5A','5B','5C','6A','6B','6C']
PI=math.pi
# Kind, x/z, facing, standing x/z. Floor-local Y stays zero.
PLACEMENTS={
 'A':[
  ('wc',[-6.18,-11.85],PI,[-6.18,-10.9]),
  ('SHOWER',[-7.75,-11.85],PI,[-7.5,-11.0]),
  ('SINK',[-7.94,-10.3],-PI/2,[-7.0,-10.3]),
  ('KITCHEN_SINK',[-10.77,-8.65],-PI/2,[-9.65,-8.65]),
  ('STOVE',[-10.77,-7.25],-PI/2,[-9.55,-7.4]),
  ('FRIDGE',[-8.76,-8.4],PI/2,[-9.65,-7.35])],
 'B':[
  ('wc',[-7.15,5.85],0,[-7.15,4.9]),
  ('SHOWER',[-8.75,5.85],0,[-8.3,5.0]),
  ('SINK',[-8.88,4.4],-PI/2,[-7.94,4.4]),
  ('KITCHEN_SINK',[-6.92,7.35],PI/2,[-8.04,7.35]),
  ('STOVE',[-6.92,9.1],PI/2,[-8.15,8.75]),
  ('FRIDGE',[-6.92,10.85],PI/2,[-8.07,10.1])],
 'C':[
  ('wc',[3.3,5.4],PI/2,[2.25,5.4]),
  ('SHOWER',[3.23,4.35],PI,[2.25,4.7]),
  ('SINK',[1.05,4.2],PI,[1.05,5.1]),
  ('KITCHEN_SINK',[4.75,4.22],PI,[4.3,5.15]),
  ('STOVE',[6.68,4.42],PI/2,[5.5,4.42]),
  ('FRIDGE',[6.64,5.55],PI/2,[5.5,4.8])],
}

def module(path,name):
    spec=importlib.util.spec_from_file_location(name,ROOT/path)
    mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod);return mod

def baseline(path):
    return json.loads(subprocess.check_output(['git','show',BASE+':'+path],cwd=ROOT).decode('utf-8'))

def load(path):return json.loads((ROOT/path).read_text(encoding='utf-8'))
def write(path,value):
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_bytes((json.dumps(value,indent=2)+'\n').encode('utf-8'))

def bounds(record):
    kind=record['kind']
    if 'bounds' in record:return record['bounds']
    if kind=='shower':return [[-.3775,0,-.3775],[.3775,2.1,.3775]]
    if kind=='sink' and record['properties']['fixture']=='bath_sink':return [[-.33,0,-.26],[.33,1.2,.24]]
    if kind=='sink':return [[-.34,.7,-.26],[.76,1.25,.25]]
    if kind=='stove':return [[-.35,0,-.40],[.35,1.25,.32]]
    return [[-.38,0,-.43],[.38,1.67 if record['properties']['monitor_top'] else 1.25,.34]]

def make():
    old=module('design/astra/work/v2_apartment_batches_01/build.py','upper_fixture_extract')
    source=load('game/data/building_layout.json')
    records={r['id']:r for f in source['floors'] for r in f.get('furniture',[])}
    markers={r['id']:r for f in source['floors'] for r in f.get('markers',[]) if 'id' in r}
    ns=old.extractors()
    layout=baseline(LAYOUT);furniture=baseline(FURNITURE);fittings=baseline(FITTINGS)
    additions=[];new_furniture=[];new_fittings=[];targets=[]
    for unit in UNITS:
        level='F0'+unit[0]
        for kind,point,yaw,stance in PLACEMENTS[unit[1]]:
            identity=unit+'_wc' if kind=='wc' else level+'_'+unit+'_'+kind+'_01'
            room=level+'_'+unit[1]+('_BATH' if kind in ['wc','SINK','SHOWER'] else '_KITCHEN')
            position=[point[0],0,point[1]]
            anchor=dict(id=identity,level=level,space=room,position=position,yaw=yaw,kind='furniture' if kind=='wc' else 'fixture')
            additions.append(anchor)
            additions.append(dict(id=identity+'_STANCE',level=level,space=room,position=[stance[0],0,stance[1]],
                                  yaw=math.atan2(-(point[0]-stance[0]),-(point[1]-stance[1])),kind='clearance'))
            targets.append(dict(id=identity,level=level,point=stance))
            if kind=='wc':new_furniture.append(old.furniture_record(identity,records,ns))
            else:new_fittings.append(old.fitting_record(identity,markers))
            if kind=='KITCHEN_SINK':
                stand=unit+'_sink_support'
                new_furniture.append(old.furniture_record(stand,records,ns))
                additions.append(dict(anchor,id=stand,kind='furniture'))
    layout['anchors']+=additions;furniture['furniture']+=new_furniture;fittings['fittings']+=new_fittings
    return {LAYOUT:layout,FURNITURE:furniture,FITTINGS:fittings},new_furniture+new_fittings,targets

def validate(outputs,records,targets):
    old=module('design/astra/work/v2_apartment_batches_01/build.py','upper_fixture_geometry')
    geo=module('design/astra/work/v2_apartment_doors_batch_01/check.py','upper_fixture_leaves')
    layout=outputs[LAYOUT];anchors={a['id']:a for a in layout['anchors']};spaces={r['id']:r for r in layout['spaces']}
    footprints=[]
    for record in records:
        anchor=anchors[record['id']];room=spaces[anchor['space']]['rect']
        rect=old.world_rect(bounds(record),(record['id'],anchor['space'],anchor['position'],anchor['yaw'],None))
        assert all([rect[0]>=room[0]+.07-1e-8,rect[1]>=room[1]+.07-1e-8,rect[2]<=room[2]-.07+1e-8,rect[3]<=room[3]-.07+1e-8]),('outside room',record['id'],rect,room)
        footprints.append(dict(id=record['id'],level=anchor['level'],room=anchor['space'],rect=rect,kind=record['kind']))
    def support_pair(a,b):
        return any({a,b}=={u+'_sink_support','F0'+u[0]+'_'+u+'_KITCHEN_SINK_01'} for u in UNITS)
    for i,a in enumerate(footprints):
        for b in footprints[i+1:]:
            if a['level']!=b['level'] or support_pair(a['id'],b['id']):continue
            assert not geo.overlaps(geo.rect_polygon(a['rect']),geo.rect_polygon(b['rect'])),('fixture overlap',a['id'],b['id'])
    program=load(PROGRAM)
    additional=[(r['id'],r['level'],r['rect']) for r in footprints]
    route=module('design/astra/work/v2_upper_floors_01/routes.py','upper_fixture_routes')
    routes=route.check(layout,program,additional,targets)
    # Sweep the native fridge food/ice leaf and reserve the stove's open
    # drop-down door. Conservative hardware thickness is included. These
    # estimates are not a replacement for actual animated collision tests.
    motion_poses=0
    for record in records:
        if record['kind'] not in ['fridge','stove']:continue
        a=anchors[record['id']];x,_,z=a['position'];yaw=a['yaw'];room=spaces[a['space']]['rect']
        def world_polygon(points):
            return [[x+p[0],z+p[1]] for p in [geo.rotate(p,yaw) for p in points]]
        motions=[]
        if record['kind']=='fridge':
            electric=record['properties']['monitor_top'];width=.72 if electric else .70;front=-.32 if electric else -.29
            for n in range(211):
                points=[geo.rotate(p,math.radians(n*.5)) for p in geo.rect_polygon([0,-.12,width,.025])]
                motions.append(world_polygon([[p[0]-width/2,p[1]+front] for p in points]))
            if not electric:motions.append(world_polygon(geo.rect_polygon([-.31,-.63,.31,-.25])))
        else:motions.append(world_polygon(geo.rect_polygon([-.26,-.76,.26,-.28])))
        for polygon in motions:
            assert all(room[0]+.07<=p[0]<=room[2]-.07 and room[1]+.07<=p[1]<=room[3]-.07 for p in polygon),('appliance motion outside room',record['id'])
            for other in footprints:
                if other['level']!=a['level'] or other['id']==record['id']:continue
                assert not geo.overlaps(polygon,geo.rect_polygon(other['rect'])),('appliance sweep hits fixture',record['id'],other['id'])
            target=next(t for t in targets if t['id']==record['id'])
            assert geo.distance(target['point'],polygon)>=.38,('appliance swing hits stance',record['id'],target['point'])
            # Open room doors must not occupy appliance operating space.
            for door in layout['doors']:
                if door['id'] not in program['doors'] or door['level']!=a['level']:continue
                spec=program['doors'][door['id']]
                offset=geo.rotate([0,spec['mount_offset']],door['yaw'])
                leaf=[[p[i]+offset[i] for i in [0,1]] for p in geo.leaf_polygon(door,spec['swing_out'],0 if spec['leaf_state']=='locked' else 100)]
                assert not geo.overlaps(polygon,leaf),('appliance swing hits open room door',record['id'],door['id'])
            motion_poses+=1
    return dict(footprints=footprints,routes=routes,appliance_motion_poses=motion_poses)

def run(apply=False):
    outputs,records,targets=make();receipt=validate(outputs,records,targets)
    # Existing rows and all other layout fields remain exact; refuse dirty
    # overlapping source instead of overwriting another category's work.
    for path,key in [(LAYOUT,'anchors'),(FURNITURE,'furniture'),(FITTINGS,'fittings')]:
        current=load(path)
        if apply:
            original=baseline(path)
            own_ids={r['id'] for r in outputs[path][key]}-{r['id'] for r in original[key]}
            # Regenerate this packet's own rows, preserving every baseline
            # record/property and refusing unrelated additions or mutations.
            stripped=copy.deepcopy(current)
            stripped[key]=[r for r in current[key] if r['id'] not in own_ids]
            assert stripped==original,('unexpected concurrent source',path)
        else:assert current==outputs[path],('installed data does not match generator',path)
        assert outputs[path][key][:len(baseline(path)[key])]==baseline(path)[key]
    probes=copy.deepcopy(load(PROBES))
    for floor in probes['floors']:
        paths=next(f['room_routes'] for f in receipt['routes']['floors'] if f['level']==floor['level'])
        for room in floor['rooms']:room['point']=next(p['points'][-1] for p in paths if p['room']==room['id'])
    if apply:
        for path,value in outputs.items():
            if path==FURNITURE:(ROOT/path).write_bytes((json.dumps(value,separators=(',',':'))+'\n').encode('utf-8'))
            elif path==LAYOUT:
                original=subprocess.check_output(['git','show',BASE+':'+path],cwd=ROOT).decode('utf-8')
                start=original.index('[',original.index('"anchors"'));_,size=json.JSONDecoder().raw_decode(original[start:]);end=start+size-1
                rows=value['anchors'][len(baseline(path)['anchors']):]
                text=original[:end].rstrip()+',\n'+',\n'.join('    '+json.dumps(r,separators=(',',':')) for r in rows)+'\n  '+original[end:]
                (ROOT/path).write_bytes(text.encode('utf-8'))
            else:write(ROOT/path,value)
        write(ROOT/PROBES,probes)
    (OUT/'routes.json').write_bytes((json.dumps(receipt.pop('routes'),separators=(',',':'))+'\n').encode('utf-8'))
    receipt.update(status='SOURCE_PASS_RUNTIME_PENDING',godot='NOT_RUN',base=BASE,units=UNITS,new_furniture=12,new_fittings=30,new_anchors=78,
                   total_furniture=len(outputs[FURNITURE]['furniture']),total_fittings=len(outputs[FITTINGS]['fittings']),
                   targets=targets,canonical_variants=[r for r in records if r['kind']=='fridge'],
                   output_hashes={p:hashlib.sha256(json.dumps(v,sort_keys=True).encode()).hexdigest() for p,v in outputs.items()})
    write(OUT/'checks.json',receipt)
    inventory=load('design/astra/work/v2_upper_floors_01/current_inventory.json')
    for row in inventory['units']:
        if row['unit'] not in UNITS:continue
        unit=row['unit']
        row['furniture']=[r['id'] for r in records if r['id'].startswith(unit+'_')]
        row['fittings']=[r['id'] for r in records if r.get('unit')==unit]
        row['status']='SANITARY_APPLIANCES_SOURCE'
        row['pending']=['remaining furnishings and accessories','installed heat emitters','room lighting',
                        'resident migration','water simulation and physical utility distribution proof','runtime and visual proof']
    inventory['totals'].update(furniture=receipt['total_furniture'],fittings=receipt['total_fittings'])
    inventory.update(batch='v2_upper_fixtures_01',sanitary_appliance_homes=12,
                     limits='Six furnished source cores plus six upper homes with sanitary/appliance categories. Upper sleep, living, storage, work, lighting and installed heat remain pending. No runtime completion claim.')
    write(OUT/'current_inventory.json',inventory)
    print(json.dumps({k:v for k,v in receipt.items() if k in ['status','new_furniture','new_fittings','new_anchors','appliance_motion_poses','total_furniture','total_fittings']}))

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--apply',action='store_true');run(p.parse_args().apply)
