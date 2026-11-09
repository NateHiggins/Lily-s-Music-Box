"""Texture audit: import parsing, header sizes, load-trace mapping and sorting."""
import struct, sys, tempfile, unittest, zlib
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]; sys.path.insert(0, str(ROOT / 'tools'))
import audit_textures as at

IMPORT = '''[remap]

importer="texture"
type="CompressedTexture2D"
uid="uid://abc123"
path.s3tc="res://.godot/imported/wall_albedo.png-0f.s3tc.ctex"

[deps]

source_file="res://assets/wall_albedo.png"
dest_files=["res://.godot/imported/wall_albedo.png-0f.s3tc.ctex"]

[params]

compress/mode=2
compress/normal_map=0
mipmaps/generate=true
process/size_limit=0
'''


def png(width, height, colour=2):
    raw = b''.join(b'\x00' + b'\x00' * width * 3 for _ in range(height))
    def chunk(kind, data):
        return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data))
    return (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, colour, 0, 0, 0))
            + chunk(b'IDAT', zlib.compress(raw)) + chunk(b'IEND', b''))


class TextureAuditTests(unittest.TestCase):
    def test_import_settings_reads_cost_keys_and_imported_files(self):
        s = at.import_settings(IMPORT)
        self.assertEqual((s['importer'], s['compress'], s['mipmaps'], s['uid']),
                         ('texture', '2', 'true', 'uid://abc123'))
        self.assertEqual(s['dest_files'], ['.godot/imported/wall_albedo.png-0f.s3tc.ctex'])

    def test_png_header_gives_size_and_mode(self):
        self.assertEqual(at.image_size(png(972, 4)), (972, 4, 'RGB'))
        self.assertFalse(at.is_power_of_two(972)); self.assertTrue(at.is_power_of_two(1024))

    def test_trace_maps_imported_files_back_to_their_source(self):
        with tempfile.TemporaryDirectory() as tmp:
            log = Path(tmp) / 'route.log'
            log.write_text('Loading resource: res://.godot/imported/wall_albedo.png-0f.s3tc.ctex\n'
                           'Loading resource: res://assets/wall_albedo.png\n'
                           "Completed load for: 'res://scenes/room.tscn' remapped 'res://scenes/room.tscn' at thread 2\n",
                           encoding='utf8')
            loaded = at.trace_paths([log], {'.godot/imported/wall_albedo.png-0f.s3tc.ctex': 'assets/wall_albedo.png'})
        self.assertEqual(loaded['assets/wall_albedo.png'], ['route.log'])
        self.assertIn('scenes/room.tscn', loaded)

    def test_audit_sorts_loaded_never_loaded_untraced_and_duplicates(self):
        with tempfile.TemporaryDirectory() as tmp:
            game = Path(tmp) / 'game'
            for rel in ['assets/building/a.png', 'assets/building/b.png', 'assets/ui/c.png', 'tests/d.png']:
                (game / rel).parent.mkdir(parents=True, exist_ok=True); (game / rel).write_bytes(png(8, 8))
            (game / 'assets/building/a.png.import').write_text(IMPORT, encoding='utf8')
            (game / 'room.tscn').write_text('[ext_resource path="res://assets/building/a.png"]', encoding='utf8')
            log = Path(tmp) / 'trace.log'; log.write_text('Loading resource: res://assets/building/a.png\n', encoding='utf8')
            rows = {r['path']: r for r in at.audit(Path(tmp), [log])['textures']}
        self.assertNotIn('tests/d.png', rows)
        self.assertEqual(rows['assets/building/a.png']['trace'], 'loaded')
        self.assertEqual(rows['assets/building/a.png']['reference'], 'path')
        self.assertEqual(rows['assets/building/b.png']['trace'], 'never_loaded')
        self.assertEqual(rows['assets/ui/c.png']['trace'], 'not_traced')
        self.assertEqual(rows['assets/building/b.png']['duplicate_of'], 'assets/building/a.png')


if __name__ == '__main__':
    unittest.main()
