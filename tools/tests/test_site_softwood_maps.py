"""Published timber maps retain pigment, height calibration and reflected borders."""
from pathlib import Path
import hashlib,json,unittest
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]

class SiteSoftwoodMapsTests(unittest.TestCase):
    def test_generated_long_grain_colour_remains_byte_exact(self):
        self.assertEqual((ROOT/'art/textures/ai_sources/site_softwood_20261017.png').read_bytes(),(ROOT/'art/textures/procedural/site_softwood/albedo.png').read_bytes())
    def test_calibrated_normals_match_independent_stored_height(self):
        for key in ['site_softwood','site_softwood_endgrain']:
            folder=ROOT/'art/textures/procedural'/key;meta=json.loads((folder/'material.json').read_text())
            for name,file in meta['maps'].items():self.assertEqual(hashlib.sha256((folder/file).read_bytes()).hexdigest(),meta['map_sha256'][name])
            h=np.asarray(Image.open(folder/'height.png')).astype(float)/65535*meta['relief_mm']/1000
            self.assertLess(meta['relief_mm'],.2)
            dy,dx=np.gradient(h,meta['meters_per_tile']/(len(h)-1),edge_order=2)
            dx[:,[0,-1]]=0;dy[[0,-1],:]=0
            n=np.stack((-dx,dy,np.ones_like(dx)),axis=-1);n/=np.linalg.norm(n,axis=2)[...,None]
            actual=np.asarray(Image.open(folder/'normal.png')).astype(float)/255*2-1
            self.assertLess(float(np.max(np.abs(n-actual))),.004)
            self.assertTrue(np.all(np.abs(actual[:,[0,-1],0])<.004))
            self.assertTrue(np.all(np.abs(actual[[0,-1],:,1])<.004))

if __name__=='__main__':unittest.main()
