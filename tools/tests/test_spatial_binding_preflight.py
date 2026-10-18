import sys
import json
import hashlib
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from preflight_spatial_test_bindings import check, check_fixture


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

    def native_fixture(self,relative,payload,digest=None):
        target=self.root/relative;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(payload)
        fixture=self.tests/'fixtures/native.json';fixture.parent.mkdir(exist_ok=True)
        fixture.write_text(json.dumps({'source_bindings':{relative:digest or hashlib.sha256(payload).hexdigest()}}))
        return fixture,target

    def test_native_binding_expires_when_real_source_changes(self):
        fixture,target=self.native_fixture('game/source.gd',b'old\n')
        target.write_bytes(b'new\n')
        self.assertEqual(check_fixture(fixture,self.root),['stale fixture dependency: game/source.gd'])

    def test_native_text_binding_survives_checkout_newlines(self):
        fixture,_=self.native_fixture('game/source.gd',b'line\r\n',hashlib.sha256(b'line\n').hexdigest())
        self.assertEqual(check_fixture(fixture,self.root),[])

    def test_native_binary_digest_does_not_normalize_bytes(self):
        fixture,_=self.native_fixture('game/mesh.glb',b'binary\r\nstock')
        self.assertEqual(check_fixture(fixture,self.root),[])

    def test_native_missing_dependency_is_not_accepted(self):
        fixture,target=self.native_fixture('game/source.gd',b'stock')
        target.unlink()
        self.assertEqual(check_fixture(fixture,self.root),['missing fixture dependency: game/source.gd'])

    def test_native_binding_cannot_read_outside_repository(self):
        fixture,_=self.native_fixture('game/source.gd',b'stock')
        fixture.write_text(json.dumps({'source_bindings':{'../outside':'0'*64}}))
        self.assertEqual(check_fixture(fixture,self.root),['fixture dependency escapes repository: ../outside'])

    def test_native_fixture_requires_real_bindings(self):
        fixture,_=self.native_fixture('game/source.gd',b'stock')
        for payload in [[],{}, {'source_bindings':{}}]:
            fixture.write_text(json.dumps(payload))
            self.assertTrue(check_fixture(fixture,self.root))


if __name__ == '__main__':
    unittest.main()
