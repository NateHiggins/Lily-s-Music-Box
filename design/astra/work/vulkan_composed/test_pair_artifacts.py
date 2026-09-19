"""Damaged metadata controls; no engine and no production mutation."""
import copy
from pathlib import Path
import tempfile
import unittest

from pair_bookkeeping import sha
from pair_bookkeeping_case import REQUIRED_ARTIFACTS, validate_artifacts


class PairArtifactControls(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.folder = Path(self.tmp.name)
        names = REQUIRED_ARTIFACTS | {'before_sources/game/example.gd'}
        for name in names:
            path = self.folder / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b'synthetic parser bytes, not evidence')
        self.result = {'artifacts': {name: sha((self.folder / name).read_bytes()) for name in names},
                       'before': {'files': {'game/example.gd': sha((self.folder / 'before_sources/game/example.gd').read_bytes())}}}

    def tearDown(self):
        self.tmp.cleanup()

    def test_complete_map_validates(self):
        validate_artifacts(self.folder, self.result)

    def test_empty_or_missing_map_rejected(self):
        for result in [{}, dict(self.result, artifacts={})]:
            with self.assertRaises(ValueError):
                validate_artifacts(self.folder, result)

    def test_each_consumed_artifact_must_be_named_even_if_file_exists(self):
        for name in REQUIRED_ARTIFACTS:
            result = copy.deepcopy(self.result)
            result['artifacts'].pop(name)
            with self.subTest(name=name), self.assertRaises(ValueError):
                validate_artifacts(self.folder, result)

    def test_removed_consumed_file_and_entry_still_rejected(self):
        result = copy.deepcopy(self.result)
        result['artifacts'].pop('stdout.log')
        (self.folder / 'stdout.log').unlink()
        with self.assertRaises(ValueError):
            validate_artifacts(self.folder, result)

    def test_mutated_log_or_probe_rejected(self):
        for name in ['stdout.log', 'stdout.log.stderr', 'frames/probe.json']:
            path = self.folder / name
            before = path.read_bytes()
            path.write_bytes(b'mutated')
            with self.subTest(name=name), self.assertRaises(ValueError):
                validate_artifacts(self.folder, self.result)
            path.write_bytes(before)

    def test_omitted_other_artifact_rejected(self):
        result = copy.deepcopy(self.result)
        result['artifacts'].pop('before_sources/game/example.gd')
        with self.assertRaises(ValueError):
            validate_artifacts(self.folder, result)

    def test_source_copy_must_match_snapshot(self):
        result = copy.deepcopy(self.result)
        result['before']['files']['game/example.gd'] = 'different'
        with self.assertRaises(ValueError):
            validate_artifacts(self.folder, result)


if __name__ == '__main__':
    unittest.main()
