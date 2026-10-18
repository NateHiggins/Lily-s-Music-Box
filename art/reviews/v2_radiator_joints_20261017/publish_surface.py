from pathlib import Path
import gzip,hashlib,json,shutil,sys,os,time
r=Path('C:/PleaseRemainOnTheLine');sys.path.insert(0,str(r/'tools'));import v2_surface_evidence as e
t=r/'tmp/v2-radiator-joints-20261017';p=t/'surface';a=r/'art/reviews/v2_radiator_joints_20261017';c=r/'art/renders/orison_v2/surface_requirements_20261011'
contract=json.loads((p/'runtime_contract.json').read_text(encoding='utf-8'));assert e.inputs()['sha256']==contract['surface_inputs_sha256'],'Rendering source changed during qualification'
shutil.copyfile(t/'surface.log.receipt.json',p/'suite_run.receipt.json')
for channel,suffix in [('stdout',''),('stderr','.stderr')]:
    (p/('suite_run.'+channel+'.log.gz')).write_bytes(gzip.compress((t/('surface.log'+suffix)).read_bytes(),mtime=0))
notes=json.loads((t/'reviewed_images.json').read_text(encoding='utf-8'))
rows=[]
for name,note in notes.items():
    target=p/name;assert target.is_file(),target
    rows.append({'file':target.name,'sha256':e.file_hash(target),'observation':note})
review={'evidence_class':'INERT','status':'PASS','scope':'Loaded radiator joint geometry and recorded appearance defects. Not photoreal or human acceptance; exhaustive technical surfaces have their separate test-written contract.','surface_inputs_sha256':e.inputs()['sha256'],'images':rows}
(p/'visual_review.json').write_text(json.dumps(review,indent=2)+'\n',encoding='utf-8',newline='\n')
result=e.qualify(p);(t/'surface_qualification.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8',newline='\n');print(result);assert result['result']=='PASS'
if '--publish' not in sys.argv:raise SystemExit(0)
prior=a/'previous_surface_packet';prior.mkdir(parents=True,exist_ok=True)
names=['runtime_contract.json','surface-inventory.json','visual_review.json','suite_run.receipt.json','suite_run.stdout.log.gz','suite_run.stderr.log.gz']
oldreview=json.loads((c/'visual_review.json').read_text(encoding='utf-8'))
for name in names+[row['file'] for row in oldreview['images']]:
    target=prior/(name+'.gz' if name=='surface-inventory.json' else name)
    if not target.exists():target.write_bytes(gzip.compress((c/name).read_bytes(),mtime=0) if name=='surface-inventory.json' else (c/name).read_bytes())
def atomic_copy(source,target):
    staged=target.with_name(target.name+'.radiator-joints-new')
    shutil.copyfile(source,staged)
    for attempt in range(40):
        try:os.replace(staged,target);return
        except OSError:
            if attempt==39:raise
            time.sleep(.1)
for name in names+[row['file'] for row in rows]:atomic_copy(p/name,c/name)
final=e.qualify(c);print(final);assert final['result']=='PASS'
