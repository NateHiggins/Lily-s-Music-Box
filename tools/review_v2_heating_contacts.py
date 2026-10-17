"""Bounded engineering disposition of an actual native triangle diagnostic."""
from pathlib import Path
import json,argparse,hashlib
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--diagnostic',type=Path,required=True)
parser.add_argument('--build-dir',type=Path,required=True)
parser.add_argument('--out',type=Path,required=True)
args=parser.parse_args()
report_path=args.diagnostic;report=json.loads(report_path.read_text())
build=args.build_dir;native=json.loads((build/'native_review.json').read_text())
allowed_native={native['native_sha256']}
package_path=build/'native_package.json'
if package_path.is_file():
    package=json.loads(package_path.read_text())
    assert not package['failures'] and package['source_sha256']==native['native_sha256']
    assert package['geometry_sha256_before']==package['geometry_sha256_after']
    allowed_native.add(package['native_sha256'])
assert report['native_sha256'] in allowed_native,'Contact report describes a different native assembly'
supports=json.loads((build/'refit_supported_native.json').read_text())
plan=json.loads((build/'passages.json').read_text())
passages={p['id']:p for p in native['passages']}
by_support={p['id']:p for p in supports['parts']}
bearings={p['id']:p for p in native['main_supports']}
tails={p['id']:p for p in native['tailpieces']}
stubs={p['id']:p['points_local_godot'][-1][1] for p in json.loads((build/'routes.json').read_text())['branches']}
tolerance=.00001
def owner_matches(path,owner):
    path=path.split('/OrisonV2Blockout/')[-1]
    if owner['table']=='riser_openings':return path.startswith(owner['riser']+'/')
    if owner['table']=='masonry_service_openings':return path=='ExteriorMasonry/ExteriorMasonry'
    if owner['table']=='slab_openings':return path==owner['space']+'/'+owner['surface']
    return path.startswith(owner['space']+'/Wall'+owner['side'].capitalize())
for c in report['contacts']:
    part=c['part'];path=c['source']['source'];a=c['bounds_native'];b=c['world_contact_face_bounds'];reason=None
    if part.endswith(('__Stem','__Foot')) and part.rsplit('__',1)[0] in by_support and path.endswith(('/Floor','/Ceiling')):
        if abs(a[5]-b[2])<=tolerance:reason='Hanger stem/foot terminates flush on actual floor/ceiling contact faces'
    if part.endswith(('__EntryPlate','__ExitPlate')):
        name,face=part.rsplit('__',1);p=passages[name]
        axis=[0,2,1][p['axis']];flip=-1 if p['axis']==2 else 1
        center=p['start'] if face=='EntryPlate' else p['end'];plane=center[p['axis']]*flip
        outward=(1 if p['end'][p['axis']]>p['start'][p['axis']] else -1)*flip*(-1 if face=='EntryPlate' else 1)
        matched=any(owner_matches(path,o) for o in p['owners'])
        flush=(abs(a[axis]-plane)<=tolerance and b[axis+3]<=plane+tolerance if outward>0 else abs(a[axis+3]-plane)<=tolerance and b[axis]>=plane-tolerance)
        if matched and flush:reason='Annular face plate touches its measured owning face; whole plate remains outside actual contacting faces'
    if part in stubs and '/'+part+'/WorkingAssembly/HeatingBranchConnection/' in path:
        plane=stubs[part]
        if abs(a[5]-plane)<=tolerance and b[2]>=plane-tolerance:reason='Branch stub terminates flush at retained radiator supply datum'
    if part.endswith(('__LugLeft','__LugRight')) and part.rsplit('__',1)[0] in bearings and '/HEAT_STACK/' in path:
        p=bearings[part.rsplit('__',1)[0]];x,y,z=p['center']
        bounds=[x-p['lug_reach_m'],-z-p['lug_half_depth_m'],y-p['lug_half_height_m'],x+p['lug_reach_m'],-z+p['lug_half_depth_m'],y+p['lug_half_height_m']]
        checks=[r for r in plan['bearing_checks'] if r['support']==p['id']]
        if len(checks)==8 and all(r['retained_bearing'] for r in checks) and all(a[i]>=bounds[i]-tolerance and a[i+3]<=bounds[i+3]+tolerance for i in range(3)):
            reason='Specified clamp lug embeds in its retained shaft bearing; eight authored bearing corners and exact lug bounds checked'
    if part in tails:
        identity=tails[part]['radiator'];suffix=path.split('/'+identity+'/WorkingAssembly/')[-1]
        if suffix in ['CastSections/SharedCastSections','ServiceUnionAndPacking/UnionMovingHalf/UnionNut'] or suffix.startswith('ServiceUnionAndPacking/@MeshInstance3D@'):
            reason='Specified short-body union tail seated into its own casting/retained union; explicit actor owner and subpart'
    c['disposition']=reason
unknown=[c for c in report['contacts'] if not c['disposition']]
report.update(scope='Engineering review of actual changed native stocks against the acquired corridor. Flush contacts checked against actual contacting face extents; embedded bearings and tail seats restricted to declared owner/subpart and native dimensions. Sampled containment is not a complete containment proof. No walking/full-surface/human acceptance.',unexplained=unknown,contact_review_status='REVIEW_CLEAR' if not unknown and not report['containments'] else 'REVIEW_REQUIRED',diagnostic_sha256=hashlib.sha256(report_path.read_bytes()).hexdigest())
out=args.out;out.parent.mkdir(parents=True,exist_ok=True);report['reviewer_sha256_lf']=hashlib.sha256(Path(__file__).read_bytes().replace(b'\r\n',b'\n')).hexdigest();out.write_text(json.dumps(report,indent=2)+'\n')
print(report['contact_review_status'],'contacts',len(report['contacts']),'unexplained',len(unknown),'sampled_containments',len(report['containments']))
for c in unknown:print(c['part'],c['source']['source'])

raise SystemExit(0 if report["contact_review_status"]=="REVIEW_CLEAR" else 1)
