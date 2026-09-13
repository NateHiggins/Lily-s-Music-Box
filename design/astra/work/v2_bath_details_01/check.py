"""Current source composition proof. Retains older packets' receipts."""
import hashlib
import json
import subprocess
import sys
from pathlib import Path
import build

ROOT, OUT = build.ROOT, build.OUT
BASE = '0123c92'
build.build()
older = build.module('design/astra/work/v2_household_persistence_01/check.py','bath_persistence_regression')
older.OUT = OUT/'persistence_regression'
older.OUT.mkdir(exist_ok=True)
older.main()
sys.path.insert(0,'C:/Users/nate_/AppData/Local/Temp/astra-gdscript-parser')
from gdtoolkit.parser import parser
scripts = ['game/scripts/building/orison_v2_bath_details.gd',
           'game/scripts/building/orison_v2_runtime_root.gd',
           'game/tests/orison_v2_apartment_batch_test.gd']
for path in scripts:
    parser.parse((ROOT/path).read_text(encoding='utf-8'))
protected = ['game/scripts/props/tap_prop.gd','game/scripts/building/orison_v2_household_state.gd',
             'game/scripts/building/orison_v2_water_controls.gd','game/scripts/building/orison_v2_water_closet.gd',
             'game/data/runtime_material_sets.json','game/data/orison_v2_blockout.json']
for path in protected:
    baseline = subprocess.check_output(['git','show',BASE+':'+path],cwd=ROOT)
    assert (ROOT/path).read_bytes().replace(b'\r\n',b'\n') == baseline.replace(b'\r\n',b'\n'),path
result = dict(status='SOURCE_PASS_RUNTIME_PENDING',base=BASE,godot='NOT_RUN',
              source_hashes={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in scripts+protected},
              source_parses=3,household_persistence_source_replay=True,
              limits='Prepared runtime rejection, material/resource sharing and two-world disposal checks are not executed. Flat-colour source preview is not an engine/material/lighting capture.')
(OUT/'source_checks.json').write_bytes((json.dumps(result,indent=2)+'\n').encode('utf-8'))
print('Bath integration source checks pass; engine remains paused.')
