"""Source integration and regression checks; never launches Godot."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import build

ROOT,OUT=build.ROOT,build.OUT
build.build()
old=build.module('design/astra/work/v2_household_persistence_01/check.py','upper_persistence_regression')
old.OUT=OUT/'persistence_regression';old.OUT.mkdir(exist_ok=True)
old.main()
bath=build.module('design/astra/work/v2_bath_details_01/build.py','upper_bath_regression')
bath.build()
sys.path.insert(0,'C:/Users/nate_/AppData/Local/Temp/astra-gdscript-parser')
from gdtoolkit.parser import parser
scripts=['game/scripts/building/orison_v2_upper_floor_doors.gd','game/scripts/building/orison_v2_domestic_doors.gd',
         'game/scripts/building/orison_v2_runtime_root.gd','game/tests/orison_v2_upper_floors_test.gd',
         'game/scripts/building/orison_v2_blockout.gd','game/tests/orison_v2_apartment_batch_test.gd']
for path in scripts:parser.parse((ROOT/path).read_text(encoding='utf-8'))
protected=['game/scripts/props/door_prop.gd','game/scripts/building/building_root_selector.gd',
           'game/scripts/building/orison_v2_household_state.gd','game/data/runtime_material_sets.json',
           'game/data/building_layout.json']
for path in protected:
    previous=subprocess.check_output(['git','show',build.BASE+':'+path],cwd=ROOT)
    assert (ROOT/path).read_bytes().replace(b'\r\n',b'\n')==previous.replace(b'\r\n',b'\n'),path
# The completeness tool is allowed to report incomplete scope. Preserve its
# actual nonzero status and capture the selected upper-floor obligations.
audit=subprocess.run([sys.executable,'tools/audit_orison_v2_completeness.py','--floor','F05','--floor','F06','--json'],
                     cwd=ROOT,capture_output=True,text=True,encoding='utf-8')
(OUT/'completeness.json').write_bytes(audit.stdout.encode('utf-8'))
(OUT/'completeness.stderr.txt').write_bytes(audit.stderr.encode('utf-8'))
assert audit.returncode in [0,1,2],('completeness failed to run',audit.returncode,audit.stderr)
assert 'summary' in json.loads(audit.stdout), 'completeness did not produce its ledger'
result=dict(status='SOURCE_PASS_RUNTIME_PENDING',godot='NOT_RUN',base=build.BASE,syntax_parses=6,
            completeness_exit=audit.returncode,related_category_checks=['heating','accessories','prep cabinets','bath details','56-control persistence source'],
            source_hashes={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in scripts+protected},
            limits='Rooms and circulation are source-integrated, not furnished or runtime-proven. Door/persistence/old-room behavior and both floor approaches still need engine execution. V1 stays default.')
(OUT/'source_checks.json').write_bytes((json.dumps(result,indent=2)+'\n').encode('utf-8'))
print('Six script parses and category source replays passed; completeness exit:',audit.returncode)
