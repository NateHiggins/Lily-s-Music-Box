"""The native shell gate must reject missing and inverted glass undersides."""
from pathlib import Path
import json
import sys
import unittest
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
from check_v2_arcade_fabric_candidate import primitives, check_pane_shells


class ArcadeCanopyShellTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        directory = ROOT / 'art/reviews/v2_arcade_fabric_20261018/canopy'
        cls.plan = json.loads((directory / 'canopy_plan.json').read_text())
        data = next(data for name, data in primitives(directory / 'arcade_canopy.glb') if name == 'canopy__glassish')
        cls.points, cls.normals = data['POSITION'], data['NORMAL']
        row = next(row for row in cls.plan['parts'] if row['material'] == 'glassish' and 'kind' not in row)
        half = np.array(row['size_m']) / 2
        local = (cls.points - row['center_m']) @ np.array(row['axes']).T
        cls.underside = np.all(np.abs(local) <= half + .00001, axis=(1, 2)) & np.all(np.abs(local[:, :, 2] + half[2]) < .00001, axis=1)

    def test_export_has_seated_closed_panes(self):
        self.assertEqual(int(self.underside.sum()), 2)
        report = check_pane_shells(self.plan, self.points, self.normals)
        self.assertEqual(report['closed_rectangular_glass_panes'], 198)
        self.assertLess(report['maximum_shell_face_area_error'], .003)

    def test_missing_inner_face_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'glass face'):
            check_pane_shells(self.plan, self.points[~self.underside], self.normals[~self.underside])

    def test_inverted_inner_face_is_rejected(self):
        normals = self.normals.copy()
        normals[self.underside] *= -1
        with self.assertRaisesRegex(ValueError, 'glass face'):
            check_pane_shells(self.plan, self.points, normals)


if __name__ == '__main__':
    unittest.main()
