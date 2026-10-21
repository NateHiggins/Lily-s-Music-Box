"""Prepare original receipts/logs, then publish only independently verified packets.
No receipts or source hashes are generated or edited here. Surface visual review
is a separate manual step before the surface publisher is used.
"""
from pathlib import Path
import argparse,gzip,hashlib,json,sys
ROOT=Path.cwd();sys.path.insert(0,str(ROOT/'tools'))
sys.path.insert(0,str(ROOT/'art/reviews/v2_responsiveness_20261021'))
from publish_v2_surface_packet import atomic_write
from publish_v2_spatial_packet import publish
from verify_first_slice import verify
BASE=ROOT/'art/reviews/v2_case_calibrator_20261021/renewal'
DEST=ROOT/'art/renders/orison_v2'
SPATIAL={'upper':'access_upper_cohort_20261018','home':'access_home_cohort_20261018',
'service':'access_service_circulation_20261018','public':'access_public_landings_20261018','regions':'access_exterior_regions_20261019'}
def prepare(name):
 packet=BASE/name;receipt=BASE/(name+'.log.receipt.json');raw=receipt.read_bytes();run=json.loads(raw)
 if not run['execution']['completed'] or run['execution']['exit_code']!=0 or run['execution']['timed_out']:raise ValueError('Failed wrapper '+name)
 if run['log']['script_error_count'] or run['log']['fail_count'] or run['log']['stale_cache_suspect']:raise ValueError('Wrapper errors '+name)
 for stream in ['stdout','stderr']:
  content=Path(run['log'][stream]).read_bytes()
  if hashlib.sha256(content).hexdigest()!=run['log'][stream+'_sha256']:raise ValueError('Original log changed '+name)
  atomic_write(packet/('suite_run.'+stream+'.log.gz'),gzip.compress(content,mtime=0))
 atomic_write(packet/'suite_run.receipt.json',raw)
 return packet,receipt
if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('name',choices=['surface','first_slice',*SPATIAL]);args=parser.parse_args()
 packet,receipt=prepare(args.name)
 if args.name in SPATIAL:
  result=publish(packet,receipt,DEST/SPATIAL[args.name],BASE/(args.name+'_previous'))
 elif args.name=='first_slice':
  result=verify(packet);destination=DEST/'first_slice_contract_20261011';archive=BASE/'first_slice_previous'
  names=['suite_run.receipt.json','suite_run.stdout.log.gz','suite_run.stderr.log.gz','runtime_authority_receipt.json','verification.json']
  for name in names:
   old=destination/name
   if old.is_file():
    if (archive/name).exists() and (archive/name).read_bytes()!=old.read_bytes():raise ValueError('Previous packet conflict')
    atomic_write(archive/name,old.read_bytes())
  for name in names[:-2]:atomic_write(destination/name,(packet/name).read_bytes())
  atomic_write(destination/'verification.json',(json.dumps(result,indent=2)+'\n').encode())
  atomic_write(destination/'runtime_authority_receipt.json',(packet/'runtime_authority_receipt.json').read_bytes())
  result=verify(destination)
 else:result={'evidence_class':'INERT','status':'PREPARED','scope':'Original logs only; surface visual review and qualification still required'}
 atomic_write(BASE/(args.name+'_publication.json'),(json.dumps(result,indent=2)+'\n').encode());print(json.dumps(result,indent=2))
