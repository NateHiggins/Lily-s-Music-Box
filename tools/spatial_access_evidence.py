"""Validate source-bound spatial access proof without granting runtime/case acceptance."""
import hashlib
import json
import math
import re
from pathlib import Path


def validate(data, root, runtime_digest, surface_digest):
    errors = []
    root = Path(root).resolve()
    if not isinstance(data, dict):
        return ['spatial receipt must be an object']
    try:
        if data.get('schema_version') != 2 or data.get('evidence_kind') != 'runtime_contract' or data.get('selector') != 'v2' or data.get('production_runtime') is not True:
            errors.append('schema-2 production V2 runtime contract required')
        execution = data['execution']
        if execution.get('completed') is not True or execution.get('exit_code') != 0 or execution.get('timed_out') is not False:
            errors.append('successful completed execution required')
        if data.get('failures') != 0 or not data.get('checks') or any(row.get('ok') is not True for row in data['checks']):
            errors.append('all executed checks must pass')
        source = data['source']
        if source.get('runtime_inputs_sha256') != runtime_digest or not runtime_digest:
            errors.append('runtime inputs are stale')
        if source.get('surface_inputs_sha256') != surface_digest or not surface_digest:
            errors.append('geometry/surface inputs are stale')
        if not re.fullmatch(r'[0-9a-f]{40}', source.get('repository_head', '')):
            errors.append('recorded repository head required')
        bindings = source['test_dependencies']
        entry = source['test_path']
        if not entry.endswith('.gd') or bindings.get(entry) != source.get('test_sha256'):
            errors.append('root test binding missing')
        referenced = {entry}
        for relative, digest in bindings.items():
            path = (root / relative).resolve()
            if not path.is_relative_to(root / 'game/tests') or not path.is_file() or Path(relative).is_absolute() or '..' in Path(relative).parts:
                errors.append('invalid test dependency: ' + relative)
                continue
            text = path.read_text(encoding='utf-8').replace('\r\n', '\n')
            if hashlib.sha256(text.encode()).hexdigest() != digest:
                errors.append('stale test dependency: ' + relative)
            referenced.update('game/' + x.removeprefix('res://') for x in re.findall(r'res://tests/[A-Za-z0-9_/.-]+', text))
        if referenced - set(bindings):
            errors.append('unbound test dependencies: ' + ', '.join(sorted(referenced - set(bindings))))
        contracts = data['contracts']
        for name in ['production_composition', 'room_access', 'teardown']:
            if contracts[name].get('executed') is not True or contracts[name].get('status') != 'PASS':
                errors.append('executed PASS required: ' + name)
        teardown = contracts['teardown']
        if teardown.get('retained_nodes') != 0 or teardown.get('tracked_nodes', 0) < 2:
            errors.append('measured root/driver retirement required')
        legs = data['legs']
        if not legs:
            errors.append('played legs required')
        points = {}
        for leg in legs:
            if leg['name'] in points or leg.get('failures') != [] or not leg.get('trace') or leg.get('initial_placement_only') is not True:
                errors.append('complete distinct collision-bearing leg required')
            points[leg['name']] = []
            for step in leg['trace']:
                actual, target = step['actual'], step['target']
                if len(actual) != 3 or len(target) != 3 or not all(type(v) in (int, float) and math.isfinite(v) for v in actual + target):
                    errors.append('finite three-axis route coordinates required')
                    continue
                if step.get('ok') is not True or math.hypot(actual[0]-target[0], actual[2]-target[2]) >= .18 or abs(actual[1]-target[1]) >= .15:
                    errors.append('route step did not reach its target')
                points[leg['name']].append(actual)
        layout = json.loads((root / 'game/data/orison_v2_blockout.json').read_text(encoding='utf-8'))
        rooms = {r['id']: r for r in layout['spaces']}
        floors = {r['id']: r['y'] for r in layout['levels']}
        claims = contracts['room_access']['rooms']
        if not claims:
            errors.append('visited rooms required')
        for identity, claim in claims.items():
            if identity not in rooms or claim['actual'] not in points.get(claim['leg'], []):
                errors.append('room lacks a played trace point: ' + identity)
                continue
            p = claim['actual']; room = rooms[identity]; r = room['rect']
            if not (r[0]+.05 < p[0] < r[2]-.05 and r[1]+.05 < p[2] < r[3]-.05 and abs(p[1]-floors[room['level']]) < .15):
                errors.append('trace point is outside claimed room: ' + identity)
    except (KeyError, TypeError, ValueError, OSError, AttributeError) as exc:
        errors.append('malformed spatial receipt: ' + str(exc))
    return errors
