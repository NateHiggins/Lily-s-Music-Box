"""Check an original first-slice packet against current authority and raw logs."""
from pathlib import Path
import argparse,gzip,hashlib,json,re,subprocess,sys
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'tools'))
from audit_orison_v2_completeness import runtime_receipt_errors


FIRST_SCENE = 'game/tests/orison_v2_first_slice_contract_test.tscn'
FIRST_SCRIPT = 'game/tests/orison_v2_first_slice_contract_test.gd'


def _git_blob(root, head, path):
    return subprocess.check_output(['git', 'show', head + ':' + path], cwd=root)


def _test_binding_errors(contract, run, root):
    source, recorded = contract.get('source', {}), run.get('source', {})
    keys = ('test_path', 'test_sha256')
    # A non-NULL or partly NULL wrapper never receives the nested-scene exception.
    if not all(key in recorded and recorded[key] is None for key in keys):
        return ['wrapper/source mismatch: ' + key for key in keys
                if not source.get(key) or source[key] != recorded.get(key)]
    try:
        if run.get('scene') != 'res://tests/orison_v2_first_slice_contract_test.tscn':
            raise ValueError('NULL test binding requires the exact first-slice scene')
        head = recorded.get('repository_head', '')
        if not isinstance(head, str) or not re.fullmatch(r'[0-9a-f]{40}', head):
            raise ValueError('NULL test binding requires the recorded full Git commit')
        if source.get('repository_head') != head or source.get('test_path') != FIRST_SCRIPT:
            raise ValueError('NULL test binding head or primary script mismatch')
        if source.get('test_scene_path') != FIRST_SCENE:
            raise ValueError('NULL test binding requires the declared exact scene')
        scene = _git_blob(root, head, FIRST_SCENE).replace(b'\r\n', b'\n')
        current = (root / FIRST_SCENE).read_bytes().replace(b'\r\n', b'\n')
        if current != scene or hashlib.sha256(scene).hexdigest() != source.get('test_scene_sha256'):
            raise ValueError('Recorded Git scene, current scene or contract scene hash differs')
        script = _git_blob(root, head, FIRST_SCRIPT).replace(b'\r\n', b'\n')
        current_script = (root / FIRST_SCRIPT).read_bytes().replace(b'\r\n', b'\n')
        if script != current_script or hashlib.sha256(script).hexdigest() != source.get('test_sha256'):
            raise ValueError('Recorded Git script, current script or primary hash differs')
        text = scene.decode('utf-8')
        resources = []
        for line in re.findall(r'^\[ext_resource[^\]\n]*\]', text, re.M):
            attrs = dict(re.findall(r'(\w+)\s*=\s*"([^"]*)"', line))
            if attrs.get('type') == 'Script':
                resources.append(attrs)
        if len(resources) != 1 or resources[0].get('path') != 'res://tests/orison_v2_first_slice_contract_test.gd':
            raise ValueError('Scene must declare exactly one exact primary Script resource')
        resource_id = resources[0].get('id', '')
        if not resource_id:
            raise ValueError('Primary Script resource has no id')
        bindings, roots = [], []
        for header, body in re.findall(r'^\[node ([^\]\n]+)\]\s*\n(.*?)(?=^\[|\Z)', text, re.M | re.S):
            attrs = dict(re.findall(r'(\w+)\s*=\s*"([^"]*)"', header))
            lines = re.findall(r'^\s*script\s*=\s*(.+)$', body, re.M)
            if 'parent' not in attrs:
                roots.append(attrs)
                if lines:
                    raise ValueError('NULL wrapper exception requires a scriptless root')
            for line in lines:
                match = re.fullmatch(r'ExtResource\("([^"\n]+)"\)\s*', line)
                if not match or match[1] != resource_id or 'parent' not in attrs:
                    raise ValueError('Unexpected primary-script attachment')
                bindings.append((attrs.get('parent'), attrs.get('name')))
        if len(roots) != 1 or len(bindings) != 1:
            raise ValueError('Primary script must be attached to exactly one child node')
    except (OSError, UnicodeError, ValueError, subprocess.CalledProcessError) as exc:
        return ['NULL wrapper test binding rejected: ' + str(exc)]
    return []


def verify(packet):
    contract=json.loads((packet/'runtime_authority_receipt.json').read_text())
    run=json.loads((packet/'suite_run.receipt.json').read_text())
    problems=runtime_receipt_errors(contract,ROOT)
    if run.get('evidence_kind')!='suite_run' or run.get('scene')!='res://tests/orison_v2_first_slice_contract_test.tscn' or not run.get('windowed'):
        problems.append('wrong wrapper identity')
    e=run.get('execution',{})
    if e.get('completed') is not True or e.get('exit_code')!=0 or e.get('timed_out') is not False:
        problems.append('wrapper not completed successfully')
    for key in ['repository_head','runtime_inputs_sha256']:
        if not contract.get('source',{}).get(key) or contract['source'][key]!=run.get('source',{}).get(key):
            problems.append('wrapper/source mismatch: '+key)
    problems += _test_binding_errors(contract,run,ROOT)
    log=run.get('log',{})
    if log.get('script_error_count')!=0 or log.get('fail_count')!=0 or log.get('stale_cache_suspect'):
        problems.append('wrapper reports errors or stale cache')
    for channel in ['stdout','stderr']:
        raw=gzip.decompress((packet/f'suite_run.{channel}.log.gz').read_bytes())
        if hashlib.sha256(raw).hexdigest()!=log.get(channel+'_sha256'):problems.append('raw log hash mismatch: '+channel)
        if any(line.lstrip().startswith(('ERROR:','SCRIPT ERROR:')) for line in raw.decode('utf8','replace').splitlines()):
            problems.append('Godot errors in '+channel)
    if problems:raise ValueError('; '.join(problems))
    return {'evidence_class':'INERT','result':'PASS','checks':len(contract['checks']),'scope':contract['scope']}

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--packet',type=Path,default=ROOT/'art/renders/orison_v2/first_slice_contract_20261011')
    print(json.dumps(verify(parser.parse_args().packet),indent=2))
