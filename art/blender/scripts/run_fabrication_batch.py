"""Run explicit build/inspect stages in one Blender process, stopping on first error.

blender --background --python art/blender/scripts/run_fabrication_batch.py -- --plan tmp/batch.json
Plan: {"stages":[{"script":"art/blender/scripts/build_x.py","env":{}}, ...]}
Use --dry-run with ordinary Python to validate a plan without starting Blender.
"""
import argparse
import json
import os
from pathlib import Path
import runpy
import sys
import time

ROOT = Path(__file__).resolve().parents[3]


def validate(plan: dict, root: Path = ROOT) -> list[dict]:
    stages = plan.get('stages', [])
    if not stages: raise ValueError('batch requires explicit stages')
    for stage in stages:
        script = (root / stage['script']).resolve()
        if not script.is_relative_to(root.resolve()) or not script.is_file() or script.suffix != '.py':
            raise ValueError(f'Invalid repository script: {script}')
        if not isinstance(stage.get('env', {}), dict) or not all(isinstance(k, str) and isinstance(v, str) for k, v in stage.get('env', {}).items()):
            raise ValueError('Stage environment must contain string keys and values')
    return stages


def execute(stages: list[dict], root: Path = ROOT) -> list[dict]:
    import bpy
    results = []
    for stage in stages:
        before = dict(os.environ)
        argv = sys.argv[:]
        path = sys.path[:]
        cwd = Path.cwd()
        started = time.monotonic()
        try:
            bpy.ops.wm.read_factory_settings(use_empty=True)
            os.environ.update(stage.get('env', {}))
            os.chdir(root)
            sys.argv = [str(root / stage['script'])]
            sys.path.insert(0, str((root / stage['script']).parent))
            print('FABRICATION STAGE: ' + stage['script'], flush=True)
            try:
                runpy.run_path(sys.argv[0], run_name='__main__')
            except SystemExit as exc:
                if exc.code not in (None, 0): raise
            results.append({'script':stage['script'], 'elapsed_s':round(time.monotonic()-started, 3)})
        finally:
            os.environ.clear(); os.environ.update(before)
            sys.argv[:] = argv
            sys.path[:] = path
            os.chdir(cwd)
    return results


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--plan', type=Path, required=True)
    parser.add_argument('--dry-run', action='store_true')
    parser.add_argument('--receipt', type=Path)
    args = parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else None)
    # A failed retry must never leave an old success receipt looking current.
    if args.receipt and not args.dry_run:
        args.receipt.parent.mkdir(parents=True, exist_ok=True)
        args.receipt.write_text(json.dumps({'evidence_class':'INERT', 'completed':False})+'\n', newline='\n')
    stages = validate(json.loads(args.plan.read_text(encoding='utf-8')))
    if args.dry_run:
        print(json.dumps({'stages':[stage['script'] for stage in stages]})); return
    results = execute(stages)
    if args.receipt:
        args.receipt.parent.mkdir(parents=True, exist_ok=True)
        args.receipt.write_text(json.dumps({'evidence_class':'INERT', 'completed':True, 'completed_stages':results}, indent=2)+'\n', newline='\n')
    print(json.dumps({'completed_stages':len(results), 'elapsed_s':sum(row['elapsed_s'] for row in results)}))


if __name__ == '__main__': main()
