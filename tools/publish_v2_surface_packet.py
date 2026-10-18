"""Publish an already qualified surface packet without reopening Godot.

Requires the test-written contract, matching wrapper/logs and reviewed images.
Preserves the preceding packet, uses atomic file replacements, and installs
its contract last. Does not create or repin runtime evidence.
"""
from pathlib import Path
import argparse,gzip,hashlib,json,os,tempfile,time
from v2_surface_evidence import ROOT,PACKET,qualify,file_hash
CORE=['surface-inventory.json','visual_review.json','suite_run.receipt.json',
      'suite_run.stdout.log.gz','suite_run.stderr.log.gz','runtime_contract.json']

def image_names(packet):
    names=[r['file'] for r in json.loads((packet/'visual_review.json').read_text(encoding='utf-8'))['images']]
    if any(not isinstance(n,str) or Path(n).name!=n or '/' in n or '\\' in n or n in {'.','..'} for n in names):
        raise ValueError('Review image names must be plain filenames')
    return names

def atomic_write(target,data):
    target=Path(target);target.parent.mkdir(parents=True,exist_ok=True)
    handle,name=tempfile.mkstemp(prefix=target.name+'.',suffix='.publication',dir=target.parent)
    staged=Path(name)
    try:
        with os.fdopen(handle,'wb') as stream:
            stream.write(data);stream.flush();os.fsync(stream.fileno())
        for attempt in range(40):
            try:os.replace(staged,target);return
            except OSError:
                if attempt==39:raise
                time.sleep(.1)
    finally:
        if staged.exists():staged.unlink()

def preserve(previous,destination):
    previous.mkdir(parents=True,exist_ok=True)
    # On a retry the backup is authoritative; never mix it with a partially
    # replaced destination. An incomplete backup must pass its inventory hash.
    reference=previous if (previous/'visual_review.json').exists() else destination
    for name in CORE+image_names(reference):
        target=previous/(name+'.gz' if name=='surface-inventory.json' else name)
        if target.exists():continue
        raw=(destination/name).read_bytes()
        atomic_write(target,gzip.compress(raw,mtime=0) if name=='surface-inventory.json' else raw)
    contract=json.loads((previous/'runtime_contract.json').read_text(encoding='utf-8'))
    raw=gzip.decompress((previous/'surface-inventory.json.gz').read_bytes())
    if hashlib.sha256(raw).hexdigest()!=contract['inventory_sha256']:
        raise ValueError('Previous inventory is incomplete or inconsistent; publication stopped')
    receipt=json.loads((previous/'suite_run.receipt.json').read_text(encoding='utf-8'))
    for channel in ['stdout','stderr']:
        raw=gzip.decompress((previous/('suite_run.'+channel+'.log.gz')).read_bytes())
        if hashlib.sha256(raw).hexdigest()!=receipt['log'][channel+'_sha256']:
            raise ValueError('Previous raw log is inconsistent: '+channel)
    review=json.loads((previous/'visual_review.json').read_text(encoding='utf-8'))
    for row in review['images']:
        if file_hash(previous/row['file'])!=row['sha256']:
            raise ValueError('Previous reviewed image is inconsistent: '+row['file'])

def publish(packet,archive,destination=PACKET,root=ROOT):
    packet,archive,destination=map(Path,(packet,archive,destination))
    if packet.resolve()==destination.resolve():raise ValueError('Source and destination must differ')
    report=qualify(packet,root)
    if report['result']!='PASS':raise ValueError('Source packet is not qualified: '+str(report.get('defects')))
    names=image_names(packet)
    preserve(archive/'previous_surface_packet',destination)
    for name in names+CORE:atomic_write(destination/name,(packet/name).read_bytes())
    report=qualify(destination,root)
    if report['result']!='PASS':raise ValueError('Published packet failed qualification: '+str(report.get('defects')))
    return report

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--packet',required=True,type=Path)
    parser.add_argument('--archive',required=True,type=Path)
    args=parser.parse_args();print(json.dumps(publish(args.packet,args.archive),indent=2))

if __name__=='__main__':main()
