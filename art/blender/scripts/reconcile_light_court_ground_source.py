"""Reconcile only the reviewed public-court boxes and replayed source bindings.

First migration requires --survey from the approved Godot lane's actual named
box survey. Later --check verifies the already reconciled authoring map. No
rotated-box or joined-mesh AABB is admitted as an exact terrain subtraction.
"""
from pathlib import Path
import argparse, collections, hashlib, json, struct, subprocess

ROOT = Path(__file__).resolve().parents[3]
PLAN = ROOT / 'art/data/orison_ground/retained_grade_source.json'
BASELINE = '619e88348291fc04d62f206a73516e2890484bf3'
LAYOUT = 'game/data/orison_v2_blockout.json'
DEPENDENCIES = ['orison_foundations','ground_core_transfer','rear_wing_a_support','rear_wing_c_support']

def source_hash(path):
    raw=path.read_bytes()
    if path.suffix not in ['.blend','.glb']:raw=raw.replace(b'\r\n',b'\n')
    return hashlib.sha256(raw).hexdigest()

def baseline_blob(relative):
    return subprocess.check_output(['git','show',BASELINE+':'+relative],cwd=ROOT)

def geometric(data):
    if isinstance(data,dict):
        return {k:round(v,10) if k in ['native_area_before_clip_m2','native_area_after_clip_m2'] else geometric(v)
                for k,v in data.items() if '_sha256' not in k and not k.endswith('_hash') and k not in ['bindings','source_bindings']}
    if isinstance(data,list):return [geometric(v) for v in data]
    return data

def glb_geometry(raw):
    size=struct.unpack_from('<I',raw,12)[0]
    document=json.loads(raw[20:20+size]);buffer=raw[28+size:]
    arrays=[];counts={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}
    kinds={5126:'f',5125:'I',5123:'H',5121:'B'}
    for accessor in document['accessors']:
        view=document['bufferViews'][accessor['bufferView']]
        assert 'byteStride' not in view
        offset=view.get('byteOffset',0)+accessor.get('byteOffset',0)
        count=counts[accessor['type']]
        values=struct.unpack_from('<'+kinds[accessor['componentType']]*(accessor['count']*count),buffer,offset)
        arrays.append([values[i:i+count] for i in range(0,len(values),count)])
    records=[]
    for mesh in document['meshes']:
        for primitive in mesh['primitives']:
            attributes=[arrays[index] for _,index in sorted(primitive['attributes'].items())]
            vertices=[sum(row,()) for row in zip(*attributes)]
            indices=[row[0] for row in arrays[primitive['indices']]]
            assert len(indices)%3==0
            triangles=[tuple(vertices[index] for index in indices[i:i+3]) for i in range(0,len(indices),3)]
            records.append(collections.Counter(min(r,r[1:]+r[:1],r[2:]+r[:2]) for r in triangles))
    return document,records

def expected_boxes(layout):
    levels={r['id']:r['y'] for r in layout['levels']}
    platforms={r['id']:r for r in layout['platforms']}
    names=['B1_PUBLIC_LANDING_E','F01_PUBLIC_LANDING_S','F01_PUBLIC_LANDING_N','F01_PUBLIC_LANDING_W',
           'B1_PUBLIC_LANDING_W_SHAFT_1','B1_PUBLIC_LANDING_W_SHAFT_3',
           'F01_PUBLIC_LANDING_W_SHAFT_1','F01_PUBLIC_LANDING_W_SHAFT_3',
           'B1_PRIMARY_STAIR_BASE','F01_LIGHT_COURT_BASE']
    result={}
    def add(owner,bounds):result['OrisonV2Blockout/'+owner]=[round(v,5) for v in bounds]
    depth=layout['dimensions']['slab_thickness']
    for name in names:
        row=platforms[name];a,b,c,d=row['rect'];y=levels[row['level']]
        add(name+'/Collision',[a,y-depth,b,c,y,d])
    stair=next(r for r in layout['stairs'] if r['id']=='PRIMARY_B1_F01')
    x,z=stair['origin'];width=stair['width'];gap=stair['gap'];rise=stair['rise'];tread=stair['tread']
    count=stair['risers_per_flight'];run=tread*count;half=rise*count;base=levels[stair['from']]
    assert (x,z,width,gap,count)==(1.4,-3.1,1.05,1.,10)
    for i in range(count):
        add(f"{stair['id']}/FlightA_Step{i:02}/Collision",[x,base+rise*i,z+tread*i,x+width,base+rise*(i+1),z+tread*(i+1)])
        end=z+run+stair['landing_depth']-tread*i
        add(f"{stair['id']}/FlightB_Step{i:02}/Collision",[x+width+gap,base+half+rise*i,end-tread,x+2*width+gap,base+half+rise*(i+1),end])
    add(stair['id']+'/HalfLanding/Collision',[x,base+half-depth,z+run,x+2*width+gap,base+half,z+run+stair['landing_depth']+.7])
    assert len(result)==31
    return result

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--survey',type=Path)
    parser.add_argument('--check',action='store_true')
    args=parser.parse_args()
    plan=json.loads(PLAN.read_text(encoding='utf-8'))
    if 'light_court_reconciliation' in plan:
        assert len(plan['retained_solids'])==900
        assert plan['light_court_reconciliation']['moved_boxes']==30
        expected=expected_boxes(json.loads((ROOT/LAYOUT).read_text(encoding='utf-8')))
        actual={r['owner']:r['bounds'] for r in plan['retained_solids'] if r['owner'] in expected}
        assert actual==expected,'Reviewed court mask bounds are stale'
        assert sum(r['owner']=='OrisonV2Blockout/F01_LIGHT_COURT_BASE/Collision' for r in plan['retained_solids'])==1
        for relative,expected in plan['bindings'].items():assert source_hash(ROOT/relative)==expected,relative
        print('Light-court ground reconciliation is current; 900 classified retained masks.')
        return
    assert not args.check,'Light-court ground reconciliation is pending'
    assert args.survey,'First migration requires --survey from the actual canonical collision world'
    before=json.loads(baseline_blob('art/data/orison_ground/retained_grade_source.json'))
    assert plan==before,'Unrelated ground authoring changes require their own migration'
    assert len(plan['retained_solids'])==899
    allowed={LAYOUT}|{f'art/blender/{name}_construction.json' for name in DEPENDENCIES}
    for relative,expected in plan['bindings'].items():
        if relative not in allowed:assert source_hash(ROOT/relative)==expected,relative
    replay=[]
    for name in DEPENDENCIES:
        relative=f'art/blender/{name}_construction.json'
        old=json.loads(baseline_blob(relative));current=json.loads((ROOT/relative).read_text(encoding='utf-8'))
        assert geometric(old)==geometric(current),'Reinspect dependent source geometry: '+name
        asset=f'game/assets/props/{name}.glb'
        assert glb_geometry(baseline_blob(asset))==glb_geometry((ROOT/asset).read_bytes()),'Reinspect dependent export attributes: '+name
        replay.append({'owner':name,'geometry_equal':True,'source_plan_sha256':source_hash(ROOT/relative)})
    layout=json.loads((ROOT/LAYOUT).read_text(encoding='utf-8'))
    expected=expected_boxes(layout)
    survey=json.loads(args.survey.read_text(encoding='utf-8'))
    assert survey['failures']==[] and survey['layout_sha256']==source_hash(ROOT/LAYOUT)
    actual={r['owner']:r for r in survey['records']}
    assert len(actual)==31 and actual.keys()==expected.keys()
    for owner,row in actual.items():
        assert row['shape_kind']=='BoxShape3D' and row['basis_identity'] is True
        assert [round(v,5) for v in row['bounds']]==expected[owner],owner
    reservation=next(r for r in plan['occupation_reservations'] if r['owner']=='B1_PUBLIC_CORE')
    def contained(bounds):
        return all(bounds[i]>=reservation['bounds'][i] and bounds[i+3]<=reservation['bounds'][i+3] for i in range(3))
    changed=0
    for row in plan['retained_solids']:
        if row['owner'] not in expected:continue
        assert row['kind']=='actual_axis_aligned_box' and contained(row['bounds']) and contained(expected[row['owner']])
        row['bounds']=expected[row['owner']];changed+=1
    assert changed==30
    well_owner='OrisonV2Blockout/F01_LIGHT_COURT_BASE/Collision'
    assert contained(expected[well_owner])
    well={'owner':well_owner,'id':well_owner+'/source_box','bounds':expected[well_owner],'kind':'actual_axis_aligned_box'}
    plan['retained_solids'].append(well)
    changed=0
    for row in plan['surface_exclusions']:
        if row['owner'] not in expected:continue
        assert contained(row['bounds']) and contained(expected[row['owner']])
        row['bounds']=expected[row['owner']];changed+=1
    assert changed==6
    plan['surface_exclusions'].append(dict(well))
    for relative in allowed:plan['bindings'][relative]=source_hash(ROOT/relative)
    plan['light_court_reconciliation']={
        'evidence_class':'INERT','baseline_commit':BASELINE,
        'previous_layout_sha256_lf':before['bindings'][LAYOUT],
        'layout_sha256_lf':source_hash(ROOT/LAYOUT),'moved_boxes':30,'added_boxes':1,
        'replayed_dependencies':replay,
        'method':'Thirty-one actual identity-basis collision boxes match the authored platforms and stair dimensions. Thirty masks move and one court slab is added; every before/after volume is inside the unchanged B1 public-core reservation. The same containment applies to the six moved surface exclusions and new slab exclusion. No transfer-mesh bounding box enters the soil subtraction. Exact oriented export triangles, normals, UVs and tangents of the four bound foundation/support dependencies are preserved after replay.'}
    PLAN.write_text(json.dumps(plan,indent=2)+'\n',encoding='utf-8',newline='\n')
    print('Reconciled 30 moved boxes, the new slab and four replayed geometry-identical dependencies; unrelated owners preserved.')

if __name__=='__main__':main()
