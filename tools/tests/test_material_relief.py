"""Physical scale and OpenGL orientation of authored construction normals."""
from pathlib import Path
import sys, unittest
import numpy as np
sys.path.insert(0, str(Path(__file__).resolve().parents[2]/'art/tools'))
from material_relief import normals, relief, smooth_height


class PhysicalReliefTests(unittest.TestCase):
    def test_filter_preserves_signed_micrometre_relief(self):
        y,x=np.mgrid[:64,:64]/64
        wave=.000002*np.sin(2*np.pi*4*x)
        filtered=smooth_height(wave,2.)
        expected=wave*np.exp(-2*np.pi**2*2.**2*(4/64)**2)
        np.testing.assert_allclose(filtered,expected,atol=1e-18)
        self.assertLess(filtered.min(),0.)
        self.assertGreater(filtered.std(),.0000001)

    def test_known_physical_wave_has_correct_scale_and_orientation(self):
        size, tile, amplitude, periods = 256, .128, .00002, 8
        y, x = np.mgrid[:size, :size]/size
        h = amplitude*(np.sin(2*np.pi*periods*x)+np.sin(2*np.pi*periods*y))
        n = normals(h, tile)
        scale = amplitude*2*np.pi*periods/tile
        np.testing.assert_allclose(n[..., 0]/n[..., 2], -scale*np.cos(2*np.pi*periods*x), atol=.00007)
        np.testing.assert_allclose(n[..., 1]/n[..., 2], scale*np.cos(2*np.pi*periods*y), atol=.00007)
        np.testing.assert_allclose(np.linalg.norm(n, axis=-1), 1., atol=1e-12)
        closer = normals(h, tile/2)
        np.testing.assert_allclose(closer[..., :2]/closer[..., 2:3], 2*n[..., :2]/n[..., 2:3], atol=1e-12)

    def test_unresolved_relief_is_reported_instead_of_aliased(self):
        height, normal, metadata = relief('fired_enamel', 128, .128)
        self.assertTrue(metadata['unresolved_for_roughness'])
        self.assertTrue(metadata['bands'])
        self.assertTrue(np.isfinite(normal).all())
        self.assertGreater(height.std(), 0.)

    def test_missing_construction_and_invalid_height_are_rejected(self):
        with self.assertRaises(ValueError): relief('generic_albedo_bumps')
        with self.assertRaises(ValueError): normals([[float('nan')]], .1)
        with self.assertRaises(ValueError): normals([[0.]], 0.)
        for scale in [0., -1., float('nan'), float('inf')]:
            with self.subTest(scale=scale):
                with self.assertRaises(ValueError): relief('porcelain', 32, scale)
        for size in [0, 2, 16.5, True]:
            with self.assertRaises(ValueError): relief('porcelain', size)

    def test_coarse_weave_and_glass_patterns_do_not_alias(self):
        for profile, structure in [('cloth','crossed weave'), ('glass_reeded','rolled flutes'),
                                   ('glass_cut','cross-cut diamond facets')]:
            with self.subTest(profile=profile):
                height, normal, metadata = relief(profile, 16, .128)
                self.assertIn(structure, [row['structure'] for row in metadata['unresolved_for_roughness']])
                self.assertNotIn(structure, [row['structure'] for row in metadata['bands']])
                np.testing.assert_allclose(normal, normals(height, .128))


if __name__ == '__main__': unittest.main()
