"""Prevent the recurring square-ended jamb behind a mitred front surround."""
import json
import math
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT/'art/blender/scripts'))
from frame_mitre_geometry import frame_parts, interface_points


class DoorFrameMitresTest(unittest.TestCase):
    def test_every_source_opening_has_two_full_depth_diagonal_contacts(self):
        layout = json.loads((ROOT/'game/data/orison_v2_blockout.json').read_text())
        self.assertEqual(len(layout['doors']), 111)
        for door in layout['doors']:
            for depth in [.14, .35]:
                with self.subTest(door=door['id'], depth=depth):
                    width, height, stock = door['width'], door['height'], .09
                    parts = frame_parts(width, height, stock, depth)
                    caps = interface_points(parts)
                    self.assertEqual(set(caps), {'left', 'right'})
                    for name, sign in [('left', -1), ('right', 1)]:
                        cap = caps[name]
                        self.assertEqual(len(cap), 4)
                        self.assertAlmostEqual(max(p[1] for p in cap)-min(p[1] for p in cap), depth)
                        # The two solids lie on opposing sides of the shared
                        # 45-degree plane: no overlapping corner or open gap.
                        plane = height-width/2
                        side = [p[2]-sign*p[0] for p in parts[name]['vertices']]
                        head = [p[2]-sign*p[0] for p in parts['head']['vertices']]
                        self.assertLessEqual(max(side), plane+1e-12)
                        self.assertGreaterEqual(min(head), plane-1e-12)
                        self.assertTrue(all(math.isclose(p[2]-sign*p[0], plane) for p in cap))
                    self.assertEqual(sum(len(p['faces'])*2 for p in parts.values()), 36)

    def test_invalid_dimensions_cannot_create_native_stock(self):
        for dimensions in [(0,2,.09,.14),(1,-2,.09,.14),(1,2,0,.14),(1,2,.09,-.14)]:
            with self.subTest(dimensions=dimensions), self.assertRaises(ValueError):
                frame_parts(*dimensions)

    def test_tall_heads_retain_their_envelope_without_square_jamb_overlaps(self):
        for width,height,jamb,depth,head in [(1.1,2.13,.1,.375,.12),(.95,2.1,.1,.16,.45),(1,2.14,.09,.2,.14)]:
            parts=frame_parts(width,height,jamb,depth,head_width=head)
            interface_points(parts)
            self.assertAlmostEqual(max(p[2] for p in parts['head']['vertices']),height+head)
            self.assertAlmostEqual(max(p[2] for p in parts['left']['vertices']),height+jamb)
            self.assertAlmostEqual(max(p[2] for p in parts['right']['vertices']),height+jamb)


if __name__ == '__main__':
    unittest.main()
