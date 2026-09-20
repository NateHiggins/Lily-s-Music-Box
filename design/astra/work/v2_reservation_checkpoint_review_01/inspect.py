"""Small read-only reservation preparation check; writes only this review folder."""
from pathlib import Path
import difflib
import hashlib
import json
import subprocess

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
BASE = ROOT / 'design/astra/work/v2_reservation_runtime_01'
DISPLAY = BASE.with_name('v2_reservation_display_01')
HEAD = '02fcb18a209624c9b609b65fb44b05b45c65de09'
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
load = lambda p: json.loads(p.read_text(encoding='utf-8'))
plan, package = load(BASE/'preparation.json'), load(BASE/'runtime/package.json')
display = load(DISPLAY/'preparation.json')
checks = []
def check(name, okay, **details):
    checks.append(dict(name=name, passed=bool(okay), **details))
head = subprocess.check_output(['git','-C',str(ROOT),'rev-parse','HEAD'],text=True).strip()
check('current canonical HEAD', head == HEAD, actual=head, expected=HEAD)
for label, base, rows in [('runtime prepared leaves', BASE, plan['files_sha256']),
                         ('runtime instruments', BASE/'runtime', package['files']),
                         ('display prepared leaves', DISPLAY, display['files_sha256']),
                         ('current reviewed dependencies', ROOT, plan['source_bindings_sha256'])]:
    differences = []
    for rel, expected in rows.items():
        p = base/rel
        actual = sha(p) if p.is_file() else None
        if actual != expected: differences.append(dict(path=rel, expected=expected, actual=actual))
    check(label, not differences, count=len(rows), differences=differences)
check('runtime preparation parent hash', sha(BASE/'preparation.json') == package['parent_preparation_sha256'])
owners = list(display['production_paths'])
for rel in owners:
    check('proposal agrees between original and runtime packages: '+rel,
          (BASE/'proposed'/rel).read_bytes() == (DISPLAY/'proposed'/rel).read_bytes())
    blob = subprocess.check_output(['git','-C',str(ROOT),'show',HEAD+':'+rel])
    checkout = (ROOT/rel).read_bytes()
    check('HEAD content agrees with current source: '+rel,
          blob.replace(b'\r\n',b'\n') == checkout.replace(b'\r\n',b'\n'),
          git_blob=subprocess.check_output(['git','-C',str(ROOT),'rev-parse',HEAD+':'+rel],text=True).strip(),
          working_sha256=sha(ROOT/rel))
rel = 'game/scripts/building/orison_v2_runtime_root.gd'
old, new = (BASE/'originals'/rel).read_bytes(), (BASE/'proposed'/rel).read_bytes()
added = b'\t_blockout.show_reservation_volumes = false'
check('production omission deletes only one false assignment',
      new.replace(added+b'\r\n', b'').replace(added+b'\n', b'') == old)
terminal = ROOT/'design/astra/work/v2_terminal_access_arrival_02'
check('copied terminal assessor is exact accepted assessor',
      (BASE/'runtime/terminal_assess.py').read_bytes() == (terminal/'runtime/assess.py').read_bytes())
check('new fixtures and evidence namespace remain uninstalled',
      all(not (ROOT/p).exists() for p in package['install']) and
      not (ROOT/'design/astra/evidence/v2_reservation_display_01').exists())
capture = load(BASE/'capture_binding.json')
capture_rows = {
    capture['fixture_source']: capture['fixture_candidate_sha256'],
    'design/astra/work/vulkan_composed/run_case.py': capture['wrapper_sha256'],
    'design/astra/work/vulkan_composed/gate.py': capture['gate_sha256'],
}
check('optional capture source/runner/gate binding still current',
      all((ROOT/p).is_file() and sha(ROOT/p)==v for p,v in capture_rows.items()))
bindings = {str(p.relative_to(ROOT)).replace('\\','/'):sha(p) for p in
            [BASE/'preparation.json',BASE/'runtime/package.json',BASE/'runtime/run.py',
             BASE/'runtime/assess.py',BASE/'runtime/terminal_assess.py',BASE/'runtime/core.py',
             BASE/'runtime/support.py',BASE/'runtime/test_assess.py',BASE/'runtime/test_runner_contract.py',
             BASE/'proposed/game/tests/orison_v2_reservation_display_test.gd',
             BASE/'proposed/game/tests/OrisonV2ReservationDisplayTest.tscn',DISPLAY/'reservation_display.patch']}
result = dict(schema='astra.v2-reservation-checkpoint.static-review.v1',
              scope='Small declared package/dependency reads only; no full-game census, engine, import, source mutation, or offline test execution.',
              head=head, checks=checks, bindings=bindings,
              status='STATIC_BINDINGS_MATCH' if all(c['passed'] for c in checks) else 'STATIC_BINDING_MISMATCH')
(HERE/'static_checks.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
print(json.dumps(dict(status=result['status'],passed=sum(c['passed'] for c in checks),total=len(checks),receipt_sha256=sha(HERE/'static_checks.json'))))
