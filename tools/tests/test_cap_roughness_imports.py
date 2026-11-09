"""Roughness import cap: half the albedo, block-aligned, square only, exclusions kept."""
import struct, sys, tempfile, unittest, zlib
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]; sys.path.insert(0, str(ROOT / 'art/tools'))
import cap_roughness_imports as cap


def png(width, height):
    def chunk(kind, data):
        return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data))
    return (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0))
            + chunk(b'IEND', b''))


class CapRoughnessTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(); self.game = Path(self.tmp.name) / 'game'
        cap.GAME = self.game

    def tearDown(self):
        self.tmp.cleanup()

    def add(self, rel, size, mode='2'):
        path = self.game / rel; path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(png(*size))
        if rel.endswith('_rough.png'):
            path.with_name(path.name + '.import').write_text(
                '[params]\n\ncompress/mode=%s\nprocess/size_limit=0\n' % mode, encoding='utf8')
        return path

    def test_limit_is_half_the_albedo_on_the_block_grid(self):
        self.add('assets/t/T_a_albedo.png', (1254, 1254))
        rough = self.add('assets/t/T_a_rough.png', (1254, 1254))
        self.assertEqual(cap.wanted_limit(rough), 624)
        self.add('assets/t/T_b_albedo.png', (1024, 1024))
        self.assertEqual(cap.wanted_limit(self.add('assets/t/T_b_rough.png', (1024, 1024))), 512)

    def test_already_small_non_square_lossless_and_dream_maps_are_left_alone(self):
        self.add('assets/t/T_c_albedo.png', (1024, 1024))
        self.assertIsNone(cap.wanted_limit(self.add('assets/t/T_c_rough.png', (512, 512))))
        self.add('assets/t/T_d_albedo.png', (1024, 512))
        self.assertIsNone(cap.wanted_limit(self.add('assets/t/T_d_rough.png', (1024, 512))))
        self.add('assets/t/T_e_albedo.png', (1024, 1024))
        self.assertIsNone(cap.wanted_limit(self.add('assets/t/T_e_rough.png', (1024, 1024), mode='0')))
        self.add('assets/dream/T_f_albedo.png', (1024, 1024))
        self.assertIsNone(cap.wanted_limit(self.add('assets/dream/T_f_rough.png', (1024, 1024))))

    def test_set_limit_replaces_or_appends_only_its_key(self):
        self.assertEqual(cap.set_limit('a=1\nprocess/size_limit=0\n', 512), 'a=1\nprocess/size_limit=512\n')
        self.assertEqual(cap.set_limit('a=1\n', 256), 'a=1\nprocess/size_limit=256\n')


if __name__ == '__main__':
    unittest.main()
