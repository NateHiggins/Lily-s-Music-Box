from pathlib import Path
import hashlib,json,shutil,subprocess,sys
R=Path('C:/PleaseRemainOnTheLine');T=R/'tmp/v2-finish-review';O=R/'art/renders/orison_v2/household_stoves_20261008'
def load(p):return json.loads(p.read_text(encoding='utf-8'))
def save(p,d):p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(d,indent=2)+'\n',encoding='utf-8',newline='\n')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def copy(p,q):q.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,q)
f=load(R/'game/tests/fixtures/orison_household_stoves.json')
for path,h in f['source_bindings'].items():
 b=(R/path).read_bytes()
 if Path(path).suffix in ['.json','.py','.gd','.import','.gltf','.tscn']:b=b.replace(b'\r\n',b'\n')
 assert hashlib.sha256(b).hexdigest()==h,path
assert sha(R/'game/assets/props/household_stoves.glb')==f['asset_sha256']
for p in ['game/scripts/props/stove_prop.gd','game/scripts/props/fridge_prop.gd']:
 assert (R/p).read_bytes()==subprocess.check_output(['git','show','HEAD:'+p],cwd=R),p
newpaths=[p.relative_to(R).as_posix() for p in (R/'art/blender/scripts').glob('*stove*.py')]
newpaths += ['art/data/household_stoves/source_plan.json','art/blender/household_stoves.blend','art/blender/household_stoves_construction.json','game/assets/props/household_stoves.glb','game/assets/props/household_stoves.glb.import','game/data/orison_v2/household_stoves.json','game/tests/fixtures/orison_household_stoves.json','game/tests/orison_v2_household_stoves_test.gd','game/scripts/building/orison_v2_stove.gd','game/scripts/building/orison_v2_stove_visual_motion.gd','game/scripts/building/orison_v2_native_household_stoves.gd']
attrs=R/'.gitattributes';s=attrs.read_text();rows=[p+' -text' for p in newpaths if p+' -text' not in s]
rows+=['art/renders/orison_v2/household_stoves_20261008/** -text -whitespace']
if rows[-1] not in s:attrs.write_text(s+'\n# Native household stove geometry and source-bound QA.\n'+'\n'.join(rows)+'\n',encoding='utf-8',newline='\n')
sys.path.insert(0,str(R/'tools'))
from audit_orison_spatial_dependencies import scan_repository
meta,records=scan_repository(R,R/'art/data/building_layout.json',True,False)
p=R/'tools/orison_spatial_dependency_manifest.json';old=load(p);keys={x['key'] for x in old['records']};new=[x for x in records if x['key'] not in keys]
assert all('stove' in x['file'] or x['file']=='game/scripts/building/orison_v2_domestic_fittings.gd' for x in new),new
before=len(old['records']);old['records'].extend(new);p.write_text(json.dumps(old,indent=1)+'\n',encoding='utf-8',newline='\n')
save(T/'stoves-spatial-append.json',{'evidence_class':'INERT','preserved':before,'appended':len(new),'records':new})
keep={p+'.uid' for p in newpaths if p.endswith('.gd')}
uids=subprocess.check_output(['git','ls-files','--others','--exclude-standard','--','*.uid'],cwd=R).decode().splitlines()
removed=[]
for name in uids:
 if name in keep:continue
 p=(R/name).resolve();assert p.is_relative_to(R) and p.suffix=='.uid';p.unlink();removed.append(name)
save(T/'stoves-uid-cleanup.json',{'evidence_class':'INERT','kept':sorted(keep),'removed_count':len(removed),'removed':removed})
for p in T.glob('stoves-*'):
 if p.is_file() and p.suffix in ['.json','.log','.stderr']:copy(p,O/'receipts'/p.name)
for name in ['household-stoves-context.json','household-stoves-motion.json','fit-stove-parking.py','package-stoves.py']:copy(T/name,O/'receipts'/name)
for p in (T/'household-stoves-native').iterdir():
 if p.is_file():copy(p,O/'native'/p.name)
for number in [1,2]:
 for p in (T/f'stoves-runtime-{number:02}').rglob('*'):
  if p.is_file():copy(p,O/'receipts'/f'runtime-{number:02}'/p.relative_to(T/f'stoves-runtime-{number:02}'))
a=load(T/'stoves-runtime-01/batch.json');b=load(T/'stoves-runtime-02/batch.json');assert b['failures']==[]
assert a['modules']['household_stoves']['fixture_sha256']==b['modules']['household_stoves']['fixture_sha256']==sha(R/'game/tests/fixtures/orison_household_stoves.json')
production=[]
for row in a['modules']['household_stoves']['views']:
 p=T/'stoves-runtime-01/household_stoves'/row['image'];copy(p,O/'production'/p.name)
 production.append(dict(row,file='production/'+p.name,sha256=sha(p),status='visually reviewed; model form and service endpoints accepted; room finish remains open'))
native=[dict(row,file='native/'+row['file'],sha256=sha(O/'native'/row['file']),status='visually reviewed') for row in load(O/'native/views.json')['views']]
assert len(native)==6 and len(production)==8
save(O/'image_manifest.json',{'evidence_class':'INERT','native':native,'production':production,'scope':'Final native04 geometry and runtime01 frames; runtime02 corrects only the validator expected initial valve angle for the two source ambient-lit households. Identical native fixture and asset. These are fabrication QA, not runtime_contract proof. Original runtime01 four validator failures remain in raw evidence.'})
save(O/'reuse.json',{'evidence_class':'INERT','runtime01_fixture':a['modules']['household_stoves']['fixture_sha256'],'runtime02_fixture':b['modules']['household_stoves']['fixture_sha256'],'asset_sha256':f['asset_sha256'],'native_geometry_unchanged_after_native04':True,'production_reuse':'No runtime/asset edits between the two runs. Only validator expected transforms include source initial burner rotation. All eight original images reviewed.'})
print(json.dumps({'native_views':len(native),'production_views':len(production),'spatial_preserved':before,'spatial_appended':len(new),'removed_uids':len(removed),'kept_uids':sorted(keep)}))
