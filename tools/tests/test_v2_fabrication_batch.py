#!/usr/bin/env python3
"""Dirty-input selection and Blender stage isolation without launching Godot."""
import json
import os
from pathlib import Path
import sys
import tempfile
import types
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
sys.path.insert(0, str(ROOT / 'art/blender/scripts'))
import plan_v2_fabrication as planner
import run_fabrication_batch as runner


class PlannerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.put('game/project.godot', 'config_version=5\n')
        self.put('game/shaders/shared.gdshaderinc', 'float value = 1.;\n')
        for name in ['pawn_clocks', 'pawn_display']:
            source = f'art/data/{name}/source_plan.json'
            self.put(source, '{}\n')
            self.put(f'art/blender/scripts/build_{name}.py', 'pass\n')
            self.put(f'art/blender/{name}.blend', 'native')
            self.put(f'game/assets/props/{name}.glb', 'mesh')
            self.put(f'game/tests/fixtures/orison_{name}.json', json.dumps({
                'source_bindings':{source:planner.digest(self.root/source)},
                'asset_sha256':planner.digest(self.root/f'game/assets/props/{name}.glb')}))

    def put(self, path, content):
        target = self.root / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(content.encode())

    def test_repeat_is_clean_but_not_evidence(self):
        first = planner.make_plan(self.root)
        repeat = planner.make_plan(self.root, first)
        self.assertEqual(repeat['queue'], [])
        self.assertEqual(first['evidence_class'], 'INERT')

    def test_changed_family_and_shared_shader(self):
        first = planner.make_plan(self.root)
        self.put('art/data/pawn_display/source_plan.json', '{"change":true}\n')
        second = planner.make_plan(self.root, first)
        self.assertEqual(second['queue'], ['pawn_display'])
        self.assertEqual(second['review_queue'], ['pawn_display'])
        self.put('game/shaders/shared.gdshaderinc', 'float value = 2.;\n')
        self.assertEqual(planner.make_plan(self.root, second)['queue'], ['pawn_clocks', 'pawn_display'])

    def test_missing_asset_never_disappears_from_review(self):
        (self.root/'game/assets/props/pawn_display.glb').unlink()
        first = planner.make_plan(self.root)
        repeat = planner.make_plan(self.root, first)
        self.assertEqual(repeat['review_queue'], ['pawn_display'])
        self.assertEqual(repeat['summary']['missing'], 1)

    def test_lf_normalized_source_and_binary_integrity(self):
        first = planner.make_plan(self.root)
        self.put('art/data/pawn_display/source_plan.json', '{}\r\n')
        self.assertEqual(planner.make_plan(self.root, first)['queue'], [])
        self.put('game/assets/props/pawn_display.glb', 'changedmesh')
        self.assertEqual(planner.make_plan(self.root, first)['queue'], ['pawn_display'])

    def test_explicit_unknown_family_refused(self):
        with self.assertRaises(ValueError): planner.make_plan(self.root, selected=['not_registered'])


class StageTests(unittest.TestCase):
    def test_stages_restore_environment_and_fail_before_next_stage(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root/'one.py').write_text('import os,sys\nassert os.environ["V2_BATCH_TEST"]=="one"\nos.environ["V2_BATCH_TEST"]="mutated"\nsys.argv.append("leak")\n')
            (root/'two.py').write_text('import os,sys\nassert os.environ["V2_BATCH_TEST"]=="two"\nassert "leak" not in sys.argv\n')
            (root/'fail.py').write_text('raise RuntimeError("stop batch")\n')
            (root/'never.py').write_text('raise AssertionError("must not run")\n')
            factory_calls = []
            bpy = types.SimpleNamespace(ops=types.SimpleNamespace(wm=types.SimpleNamespace(
                read_factory_settings=lambda **kw: factory_calls.append(kw))))
            stages = [{'script':'one.py', 'env':{'V2_BATCH_TEST':'one'}},
                      {'script':'two.py', 'env':{'V2_BATCH_TEST':'two'}}]
            old_argv, old_path, old_cwd = sys.argv[:], sys.path[:], Path.cwd()
            with patch.dict(sys.modules, {'bpy':bpy}), patch.dict(os.environ, {'V2_BATCH_TEST':'before'}):
                result = runner.execute(runner.validate({'stages':stages}, root), root)
                self.assertEqual(len(result), 2)
                self.assertEqual(len(factory_calls), 2)
                self.assertEqual(os.environ['V2_BATCH_TEST'], 'before')
                with self.assertRaisesRegex(RuntimeError, 'stop batch'):
                    runner.execute([{'script':'fail.py'}, {'script':'never.py'}], root)
                self.assertEqual(len(factory_calls), 3)
            self.assertEqual((sys.argv, sys.path, Path.cwd()), (old_argv, old_path, old_cwd))
            with self.assertRaises(ValueError): runner.validate({'stages':[{'script':'../outside.py'}]}, root)


if __name__ == '__main__': unittest.main()
