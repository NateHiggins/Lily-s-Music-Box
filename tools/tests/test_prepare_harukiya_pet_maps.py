import base64
import json
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import unittest
import shutil

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
from tools.prepare_harukiya_pet_maps import prepare

PNG = base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+afo8AAAAASUVORK5CYII=')


def asset(path, names=('fur', 'normal')):
    binary = b''
    views = []
    for name in names:
        start = len(binary)
        binary += PNG
        views.append({'buffer': 0, 'byteOffset': start, 'byteLength': len(PNG)})
        binary += b'\0' * (-len(binary) % 4)
    doc = {'asset': {'version': '2.0'}, 'buffers': [{'byteLength': len(binary)}],
           'bufferViews': views,
           'images': [{'name': name, 'mimeType': 'image/png', 'bufferView': i} for i, name in enumerate(names)]}
    text = json.dumps(doc).encode()
    text += b' ' * (-len(text) % 4)
    chunks = struct.pack('<II', len(text), 0x4E4F534A) + text + struct.pack('<II', len(binary), 0x004E4942) + binary
    path.write_bytes(b'glTF' + struct.pack('<II', 2, len(chunks) + 12) + chunks)


class PetMapRestoreTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.project = Path(self.temporary.name)
        self.folder = self.project / 'assets/characters/harukiya_pets'
        self.folder.mkdir(parents=True)
        asset(self.folder / 'judge.glb')
        # Reproduce the source-present/PNG-missing sidecar condition without
        # deleting or touching a real checkout or import cache.
        self.sidecar = self.folder / 'judge_fur.png.import'
        self.sidecar.write_text('[remap]\ngenerator_parameters={"md5":"matching_pixels"}\n[params]\nmipmaps/generate=true\n')

    def test_missing_maps_restore_exactly_and_preserve_import_settings(self):
        before = self.sidecar.read_bytes()
        result = prepare(self.project)
        self.assertEqual(result['restored'], 2)
        self.assertEqual((self.folder / 'judge_fur.png').read_bytes(), PNG)
        self.assertEqual((self.folder / 'judge_normal.png').read_bytes(), PNG)
        self.assertEqual(self.sidecar.read_bytes(), before)
        self.assertEqual(prepare(self.project)['restored'], 0)

    def test_check_is_read_only(self):
        result = prepare(self.project, check=True)
        self.assertEqual(result['missing'], 2)
        self.assertEqual(result['status'], 'FAIL')
        self.assertFalse(list(self.folder.glob('*.png')))

    def test_conflict_preserves_existing_file_and_prevents_partial_restore(self):
        target = self.folder / 'judge_normal.png'
        target.write_bytes(b'owner-modified')
        with self.assertRaisesRegex(ValueError, 'differs'):
            prepare(self.project)
        self.assertEqual(target.read_bytes(), b'owner-modified')
        self.assertFalse((self.folder / 'judge_fur.png').exists())

    def test_unsafe_image_name_does_not_escape_asset_directory(self):
        asset(self.folder / 'judge.glb', ('../escape',))
        with self.assertRaisesRegex(ValueError, 'name'):
            prepare(self.project)
        self.assertFalse(list(self.folder.glob('*.png')))

    def test_truncated_binary_is_rejected_without_writes(self):
        path = self.folder / 'judge.glb'
        path.write_bytes(path.read_bytes()[:-1])
        with self.assertRaisesRegex(ValueError, 'header'):
            prepare(self.project)
        self.assertFalse(list(self.folder.glob('*.png')))

    def test_project_without_pets_is_unchanged(self):
        with tempfile.TemporaryDirectory() as name:
            result = prepare(Path(name))
            self.assertEqual(result['status'], 'PASS')
            self.assertEqual(result['maps'], [])
            self.assertEqual(list(Path(name).iterdir()), [])

    def test_cli_reports_restore_then_clean_check(self):
        script = ROOT / 'tools/prepare_harukiya_pet_maps.py'
        for flags in [[], ['--check']]:
            run = subprocess.run([sys.executable, str(script), '--project', str(self.project), *flags],
                                 text=True, capture_output=True)
            self.assertEqual(run.returncode, 0, run.stderr)
            self.assertEqual(json.loads(run.stdout)['status'], 'PASS')

    @unittest.skipUnless(shutil.which('pwsh'), 'PowerShell is not installed')
    def test_actual_runner_preparation_restores_maps_and_records_source_hashes(self):
        def quote(path):
            return "'" + str(path).replace("'", "''") + "'"
        log = self.project / 'logs/test.log'
        command = '. ' + quote(ROOT / 'tools/lane_common.ps1')
        command += '; Initialize-OrisonGeneratedPetMaps -ProjectPath ' + quote(self.project)
        command += ' -LogPath ' + quote(log) + ' -Importing'
        result = subprocess.run(['pwsh', '-NoProfile', '-Command', command], text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.folder / 'judge_fur.png').read_bytes(), PNG)
        record = json.loads(Path(str(log) + '.pet_maps.json').read_text())
        self.assertEqual(record['restored'], 2)
        self.assertEqual(record['sources'][0]['file'], 'judge.glb')

    def test_restored_maps_retire_only_stale_scene_freshness_marker(self):
        imported = self.project / '.godot/imported'
        imported.mkdir(parents=True)
        name = 'judge.glb-' + 'a' * 32
        scene = imported / (name + '.scn')
        marker = imported / (name + '.md5')
        scene.write_bytes(b'previous-embedded-scene')
        marker.write_bytes(b'previous-freshness-marker')
        (self.folder / 'judge.glb.import').write_text('[remap]\npath="res://.godot/imported/' + name + '.scn"\n')
        result = prepare(self.project)
        self.assertTrue(result['imports_required'])
        self.assertFalse(marker.exists())
        self.assertEqual(scene.read_bytes(), b'previous-embedded-scene')
        self.assertEqual(result['invalidated_scene_imports'][0]['prior_bytes_hex'], b'previous-freshness-marker'.hex())
        # A retry must still request import, even though maps now exist.
        self.assertTrue(prepare(self.project)['imports_required'])

    def test_second_import_refreshes_scene_after_textures_exist(self):
        prepare(self.project)
        imported = self.project / '.godot/imported'
        imported.mkdir(parents=True)
        name = 'judge.glb-' + 'b' * 32
        (imported / (name + '.scn')).write_bytes(b'scene-created-before-texture-import')
        marker = imported / (name + '.md5')
        marker.write_bytes(b'old-marker')
        (self.folder / 'judge.glb.import').write_text('[remap]\npath="res://.godot/imported/' + name + '.scn"\n')
        before_settings = (self.folder / 'judge.glb.import').read_bytes()
        before_time = (self.folder / 'judge.glb.import').stat().st_mtime_ns
        result = prepare(self.project, force_scene_import=True)
        self.assertEqual(result['restored'], 0)
        self.assertEqual(len(result['invalidated_scene_imports']), 1)
        self.assertFalse(marker.exists())
        self.assertEqual((self.folder / 'judge.glb.import').read_bytes(), before_settings)
        self.assertGreaterEqual((self.folder / 'judge.glb.import').stat().st_mtime_ns - before_time, 2_000_000_000)


if __name__ == '__main__':
    unittest.main()
