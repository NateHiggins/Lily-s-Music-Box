"""Build the four-emitter native retrofit and strict scratch GLB in one Blender run.

Run Blender --background --python-exit-code 1 --python this_file --
--work-dir <scratch-directory>. Does not edit production data or publish assets.
"""
import json
import os
from pathlib import Path
import runpy
import sys

HERE = Path(__file__).resolve().parent/'heating_refit'
sys.path.insert(0, str(HERE))
from heating_refit_context import OUT, PLAN, bindings

before = bindings()
for name, data in [('routes', PLAN['routes']), ('supports', PLAN['supports']), ('passages', PLAN['projection'])]:
    (OUT/(name+'.json')).write_text(json.dumps(data, indent=2)+'\n', encoding='utf-8', newline='\n')
os.environ['HEATING_CANDIDATE_ROUTES'] = str(OUT/'routes.json')
os.environ['HEATING_NATIVE_PREFIX'] = 'refit_pipes'
os.environ['HEATING_SUPPORTED_PREFIX'] = 'refit_supported'
os.environ['HEATING_SUPPORTS'] = str(OUT/'supports.json')
for name in ['build_pipes.py', 'build_hangers.py', 'build_sleeves.py', 'export.py']:
    runpy.run_path(str(HERE/name), run_name='__main__')
after = bindings()
if before != after:
    raise RuntimeError('Authoring inputs changed during native generation')
native = json.loads((OUT/'native_review.json').read_text())
export = json.loads((OUT/'export/export_review.json').read_text())
if native['failures'] or native['native_sha256'] != export['native_sha256']:
    raise RuntimeError('Native/export source binding failed')
report = {'evidence_class': 'INERT', 'scope': 'Reproducible native construction and scratch export only; no installed runtime or human acceptance.',
          'source_bindings': after, 'native_sha256': native['native_sha256'],
          'asset_sha256': export['asset_sha256'], 'exported_tangents': export['exported_tangents'], 'failures': []}
(OUT/'build_review.json').write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8', newline='\n')
print('PORTABLE HEATING REFIT BUILD PASS', flush=True)
