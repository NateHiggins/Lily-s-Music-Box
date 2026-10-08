from pathlib import Path
import hashlib,json,shutil,subprocess
ROOT=Path('C:/PleaseRemainOnTheLine');TMP=ROOT/'tmp/v2-finish-review'
OUT=ROOT/'art/renders/orison_v2/household_fridges_20261008'
def load(p):return json.loads(p.read_text(encoding='utf-8'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,d):p.write_text(json.dumps(d,indent=2)+'\n',encoding='utf-8',newline='\n')
def copy(p,q):q.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,q)
for p in ['game/scripts/props/fridge_prop.gd','game/scripts/props/stove_prop.gd']:
 original=subprocess.check_output(['git','show','HEAD:'+p],cwd=ROOT)
 assert (ROOT/p).read_bytes().replace(b'\r\n',b'\n')==original.replace(b'\r\n',b'\n'),p
 (ROOT/p).write_bytes(original)
# No semantic edits; normalize our own newly hash-bound adapter.
p=ROOT/'game/scripts/building/orison_v2_domestic_fittings.gd';p.write_bytes(p.read_bytes().replace(b'\r\n',b'\n'))
for p in TMP.glob('fridges-*'):
 if p.is_file() and (p.suffix in ['.log','.json','.stderr']):copy(p,OUT/'receipts'/p.name)
for name in ['household-fridges-context.json','household-fridges-motion.json','refresh-fridge-context.py','package-fridges.py']:
 copy(TMP/name,OUT/'receipts'/name)
for p in (TMP/'household-fridges-native').iterdir():
 if p.is_file():copy(p,OUT/'native'/p.name)
for number in range(1,5):
 for p in (TMP/f'fridges-runtime-{number:02}').rglob('*'):
  if p.is_file():copy(p,OUT/'receipts'/f'runtime-{number:02}'/p.relative_to(TMP/f'fridges-runtime-{number:02}'))
selected=[]
for number in [3,4]:
 batch=load(TMP/f'fridges-runtime-{number:02}/batch.json');assert batch['failures']==[]
 for row in batch['modules']['household_fridges']['views']:
  if (row['owner']=='F04_B_FRIDGE_01')!=(number==4):continue
  p=TMP/f'fridges-runtime-{number:02}/household_fridges'/row['image']
  copy(p,OUT/'production'/p.name)
  selected.append(dict(row,source_run=f'fridges-runtime-{number:02}',file='production/'+p.name,sha256=sha(p),status='visually reviewed; scoped geometry/material fit accepted'))
assert len(selected)==10
before=load(TMP/'fridges-before-final-bindings.json');after=load(ROOT/'game/tests/fixtures/orison_household_fridges.json')
changed={key:[before.get(key),after.get(key)] for key in set(before)|set(after) if before.get(key)!=after.get(key)}
assert set(changed)<= {'source_bindings'},set(changed)
for key in ['asset_sha256','runtime','closed_stocks']:assert before[key]==after[key]
save(OUT/'receipts/final-native-reuse.json',{'evidence_class':'INERT','identical_fields':['asset_sha256','runtime','closed_stocks'],'only_changed_fields':list(changed),'bindings_changed':{key:[before['source_bindings'].get(key),value] for key,value in after['source_bindings'].items() if value!=before['source_bindings'].get(key)},'asset_sha256':after['asset_sha256'],'scope':'Native render03 remains valid after native11 and normalized Godot import provenance; every non-binding field is identical. Runtime03/04 use final asset.'})
views=load(OUT/'native/views.json')['views'];assert len(views)==26
native=[dict(row,file='native/'+row['file'],sha256=sha(OUT/'native'/row['file']),status='visually reviewed; scoped form/material fit accepted') for row in views]
save(OUT/'image_manifest.json',{'evidence_class':'INERT','native':native,'production':selected,'scope':'Fabrication QA only, no runtime_contract proof or ledger promotion. Final native26 and production10; whole-building photoreal acceptance remains open. Production rooms retain strong warm light and coarse floor/plaster maps. 4B final camera includes actual case/leaf occlusion checks. Earlier failed/occluded frames and raw receipts retained.'})
print(json.dumps({'packet':str(OUT),'native_views':len(native),'production_views':len(selected),'files':sum(1 for p in OUT.rglob('*') if p.is_file()),'bindings_only_changes':list(changed)}))
