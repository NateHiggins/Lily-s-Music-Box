"""Publish executed played-room proof; never create or repin runtime evidence.

Checks source-bound room, connection and region claims, corroborating wrapper
and original log bytes. Preserves the preceding files and installs the contract
last. Captures are optional records, never human acceptance.
"""
import argparse
import gzip
import hashlib
import json
from pathlib import Path

from audit_orison_v2_completeness import runtime_inputs_sha256
from publish_v2_surface_packet import atomic_write
from spatial_access_evidence import validate
from spatial_connection_evidence import validate_connections
from spatial_region_evidence import validate_regions
from v2_surface_evidence import inputs

ROOT=Path(__file__).resolve().parents[1]
CORE=['suite_run.receipt.json','suite_run.stdout.log.gz',
      'suite_run.stderr.log.gz','runtime_contract.json']

def digest(raw):return hashlib.sha256(raw).hexdigest()

def current_digests(root):
    return runtime_inputs_sha256(root),inputs(root)['sha256']

def verify(contract_raw,run_raw,logs,root,digests):
    contract=json.loads(contract_raw);run=json.loads(run_raw)
    problems=validate(contract,root,*digests)
    claims=contract.get('contracts',{})
    if 'room_connections' in claims:problems+=validate_connections(contract,root,*digests)
    if 'region_access' in claims:problems+=validate_regions(contract,root,*digests)
    if run.get('schema')!='orison.run-receipt.v1' or run.get('schema_version')!=1 or run.get('evidence_kind')!='suite_run':
        problems.append('matching suite_run wrapper required')
    execution=run.get('execution',{})
    if execution.get('completed') is not True or execution.get('exit_code')!=0 or execution.get('timed_out') is not False:
        problems.append('wrapper did not complete successfully')
    for key in ['test_path','test_sha256','runtime_inputs_sha256']:
        if not contract.get('source',{}).get(key) or run.get('source',{}).get(key)!=contract['source'][key]:
            problems.append('wrapper/contract source mismatch: '+key)
    captured=run.get('log',{})
    if captured.get('script_error_count')!=0 or captured.get('fail_count')!=0 or captured.get('stale_cache_suspect',False):
        problems.append('wrapper reports failed checks, script errors or stale imports')
    for stream in ['stdout','stderr']:
        raw=logs[stream]
        if digest(raw)!=captured.get(stream+'_sha256'):problems.append('raw log hash mismatch: '+stream)
        if any(line.lstrip().startswith(('ERROR:','SCRIPT ERROR:')) for line in raw.decode('utf8','replace').splitlines()):
            problems.append('Godot error in '+stream)
    if problems:raise ValueError('Unqualified spatial packet: '+'; '.join(problems))
    return contract

def read_logs(packet,run):
    logs={}
    for stream in ['stdout','stderr']:
        original=Path(run['log'][stream])
        logs[stream]=original.read_bytes() if original.is_file() else gzip.decompress((packet/('suite_run.'+stream+'.log.gz')).read_bytes())
    return logs

def preserve(archive,destination,names,incoming):
    manifest=archive/'publication.json'
    if manifest.exists():
        record=json.loads(manifest.read_text())
        if record['destination']!=str(destination) or record['incoming_contract_sha256']!=incoming:
            raise ValueError('Archive belongs to another publication; choose a fresh archive directory')
        for name,expected in record['previous_files'].items():
            if digest((archive/name).read_bytes())!=expected:raise ValueError('Previous packet archive changed: '+name)
        return
    previous={}
    for name in names:
        path=destination/name
        if not path.exists():continue
        raw=path.read_bytes();target=archive/name
        if target.exists() and target.read_bytes()!=raw:raise ValueError('Incomplete archive conflicts with previous packet: '+name)
        atomic_write(target,raw);previous[name]=digest(raw)
    record={'evidence_class':'INERT','destination':str(destination),
            'incoming_contract_sha256':incoming,'previous_files':previous}
    atomic_write(manifest,(json.dumps(record,indent=2)+'\n').encode())

def publish(packet,receipt,destination,archive,root=ROOT,images=()):
    root=Path(root).resolve()
    packet,receipt,destination,archive=map(lambda p:Path(p).resolve(),[packet,receipt,destination,archive])
    if not destination.is_relative_to(root/'art/renders/orison_v2') or destination==root/'art/renders/orison_v2':
        raise ValueError('Destination must name a packet below art/renders/orison_v2')
    if not archive.is_relative_to(root/'art/reviews') or archive==root/'art/reviews':
        raise ValueError('Archive must name a directory below art/reviews')
    if packet.is_relative_to(destination) or destination.is_relative_to(packet) \
            or archive.is_relative_to(destination) or destination.is_relative_to(archive) \
            or archive.is_relative_to(packet) or packet.is_relative_to(archive):
        raise ValueError('Source, destination and archive must be separate')
    if any(not isinstance(n,str) or Path(n).name!=n or '/' in n or '\\' in n \
            or Path(n).suffix.lower() not in {'.png','.jpg','.jpeg','.webp'} for n in images):
        raise ValueError('Capture names must be plain non-core filenames')
    if len(images)!=len(set(images)):raise ValueError('Duplicate capture name')
    contract_raw=(packet/'runtime_contract.json').read_bytes();run_raw=receipt.read_bytes()
    logs=read_logs(packet,json.loads(run_raw));before=current_digests(root)
    contract=verify(contract_raw,run_raw,logs,root,before)
    payload={'suite_run.receipt.json':run_raw,**{f'suite_run.{k}.log.gz':gzip.compress(v,mtime=0) for k,v in logs.items()}}
    payload.update({name:(packet/name).read_bytes() for name in images})
    preserve(archive,destination,CORE+list(images),digest(contract_raw))
    for name,raw in payload.items():atomic_write(destination/name,raw)
    atomic_write(destination/'runtime_contract.json',contract_raw)
    after=current_digests(root)
    if after!=before:raise ValueError('Inputs changed during publication; the written packet is not current proof')
    verify((destination/'runtime_contract.json').read_bytes(),(destination/'suite_run.receipt.json').read_bytes(),
           {k:gzip.decompress((destination/f'suite_run.{k}.log.gz').read_bytes()) for k in logs},root,after)
    return {'evidence_class':'INERT','result':'PASS','destination':str(destination),
            'contract_sha256':digest(contract_raw),'rooms':len(contract['contracts']['room_access']['rooms'])}

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    for name in ['packet','receipt','destination','archive']:parser.add_argument('--'+name,required=True,type=Path)
    parser.add_argument('--images',nargs='*',default=[])
    args=parser.parse_args()
    print(json.dumps(publish(args.packet,args.receipt,args.destination,args.archive,images=args.images),indent=2))

if __name__=='__main__':main()
