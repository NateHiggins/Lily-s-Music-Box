"""Reconcile current native sources and an actual V2 static-box survey.

Output is an inert authoring candidate. Native soil and foundations still need
regeneration, independent inspection and composed-world verification.
"""
import argparse,copy,hashlib,json,math,re,shutil,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]

def digest(path):
    raw=path.read_bytes()
    return hashlib.sha256(raw if path.suffix in {'.blend','.glb','.bin'} else raw.replace(b'\r\n',b'\n')).hexdigest()

def subtract(bounds,mask):
    lo=[max(bounds[i],mask[i]) for i in range(3)];hi=[min(bounds[i+3],mask[i+3]) for i in range(3)]
    if any(hi[i]<=lo[i] for i in range(3)):return [bounds]
    a,b,c,d,e,f=bounds;x,y,z,u,v,w=lo+hi
    return [r for r in [[a,b,c,x,e,f],[u,b,c,d,e,f],[x,b,c,u,y,f],[x,v,c,u,e,f],[x,y,c,u,v,z],[x,y,w,u,v,f]] if all(r[i+3]>r[i] for i in range(3))]

def covered(bounds,masks):
    pieces=[bounds]
    for mask in masks:
        pieces=[part for p in pieces for part in subtract(p,mask)]
        if not pieces:return True
    return False

def plan(layout,native,survey,previous,span):
    if survey['failures']!=0:raise ValueError('Failed runtime survey')
    if len(span)!=2 or not all(math.isfinite(v) for v in span) or span[0]>=span[1]:raise ValueError('Invalid reveal span')
    for row in native['records']:
        b=row['bounds']
        if len(b)!=6 or not all(math.isfinite(v) for v in b) or not all(b[i]<b[i+3] for i in range(3)):raise ValueError('Invalid native bounds')
    low=float(previous['soil_bottom']);top=float(previous['asphalt_y'][1]);slab=float(layout['dimensions']['slab_thickness'])
    levels={r['id']:r['y'] for r in layout['levels']};occupation=[];surfaces=[]
    rooms=[r for r in layout['spaces'] if r['level'] in ['B1','F01'] and not r.get('open_shell')]
    for room in rooms:
        a,b,c,d=room['rect'];bottom=levels[room['level']]-slab
        occupation.append(dict(owner=room['id'],bounds=[a,bottom,b,c,0,d],kind='current_occupied_space'))
        surfaces.append(dict(owner=room['id'],bounds=[a,low,b,c,.05,d],kind='retained_room_floor_or_basement_roof'))
    for shaft in layout['risers']:
        if shaft['from_y']>=0:raise ValueError('Review a riser without ground-level continuity: '+shaft['id'])
        a,b,c,d=shaft['rect']
        # This external masonry stack has its own native footing below the
        # shaft. Do not excavate soil beneath that footing down to the generic
        # legacy reservation bottom; the fresh native pad supplies its mask.
        bottom=max(low,float(shaft['from_y'])) if shaft['id']=='C_STOVE_FLUE' else low
        occupation.append(dict(owner=shaft['id'],bounds=[a,bottom,b,c,0,d],kind='retained_service_or_shaft_reservation'))
    window=next(r for r in layout['windows'] if r['id']=='B1_BOILER_AIR_E')
    half=window['width']/2;y=levels[window['level']]+window['sill']
    air=dict(owner=window['id']+'/RetainedReveal',bounds=[span[0],y,window['center'][1]-half,span[1],y+window['height'],window['center'][1]+half],kind='retained_window_throat_reservation',note='Exact generated masonry reveal, not an enlarged window.')
    occupation.append(air)
    retained=copy.deepcopy(native['records']);redundant=[];unclassified=[]
    masks=[r['bounds'] for r in occupation]
    for row in survey['records']:
        if row.get('shape_type')!='BoxShape3D':raise ValueError('Complex AABB cannot be a solid mask')
        bounds=[round(v,5) for v in row['bounds']]
        if not all(math.isfinite(v) for v in bounds) or not all(bounds[i]<bounds[i+3] for i in range(3)):raise ValueError('Invalid runtime bounds')
        if bounds[1]>=top or bounds[4]<=low:continue
        clipped=list(bounds);clipped[1]=max(low,bounds[1]);clipped[4]=min(top,bounds[4])
        if covered(clipped,masks):redundant.append(row['owner']);continue
        if not row['aligned']:
            unclassified.append(row['owner']);continue
        axes=[row['pose'][key] for key in ['x_axis','y_axis','z_axis']]
        active=[[i for i,v in enumerate(axis) if abs(v)>.00003] for axis in axes]
        if not all(len(a)==1 for a in active) or len({a[0] for a in active})!=3 or not all(abs(sum(v*v for v in a)-1)<.00006 for a in axes):raise ValueError('Invalid claimed aligned basis')
        retained.append(dict(owner=row['owner'],id=row['shape_owner'],bounds=bounds,kind='actual_axis_aligned_box'))
    if unclassified:raise ValueError('Unaligned grade boxes outside occupied reservations: '+str(unclassified))
    for row in native['records']:
        if row['kind']!='retained_continuous_paving_substrate':continue
        a,b,c,d,e,f=row['bounds']
        occupation.append(dict(owner='ServiceAlley/'+row['id'],bounds=[a,b,c,d,.05,f],kind='retained_paving_volume_and_joints'))
        surfaces.append(dict(owner=row['owner'],id=row['id'],bounds=[a,low,c,d,.05,f],kind='retained_paving_envelope'))
    surfaces.extend(copy.deepcopy(r) for r in retained if r['bounds'][4]>=top-.00003)
    # The outer well reservation is supplied separately by the ground builder.
    result={k:copy.deepcopy(previous[k]) for k in ['evidence_class','region','soil_bottom','asphalt_y']}
    result.update(retained_solids=retained,occupation_reservations=occupation,surface_exclusions=surfaces,bindings=copy.deepcopy(native['bindings']),
        method='Fresh classified editable native components and actual aligned static collision boxes. Runtime boxes wholly covered by current occupied/shaft reservations are redundant and omitted after exact box-union subtraction. Complex native AABBs never become solid masks. Independent native/installed verification remains required.',
        open=copy.deepcopy(previous.get('open',[])))
    return result,dict(evidence_class='INERT',native_records=len(native['records']),runtime_boxes=len(survey['records']),redundant_runtime_boxes=redundant,retained_records=len(retained),unclassified_boxes=unclassified,scope='Authoring discovery only; no native or runtime acceptance.')

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    for name in ['native','survey','out','report']:parser.add_argument('--'+name,type=Path,required=True)
    parser.add_argument('--discovery-dir',type=Path,default=ROOT/'art/data/orison_ground/discovery')
    args=parser.parse_args();native=json.loads(args.native.read_text());survey=json.loads(args.survey.read_text())
    for p,h in native['bindings'].items():
        if digest(ROOT/p)!=h:raise ValueError('Native discovery stale: '+p)
    sys.path.insert(0,str(ROOT/'tools'));from run_receipt import runtime_inputs_sha256
    if runtime_inputs_sha256(ROOT)!=survey['source']['runtime_inputs_sha256']:raise ValueError('Runtime discovery stale')
    if native['receiving_registration']!=survey['poses']['receiving']:raise ValueError('Native registration does not match fresh runtime')
    layout=json.loads((ROOT/'game/data/orison_v2_blockout.json').read_text());previous=json.loads((ROOT/'art/data/orison_ground/retained_grade_source.json').read_text())
    text=(ROOT/'game/scripts/generated/v2_exterior_masonry.gd').read_text();match=re.search(r'"B1_BOILER_AIR_E": Vector2\(([^,]+),([^\)]+)\)',text)
    if not match:raise ValueError('Missing generated reveal span')
    result,report=plan(layout,native,survey,previous,[float(v) for v in match.groups()])
    for relative in ['game/data/orison_v2_blockout.json','art/data/building_layout.json','game/data/orison_v2/exterior/regions.json','game/data/orison_v2/exterior/exterior_geometry.json','game/data/orison_v2/exterior/street_frame.json','game/scripts/building/orison_v2_blockout.gd','game/scripts/building/orison_v2_basement.gd','game/scripts/building/orison_v2_bodega_receiving.gd','game/scripts/building/orison_v2_street_boundaries.gd','art/blender/city_shells.blend']:
        result['bindings'][relative]=digest(ROOT/relative)
    # Ignored temporary files cannot be required in a fresh checkout.
    discovery=args.discovery_dir.resolve()
    if not discovery.is_relative_to(ROOT):raise ValueError('Discovery must remain in repository')
    discovery.mkdir(parents=True,exist_ok=True)
    for source,name in [(args.survey,'runtime_survey.json'),(args.native,'native_sources.json')]:
        dest=discovery/name
        if source.resolve()!=dest:shutil.copyfile(source,dest)
        result['bindings'][dest.relative_to(ROOT).as_posix()]=digest(dest)
    result['runtime_survey']=(discovery/'runtime_survey.json').relative_to(ROOT).as_posix()
    for relative,expected in survey['source']['test_dependencies'].items():
        if digest(ROOT/relative)!=expected:raise ValueError('Survey helper changed: '+relative)
        result['bindings'][relative]=expected
    for relative in ['tools/plan_v2_retained_grade.py','tools/grade_source_snapshot.py','tools/run_receipt.py','tools/audit_orison_v2_completeness.py']:
        result['bindings'][relative]=digest(ROOT/relative)
    for path in [args.out,args.report]:path.parent.mkdir(parents=True,exist_ok=True)
    args.out.write_text(json.dumps(result,indent=2)+'\n',newline='\n');args.report.write_text(json.dumps(report,indent=2)+'\n',newline='\n')
    print('Fresh grade candidate:',len(result['retained_solids']),'retained;',len(report['redundant_runtime_boxes']),'redundant boxes omitted')

if __name__=='__main__':main()
