"""Read-only checkpoint comparison. Does not grant runtime qualification."""
from pathlib import Path
import collections
import hashlib
import json
import os
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT/'tools'))
import gate_board
import verify_candidate

def git(*args):
    return subprocess.check_output(['git','--no-optional-locks',*args],cwd=ROOT)

def main():
    os.environ['GIT_OPTIONAL_LOCKS']='0'
    main=git('rev-parse','origin/main').decode().strip()
    baseline_path=ROOT/'art/reviews/v2_case_calibrator_20261021/player_door_hull_diagnostic/clean_main_baseline/board.json'
    baseline=json.loads(baseline_path.read_text())
    board=json.loads((HERE/'board_checkpoint/board.json').read_text())
    receipt=json.loads((ROOT/verify_candidate.PROTECTED_RECEIPT).read_text())
    protected=[]
    for entry in receipt['files']:
        name=entry['path']
        current=(ROOT/name).read_bytes()
        base=git('show',f'{main}:{name}')
        if Path(name).suffix in ['.gd','.gltf','.json','.tscn','.tres']:
            current=current.replace(b'\r\n',b'\n');base=base.replace(b'\r\n',b'\n')
        protected.append({'path':name,'matches_main_lf_normalized':current==base,'current_sha256':hashlib.sha256(current).hexdigest()})
    result={'evidence_class':'INERT','scope':'Working checkpoint and pre-existing main comparison; not a merge candidate or runtime proof.',
            'branch':git('branch','--show-current').decode().strip(),'precheckpoint_head':git('rev-parse','HEAD').decode().strip(),
            'origin_main':main,'merge_base':git('merge-base','HEAD','origin/main').decode().strip(),
            'protected':protected,'protected_matched':sum(row['matches_main_lf_normalized'] for row in protected),
            'selector':verify_candidate.selector_check('HEAD'),
            'baseline_validation_errors':verify_candidate.validate_baseline_board(baseline,main),
            'gate_severities':dict(collections.Counter(row['severity'] for row in board['gates'])),
            'gate_failures':[row for row in board['gates'] if row['severity']=='FAIL'],
            'main_comparison':gate_board.compare(baseline,board),
            'reader':[row for row in board['gates'] if row['id']=='reader'],
            'spatial':[row for row in board['gates'] if row['id']=='spatial']}
    (HERE/'integration_diagnostic.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8',newline='\n')
    print('Protected',result['protected_matched'],'selector',result['selector'],'baseline errors',result['baseline_validation_errors'])
    print('Gate severity',result['gate_severities'],'main regressions',len(result['main_comparison']['regressions']))

if __name__=='__main__':main()
