import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from preflight_spatial_test_bindings import check


class BindingPreflightTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.tests = self.root / 'game/tests'
        self.tests.mkdir(parents=True)
        self.entry = self.tests / 'entry.gd'

    def write_entry(self, extra=''):
        self.entry.write_text('const SOURCES := ["res://tests/entry.gd"' + extra + ']\n', encoding='utf-8')

    def test_inherited_helper_missing_from_declaration(self):
        self.write_entry(', "res://tests/base.gd"')
        (self.tests / 'base.gd').write_text('const H = preload("res://tests/helper.gd")')
        (self.tests / 'helper.gd').write_text('extends Node')
        self.assertEqual(check(self.entry, self.root), ['unbound dependency: res://tests/helper.gd'])

    def test_bound_cycle_terminates(self):
        self.write_entry(', "res://tests/base.gd"')
        (self.tests / 'base.gd').write_text('extends "res://tests/entry.gd"')
        self.assertEqual(check(self.entry, self.root), [])

    def test_absent_declared_file_fails(self):
        self.write_entry(', "res://tests/missing.gd"')
        self.assertEqual(check(self.entry, self.root), ['missing dependency file: res://tests/missing.gd'])

    def test_escape_is_rejected(self):
        self.write_entry(', "res://tests/../private.gd"')
        self.assertEqual(check(self.entry, self.root), ['dependency escapes game/tests: res://tests/../private.gd'])

    def test_missing_self_binding_fails(self):
        self.entry.write_text('const SOURCES := []')
        self.assertEqual(check(self.entry, self.root), ['unbound dependency: res://tests/entry.gd'])

    def test_no_declaration_is_not_a_pass(self):
        self.entry.write_text('extends Node')
        self.assertEqual(check(self.entry, self.root), ['missing static SOURCES declaration'])

    def test_typed_multiline_declaration(self):
        self.entry.write_text('const SOURCES: Array[String] = [\n"res://tests/entry.gd",\n]')
        self.assertEqual(check(self.entry, self.root), [])


if __name__ == '__main__':
    unittest.main()
