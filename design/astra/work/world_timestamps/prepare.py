"""Prepare a bounded proposal outside game/. Never installs or executes it."""
from pathlib import Path
import difflib
import hashlib
import json
import subprocess

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
PATHS = [
    'game/scripts/game/maintenance_inventory.gd',
    'game/scripts/game/work_orders.gd',
    'game/scripts/reality/organism_incidents.gd',
    'game/scripts/props/night_register_prop.gd',
    'game/scripts/game/chirp_hunt.gd',
]
originals = {}
for name in PATHS:
    source = ROOT / name
    original = HERE / 'originals' / name
    original.parent.mkdir(parents=True, exist_ok=True)
    if not original.exists():
        original.write_bytes(source.read_bytes())
    originals[name] = original.read_text(encoding='utf-8')

def replace_once(source, old, new):
    assert source.count(old) == 1, old
    return source.replace(old, new)

def owner_clock(source, anchor):
    return replace_once(source, anchor,
        'const TIMESTAMP_BASIS := "campaign_elapsed_minutes"\n'
        'var _clock := CampaignClock.new()\n\n\n' + anchor)

proposed = {}
name = PATHS[0]
s = owner_clock(originals[name], 'func setup() -> void:')
s = replace_once(s, '\titems[item_id] = {',
    '\tif not _clock.bind_state():\n\t\treturn false\n\titems[item_id] = {')
s = replace_once(s, '"acquired_at": Time.get_unix_time_from_system(),',
    '"acquired_at": _clock.elapsed_minutes(), "acquired_at_basis": TIMESTAMP_BASIS,')
s = replace_once(s, '\titems[item_id].consumed = true',
    '\tif not _clock.bind_state():\n\t\treturn false\n\titems[item_id].consumed = true')
s = replace_once(s, '\titems[item_id].consumed_at = Time.get_unix_time_from_system()',
    '\titems[item_id].consumed_at = _clock.elapsed_minutes()\n'
    '\titems[item_id].consumed_at_basis = TIMESTAMP_BASIS')
proposed[name] = s

name = PATHS[1]
s = owner_clock(originals[name], 'var tracker: ObjectiveTracker')
s = replace_once(s, '\torders[order_id] = {',
    '\tif not _clock.bind_state():\n\t\treturn false\n\torders[order_id] = {')
s = replace_once(s, '"status": "issued", "issued_at": Time.get_unix_time_from_system(),',
    '"status": "issued", "issued_at": _clock.elapsed_minutes(),\n'
    '\t\t"issued_at_basis": TIMESTAMP_BASIS,')
s = replace_once(s, '\torder.status = "closed"',
    '\tif not _clock.bind_state():\n\t\treturn false\n\torder.status = "closed"')
s = replace_once(s, '\torder.closed_at = Time.get_unix_time_from_system()',
    '\torder.closed_at = _clock.elapsed_minutes()\n\torder.closed_at_basis = TIMESTAMP_BASIS')
s = replace_once(s, '\tjobs[job_id] = {',
    '\tif not _clock.bind_state():\n\t\treturn false\n\tjobs[job_id] = {')
# One newly issued job and one adopted job formerly used the same host expression.
needle = '\t\t"issued_at": Time.get_unix_time_from_system(),'
assert s.count(needle) == 2
s = s.replace(needle,
    '\t\t"issued_at": _clock.elapsed_minutes(), "issued_at_basis": TIMESTAMP_BASIS,', 1)
s = replace_once(s, '\t\tevidence: Array) -> bool:',
    '\t\tevidence: Array, legacy_order_id := "") -> bool:')
s = replace_once(s, '\tvar record := {\n\t\t"stage": stage,',
    '\tvar legacy := _order(legacy_order_id).duplicate(true)\n'
    '\tif not legacy_order_id.is_empty() and legacy.is_empty():\n\t\treturn false\n'
    '\tvar record := {\n\t\t"stage": stage,')
s = replace_once(s, needle + '\n', '')
s = replace_once(s, '\t_jobs()[job_id] = record',
    '\tif not _clock.bind_state():\n\t\treturn false\n'
    '\t# Adoption is observed now; it cannot establish the original issue time.\n'
    '\trecord.adopted_at = _clock.elapsed_minutes()\n'
    '\trecord.adopted_at_basis = TIMESTAMP_BASIS\n'
    '\tif not legacy_order_id.is_empty():\n'
    '\t\trecord.legacy_order_id = legacy_order_id\n'
    '\t\trecord.legacy_order = legacy\n'
    '\t\t# Preserve old units and any existing qualification verbatim.\n'
    '\t\tfor fact in ["issued_at", "issued_at_basis"]:\n'
    '\t\t\tif legacy.has(fact):\n\t\t\t\trecord[fact] = legacy[fact]\n'
    '\t_jobs()[job_id] = record')
s = replace_once(s, 'func retire_order(order_id: String) -> bool:',
    'func retire_order(order_id: String, successor_job_id := "") -> bool:')
s = replace_once(s, '\torders.erase(order_id)',
    '\tif not successor_job_id.is_empty():\n'
    '\t\tvar successor := _job(successor_job_id)\n'
    '\t\tif successor.is_empty() or not _clock.bind_state():\n\t\t\treturn false\n'
    '\t\t# Coexisting authored progress wins, but its source history is not discarded.\n'
    '\t\t# Conflicting archival history refuses retirement rather than overwriting it.\n'
    '\t\tif successor.has("legacy_order"):\n'
    '\t\t\tif successor.get("legacy_order_id", "") != order_id \\\n'
    '\t\t\t\t\tor successor.legacy_order != orders[order_id]:\n\t\t\t\treturn false\n'
    '\t\telse:\n'
    '\t\t\tsuccessor.legacy_order_id = order_id\n'
    '\t\t\tsuccessor.legacy_order = orders[order_id].duplicate(true)\n'
    '\torders.erase(order_id)')
s = replace_once(s,
    '## Objective text and any other presentation is deliberately absent: it is\n'
    '## reconstructed from the job library on restore.',
    '## Active objective text is reconstructed from the job library on restore.\n'
    '## An opaque legacy_order archive may retain its original labels as history;\n'
    '## no presentation or deadline reads those archived labels or timestamps.')
proposed[name] = s

name = PATHS[2]
s = owner_clock(originals[name], 'var encroachment: Node')
s = replace_once(s, '\tvar flat: Dictionary = flats[unit]\n\tvar ledger: Dictionary = RealityState.data.organism_incidents',
    '\tif not _clock.bind_state():\n\t\treturn\n'
    '\tvar flat: Dictionary = flats[unit]\n\tvar ledger: Dictionary = RealityState.data.organism_incidents')
s = replace_once(s, '"reported_at": Time.get_unix_time_from_system(), "condition": "", "prop": "",',
    '"reported_at": _clock.elapsed_minutes(), "reported_at_basis": TIMESTAMP_BASIS,\n'
    '\t\t"condition": "", "prop": "",')
proposed[name] = s

name = PATHS[3]
s = owner_clock(originals[name], 'var signed_lines := 0')
s = replace_once(s, '\tvar line := {\n\t\t"at": Time.get_unix_time_from_system(),',
    '\tif not _clock.bind_state():\n\t\treturn false\n'
    '\tvar line := {\n\t\t"at": _clock.elapsed_minutes(), "at_basis": TIMESTAMP_BASIS,')
proposed[name] = s

name = PATHS[4]
s = replace_once(originals[name],
    'or not spine.adopt_job(JOB_ID, "reported", stage, evidence):',
    'or not spine.adopt_job(JOB_ID, "reported", stage, evidence, LEGACY_ORDER_ID):')
proposed[name] = replace_once(s, 'spine.retire_order(LEGACY_ORDER_ID)',
    'spine.retire_order(LEGACY_ORDER_ID, JOB_ID)')

for name, source in proposed.items():
    target = HERE / 'proposed' / name
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(source, encoding='utf-8', newline='\n')

# A unit mutation is red-capable even when every basis label is present.
for name in PATHS[:4]:
    source = proposed[name]
    assert '_clock.elapsed_minutes()' in source
    target = HERE / 'controls/wrapped_minute' / name
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(source.replace('_clock.elapsed_minutes()', '_clock.minute_of_day()'),
                      encoding='utf-8', newline='\n')

patch = []
rows = []
for target in sorted((HERE / 'proposed').rglob('*')):
    if not target.is_file():
        continue
    relative = target.relative_to(HERE / 'proposed').as_posix()
    old = originals.get(relative, '')
    text = target.read_text(encoding='utf-8')
    patch.extend(difflib.unified_diff(old.splitlines(keepends=True), text.splitlines(keepends=True),
        fromfile='a/' + relative if relative in originals else '/dev/null', tofile='b/' + relative))
    rows.append({'path': relative, 'sha256': hashlib.sha256(target.read_bytes()).hexdigest()})
(HERE / 'world_timestamps.patch').write_text(''.join(patch), encoding='utf-8', newline='\n')
receipt = {'status': 'prepared_not_applied_not_runtime_executed',
    'source_head': subprocess.check_output(['git', '-C', str(ROOT), 'rev-parse', 'HEAD']).decode().strip(),
    'files': rows,
    'originals': {name: hashlib.sha256((HERE / 'originals' / name).read_bytes()).hexdigest() for name in PATHS},
    'originals_match_live': all((HERE / 'originals' / name).read_bytes() == (ROOT / name).read_bytes() for name in PATHS),
    'checks': ['Unique mutation anchors', 'Original/live exact byte comparisons',
               'Prepared patch and wrapped-minute negative source control'],
    'not_run': ['Godot parser/import', 'original-source red', 'candidate green', 'wrapped-minute red',
                'save/load and existing owner regression scenes']}
(HERE / 'preparation_receipt.json').write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8')
print(json.dumps(receipt, indent=2))
